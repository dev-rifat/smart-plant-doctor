# %% [markdown]
# # KrishiSathi AI - Rice leaf disease classifier (Phase 5)
#
# ধানের পাতার রোগ শনাক্তকরণ মডেল ট্রেনিং। Google Colab-এ GPU দিয়ে চালান:
# **Runtime → Change runtime type → T4 GPU**, তারপর **Runtime → Run all**।
#
# এই notebook যা করে:
# 1. GitHub থেকে Phase 1-এর split ফাইল আনে, Mendeley থেকে ছবি ডাউনলোড করে
# 2. দুটি মডেল ট্রেন করে: MobileNetV3-Large ও EfficientNetB0 (transfer learning)
# 3. **শুধু validation set দিয়ে** তুলনা করে: per-class precision/recall/F1, confusion matrix,
#    ফোন-প্যাটার্ন অনুযায়ী accuracy (shortcut যাচাই)
# 4. Temperature scaling দিয়ে confidence calibrate করে, "নিশ্চিত নই" threshold বের করে
# 5. TFLite-এ export করে, Keras-এর সাথে output মিলিয়ে দেখে
# 6. সব ফলাফল Google Drive-এ সংরক্ষণ করে
#
# Test set এখানে চলে না। মডেল চূড়ান্ত করার পর শেষ সেলে `RUN_TEST = True` করে **একবারই** চালাবেন।
#
# Source of truth: `ml/notebooks/train_rice_classifier.py` (এই .ipynb সেখান থেকে তৈরি)।
# লোকাল smoke test: `SMOKE=1 python ml/notebooks/train_rice_classifier.py`

# %%
import json
import os
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

IN_COLAB = 'google.colab' in sys.modules
SMOKE = os.environ.get('SMOKE') == '1'  # tiny run for testing the code, not for results

REPO_URL = 'https://github.com/dev-rifat/plant-health-checker.git'
BRANCH = 'add_ai_voice'

if IN_COLAB:
    REPO_DIR = Path('/content/plant-health-checker')
    if not REPO_DIR.exists():
        r = subprocess.run(['git', 'clone', '--depth', '1', '-b', BRANCH, REPO_URL, str(REPO_DIR)])
        if r.returncode != 0:
            # Fallback: upload ml_bundle.zip (ml/scripts, ml/data/splits, ml/reports/manifest.csv)
            from google.colab import files
            print('git clone failed - upload ml_bundle.zip')
            up = files.upload()
            REPO_DIR.mkdir(parents=True)
            subprocess.run(['unzip', '-q', next(iter(up)), '-d', str(REPO_DIR)], check=True)
    DATA_ROOT = Path('/content/data/riceleafdiseasebd')
    from google.colab import drive
    drive.mount('/content/drive')
    OUT_ROOT = Path('/content/drive/MyDrive/krishisathi_ml')
else:
    REPO_DIR = Path.cwd()
    while not (REPO_DIR / 'ml').is_dir() and REPO_DIR != REPO_DIR.parent:
        REPO_DIR = REPO_DIR.parent
    DATA_ROOT = REPO_DIR / 'ml/data/raw/riceleafdiseasebd'
    OUT_ROOT = REPO_DIR / 'ml/models'

SPLITS = REPO_DIR / 'ml/data/splits'
MANIFEST = REPO_DIR / 'ml/reports/manifest.csv'
RUN_DIR = OUT_ROOT / (('smoke_' if SMOKE else 'run_') + datetime.now().strftime('%Y%m%d_%H%M'))
RUN_DIR.mkdir(parents=True, exist_ok=True)
print('repo :', REPO_DIR)
print('data :', DATA_ROOT)
print('out  :', RUN_DIR)

# %% [markdown]
# ## 1) ছবি ডাউনলোড
# Phase 1-এর `download_dataset.py` ব্যবহার করে (শুধু Original images, ~3.3 GB)। Colab-এ সাধারণত কয়েক মিনিট লাগে।
# প্রতিটি নতুন Colab session-এ আবার লাগবে, কারণ `/content` মুছে যায়।

# %%
if not (DATA_ROOT / 'Original images').is_dir():
    subprocess.run([sys.executable, str(REPO_DIR / 'ml/scripts/download_dataset.py'),
                    '--out', str(DATA_ROOT)], check=True)
n_found = sum(1 for _ in (DATA_ROOT / 'Original images').glob('*/*.jpg'))
print('images on disk:', n_found)

# %% [markdown]
# ## 2) Settings

# %%
import numpy as np
import pandas as pd
import tensorflow as tf
import keras
from keras import layers

IMG_SIZE = 224
CACHE_SIZE = 256          # images cached at this size, then cropped/resized to IMG_SIZE
BATCH = 32
EPOCHS_HEAD = 1 if SMOKE else 8      # backbone frozen
EPOCHS_FINETUNE = 1 if SMOKE else 25  # whole backbone, low LR, early stopping
LR_HEAD = 1e-3
LR_FINETUNE = 1e-5
SEED = 42
MODELS = ['mobilenetv3_large', 'efficientnetb0']

keras.utils.set_random_seed(SEED)
pd.set_option('display.width', 200)
pd.set_option('display.max_columns', 20)
print('TensorFlow', tf.__version__, '| Keras', keras.__version__)
print('GPU:', tf.config.list_physical_devices('GPU') or 'NONE - training will be very slow')

CLASS_NAMES = json.loads((SPLITS / 'labels.json').read_text())
N_CLASSES = len(CLASS_NAMES)
print('classes:', CLASS_NAMES)

# %% [markdown]
# ## 3) Data pipeline
# - পুরো ছবি crop ছাড়া বর্গাকারে resize - অ্যাপেও ঠিক এভাবেই করতে হবে।
# - Augmentation (শুধু train): random aspect-ratio crop, flip, 90° rotation, brightness/contrast।
#   Aspect ও rotation যোগ করা হয়েছে কারণ Phase 1-এ দেখা গেছে কিছু ক্লাস মূলত landscape, কিছু portrait
#   (FINDINGS §২.৫) - মডেল যেন ছবির দিক দেখে রোগ "আন্দাজ" না করে।

# %%
def load_split(name):
    df = pd.read_csv(SPLITS / f'{name}.csv')
    if SMOKE:
        df = df.groupby('class').head(8).reset_index(drop=True)
    df['file'] = [str(DATA_ROOT / p) for p in df['path']]
    return df


splits = {k: load_split(k) for k in ('train', 'val', 'test')}
for k, df in splits.items():
    print(f'{k:5s} {len(df):5d} images')


def decode(path, label):
    img = tf.io.decode_jpeg(tf.io.read_file(path), channels=3)
    img = tf.image.resize(img, (CACHE_SIZE, CACHE_SIZE), antialias=True)
    return tf.cast(tf.round(img), tf.uint8), label


def augment(img, label):
    img = tf.cast(img, tf.float32)
    # random aspect ratio: crop each side independently to 75-100%, then stretch back
    h = tf.cast(tf.random.uniform([], 0.75, 1.0) * CACHE_SIZE, tf.int32)
    w = tf.cast(tf.random.uniform([], 0.75, 1.0) * CACHE_SIZE, tf.int32)
    img = tf.image.random_crop(img, tf.stack([h, w, 3]))
    img = tf.image.resize(img, (IMG_SIZE, IMG_SIZE))
    img = tf.image.random_flip_left_right(img)
    img = tf.image.random_flip_up_down(img)
    img = tf.image.rot90(img, k=tf.random.uniform([], 0, 4, dtype=tf.int32))
    img = tf.image.random_brightness(img, 25.0)
    img = tf.image.random_contrast(img, 0.8, 1.2)
    img = tf.image.random_saturation(img, 0.8, 1.2)
    return tf.clip_by_value(img, 0.0, 255.0), label


def to_eval_size(img, label):
    return tf.image.resize(tf.cast(img, tf.float32), (IMG_SIZE, IMG_SIZE)), label


def make_ds(df, training):
    ds = tf.data.Dataset.from_tensor_slices((df['file'].values, df['label'].values.astype('int32')))
    ds = ds.map(decode, num_parallel_calls=tf.data.AUTOTUNE).cache()
    if training:
        ds = ds.shuffle(len(df), seed=SEED, reshuffle_each_iteration=True)
        ds = ds.map(augment, num_parallel_calls=tf.data.AUTOTUNE)
    else:
        ds = ds.map(to_eval_size, num_parallel_calls=tf.data.AUTOTUNE)
    return ds.batch(BATCH).prefetch(tf.data.AUTOTUNE)


train_ds = make_ds(splits['train'], training=True)
val_ds = make_ds(splits['val'], training=False)

counts = splits['train']['label'].value_counts().sort_index()
class_weight = {i: len(splits['train']) / (N_CLASSES * counts.get(i, 1)) for i in range(N_CLASSES)}
print('class weights:', {CLASS_NAMES[i]: round(float(w), 2) for i, w in class_weight.items()})

# %% [markdown]
# ## 4) Models
# দুটোই ImageNet-এ pre-trained, input 0-255 RGB (নিজেরাই normalize করে)। ফলে অ্যাপে শুধু
# pixel মান পাঠালেই হবে। Output = logits; softmax পরে temperature সহ যোগ হবে।
#
# EfficientNet-Lite Keras-এ built-in নেই, তাই তুলনা হচ্ছে EfficientNetB0-এর সাথে।

# %%
def build_model(name):
    shape = (IMG_SIZE, IMG_SIZE, 3)
    if name == 'mobilenetv3_large':
        base = keras.applications.MobileNetV3Large(
            input_shape=shape, include_top=False, weights='imagenet',
            pooling='avg', include_preprocessing=True)
    elif name == 'efficientnetb0':
        base = keras.applications.EfficientNetB0(
            input_shape=shape, include_top=False, weights='imagenet', pooling='avg')
    else:
        raise ValueError(name)
    base.trainable = False
    inp = keras.Input(shape, name='image')
    x = base(inp, training=False)  # BatchNorm stays in inference mode, also while fine-tuning
    x = layers.Dropout(0.3)(x)
    out = layers.Dense(N_CLASSES, name='logits')(x)
    return keras.Model(inp, out, name=name), base


def train(name):
    model, base = build_model(name)
    loss = keras.losses.SparseCategoricalCrossentropy(from_logits=True)
    ckpt = RUN_DIR / f'{name}_best.keras'
    callbacks = [
        keras.callbacks.EarlyStopping(monitor='val_loss', patience=4, restore_best_weights=True),
        keras.callbacks.ModelCheckpoint(str(ckpt), monitor='val_loss', save_best_only=True),
        keras.callbacks.CSVLogger(str(RUN_DIR / f'{name}_history.csv'), append=True),
    ]
    t0 = time.time()
    model.compile(optimizer=keras.optimizers.Adam(LR_HEAD), loss=loss, metrics=['accuracy'])
    model.fit(train_ds, validation_data=val_ds, epochs=EPOCHS_HEAD,
              class_weight=class_weight, callbacks=callbacks, verbose=2)
    base.trainable = True
    model.compile(optimizer=keras.optimizers.Adam(LR_FINETUNE), loss=loss, metrics=['accuracy'])
    model.fit(train_ds, validation_data=val_ds, epochs=EPOCHS_FINETUNE,
              class_weight=class_weight, callbacks=callbacks, verbose=2)
    print(f'{name}: trained in {(time.time() - t0) / 60:.1f} min')
    # EarlyStopping only restores the best weights of the last fit(); the checkpoint
    # holds the best across both phases (fine-tuning can end up worse than the head).
    return keras.models.load_model(ckpt)


trained = {}
for name in MODELS:
    print('\n' + '=' * 60 + f'\n{name}\n' + '=' * 60)
    trained[name] = train(name)

# %% [markdown]
# ## 5) Validation results (মডেল বাছাই শুধু এখান থেকে)

# %%
import matplotlib.pyplot as plt
from sklearn.metrics import classification_report, confusion_matrix, f1_score


def softmax(z, t=1.0):
    z = z / t
    z = z - z.max(axis=1, keepdims=True)
    e = np.exp(z)
    return e / e.sum(axis=1, keepdims=True)


def nll(probs, y):
    return float(-np.log(probs[np.arange(len(y)), y] + 1e-12).mean())


def ece(probs, y, bins=10):
    conf, pred = probs.max(1), probs.argmax(1)
    edges = np.linspace(0, 1, bins + 1)
    total = 0.0
    for lo, hi in zip(edges[:-1], edges[1:]):
        m = (conf > lo) & (conf <= hi)
        if m.any():
            total += m.mean() * abs((pred[m] == y[m]).mean() - conf[m].mean())
    return float(total)


manifest = pd.read_csv(MANIFEST)[['path', 'filename_pattern']]
val_df = splits['val'].merge(manifest, on='path', how='left')
y_val = val_df['label'].values
results = {}

for name, model in trained.items():
    logits = model.predict(val_ds, verbose=0)
    pred = logits.argmax(1)
    print('\n' + '=' * 60 + f'\n{name} - VALIDATION\n' + '=' * 60)
    print(classification_report(y_val, pred, labels=range(N_CLASSES),
                                target_names=CLASS_NAMES, digits=3, zero_division=0))

    # Shortcut check: accuracy should not depend much on which phone/pattern took the photo
    by_pattern = (val_df.assign(ok=(pred == y_val))
                  .groupby('filename_pattern')['ok'].agg(['mean', 'size']).round(3))
    print('accuracy by original filename pattern (proxy for phone):\n', by_pattern, '\n')

    # Temperature scaling: one number fitted on val so scores match real accuracy better
    temps = np.linspace(0.25, 10.0, 196)
    best_t = float(temps[np.argmin([nll(softmax(logits, t), y_val) for t in temps])])
    if best_t in (temps[0], temps[-1]):
        print(f'[WARNING] temperature hit the search limit ({best_t}) - model is badly calibrated')
    p_raw, p_cal = softmax(logits), softmax(logits, best_t)

    # "Not sure" threshold: smallest confidence cut where answered images are >= 95% correct
    conf = p_cal.max(1)
    threshold, coverage = None, 0.0
    for th in np.linspace(0.3, 0.99, 70):
        m = conf >= th
        if m.sum() >= 20 and (pred[m] == y_val[m]).mean() >= 0.95:
            threshold, coverage = float(th), float(m.mean())
            break

    results[name] = {
        'val_accuracy': float((pred == y_val).mean()),
        'val_macro_f1': float(f1_score(y_val, pred, average='macro')),
        'temperature': best_t,
        'ece_before': ece(p_raw, y_val), 'ece_after': ece(p_cal, y_val),
        'uncertain_threshold': threshold, 'coverage_at_threshold': coverage,
        'params': int(model.count_params()),
        'per_class_report': classification_report(
            y_val, pred, labels=range(N_CLASSES), target_names=CLASS_NAMES,
            output_dict=True, zero_division=0),
        'accuracy_by_filename_pattern': by_pattern['mean'].to_dict(),
    }
    print(f'temperature {best_t:.2f} | ECE {results[name]["ece_before"]:.3f} -> {results[name]["ece_after"]:.3f}'
          f' | threshold {threshold} answers {coverage:.0%} of val images at >=95% accuracy')

    cm = confusion_matrix(y_val, pred, labels=range(N_CLASSES))
    fig, ax = plt.subplots(figsize=(7, 6))
    ax.imshow(cm, cmap='Greens')
    ax.set_xticks(range(N_CLASSES), CLASS_NAMES, rotation=45, ha='right')
    ax.set_yticks(range(N_CLASSES), CLASS_NAMES)
    for i in range(N_CLASSES):
        for j in range(N_CLASSES):
            ax.text(j, i, cm[i, j], ha='center', va='center',
                    color='white' if cm[i, j] > cm.max() / 2 else 'black')
    ax.set_xlabel('predicted')
    ax.set_ylabel('true')
    ax.set_title(f'{name} - validation')
    fig.tight_layout()
    fig.savefig(RUN_DIR / f'{name}_val_confusion.png', dpi=120)
    plt.show()

# %% [markdown]
# ## 6) TFLite export ও যাচাই
# প্রতিটি মডেলের শেষে `logits / T → softmax` যোগ করে export করা হয়, যাতে অ্যাপ সরাসরি
# calibrated probability পায়। float16 ও dynamic-range (int8 weights) দুটোই তৈরি হয়, তারপর
# Keras-এর সাথে top-1 মিল ও সময় মাপা হয় (Colab CPU-তে - ফোনের সময় আলাদা হবে)।

# %%
def export_tflite(name, model, temperature):
    inp = keras.Input((IMG_SIZE, IMG_SIZE, 3), name='image')
    x = model(inp, training=False)
    x = layers.Rescaling(1.0 / temperature, name='temperature')(x)
    out = layers.Softmax(name='probabilities')(x)
    wrapped = keras.Model(inp, out)
    saved = RUN_DIR / f'{name}_savedmodel'
    wrapped.export(str(saved), verbose=False)
    files = {}
    for kind in ('float16', 'dynamic_int8'):
        conv = tf.lite.TFLiteConverter.from_saved_model(str(saved))
        conv.optimizations = [tf.lite.Optimize.DEFAULT]
        if kind == 'float16':
            conv.target_spec.supported_types = [tf.float16]
        path = RUN_DIR / f'{name}_{kind}.tflite'
        path.write_bytes(conv.convert())
        files[kind] = path
    return wrapped, files


try:  # LiteRT is the successor of tf.lite.Interpreter (deprecated)
    from ai_edge_litert.interpreter import Interpreter
except ImportError:
    Interpreter = tf.lite.Interpreter


def run_tflite(path, images):
    interp = Interpreter(model_path=str(path))
    interp.allocate_tensors()
    inp, out = interp.get_input_details()[0], interp.get_output_details()[0]
    preds, t0 = [], time.time()
    for img in images:
        interp.set_tensor(inp['index'], img[None].astype(np.float32))
        interp.invoke()
        preds.append(interp.get_tensor(out['index'])[0])
    return np.array(preds), (time.time() - t0) / len(images) * 1000


check_images = np.concatenate([x.numpy() for x, _ in val_ds.take(4 if not SMOKE else 1)])
for name, model in trained.items():
    wrapped, files = export_tflite(name, model, results[name]['temperature'])
    ref = wrapped.predict(check_images, verbose=0)
    results[name]['tflite'] = {}
    for kind, path in files.items():
        probs, ms = run_tflite(path, check_images)
        info = {
            'file': path.name,
            'size_mb': round(path.stat().st_size / 1e6, 2),
            'top1_agreement_with_keras': float((probs.argmax(1) == ref.argmax(1)).mean()),
            'max_prob_diff': float(np.abs(probs - ref).max()),
            'colab_cpu_ms_per_image': round(ms, 1),
        }
        results[name]['tflite'][kind] = info
        print(name, kind, info)

# %% [markdown]
# ## 7) তুলনা ও সংরক্ষণ
# বাছাইয়ের নিয়ম: validation macro-F1 বেশি যেটির; ১ পয়েন্টের কম পার্থক্য হলে ছোট ও দ্রুত মডেল।

# %%
summary = pd.DataFrame({
    n: {
        'val_macro_f1': r['val_macro_f1'], 'val_accuracy': r['val_accuracy'],
        'ece_after': r['ece_after'], 'threshold': r['uncertain_threshold'],
        'coverage': r['coverage_at_threshold'], 'params_M': r['params'] / 1e6,
        'fp16_MB': r['tflite']['float16']['size_mb'],
        'int8w_MB': r['tflite']['dynamic_int8']['size_mb'],
        'int8w_agree': r['tflite']['dynamic_int8']['top1_agreement_with_keras'],
    } for n, r in results.items()
}).T.round(3)
print(summary)

best_f1 = summary['val_macro_f1'].max()
close = summary[summary['val_macro_f1'] >= best_f1 - 0.01]
chosen = close['params_M'].idxmin()
print('\nchosen model:', chosen)

model_card = {
    'model_version': f'rice-{chosen}-{RUN_DIR.name}',
    'smoke_run': SMOKE,
    'labels': CLASS_NAMES,
    'input': {'size': [IMG_SIZE, IMG_SIZE], 'channels': 'RGB', 'dtype': 'float32',
              'range': '0-255', 'preprocessing': 'resize the whole photo to 224x224, no crop, no normalisation'},
    'output': 'calibrated probabilities (softmax(logits / temperature)), same order as labels',
    'temperature': results[chosen]['temperature'],
    'uncertain_threshold': results[chosen]['uncertain_threshold'],
    'validation': {k: v for k, v in results[chosen].items() if k != 'tflite'},
    'tflite': results[chosen]['tflite'],
    'dataset': {'name': 'RiceLeafDiseaseBD v3', 'doi': '10.17632/86s4jzj2m4.3', 'license': 'CC BY 4.0',
                'split': 'ml/data/splits (group-wise, see ml/docs/PHASE1_FINDINGS.md)'},
    'limitations': [
        'Only 6 classes; any other disease or pest will be forced into one of them.',
        'Trained on photos from Gazipur, one season (Apr-May 2025), BRRI dhan28/29 only.',
        'Scores are calibrated on the validation set, not guaranteed probabilities of correctness.',
        'Test-set and real-field performance not yet measured.',
    ],
}
(RUN_DIR / 'model_card.json').write_text(json.dumps(model_card, indent=2, default=float))
(RUN_DIR / 'all_results.json').write_text(json.dumps(results, indent=2, default=float))
summary.to_csv(RUN_DIR / 'comparison.csv')
print('saved to', RUN_DIR)

# %% [markdown]
# ## 8) TEST SET - শুধু একবার, মডেল চূড়ান্ত করার পর
# `RUN_TEST = True` করুন শুধু তখন, যখন validation দেখে মডেল ও settings চূড়ান্ত।
# Test ফল দেখে আবার ট্রেনিং বদলালে test আর "অদেখা" থাকে না, তখন রিপোর্ট করা সংখ্যা বিশ্বাসযোগ্য নয়।

# %%
RUN_TEST = False

if RUN_TEST:
    test_ds = make_ds(splits['test'], training=False)
    y_test = splits['test']['label'].values
    logits = trained[chosen].predict(test_ds, verbose=0)
    pred = logits.argmax(1)
    report = classification_report(y_test, pred, labels=range(N_CLASSES),
                                   target_names=CLASS_NAMES, digits=3, zero_division=0)
    print(f'{chosen} - TEST\n{report}')
    print(confusion_matrix(y_test, pred, labels=range(N_CLASSES)))
    (RUN_DIR / 'TEST_RESULT.txt').write_text(f'{chosen}\n{report}\n'
                                             f'{confusion_matrix(y_test, pred, labels=range(N_CLASSES))}\n')
