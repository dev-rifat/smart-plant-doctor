#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Image embeddings for near-duplicate detection - KrishiSathi AI

dHash (a 64-bit gradient hash) can't tell apart different leaves on a white
background: thin leaf + white page looks the same to it. ImageNet
EfficientNetB0 features compare what is in the picture instead.

Writes ml/reports/embeddings.npz (paths, L2-normalised 1280-d vectors),
reusing vectors already computed for unchanged paths.

Usage:
  python ml/scripts/embed_images.py
"""

import csv
from pathlib import Path

import numpy as np
import tensorflow as tf
import keras
from PIL import Image

RAW = Path('ml/data/raw')
OUT = Path('ml/reports/embeddings.npz')


def all_paths():
    paths = [f'riceleafdiseasebd/{r["path"]}'
             for r in csv.DictReader(open('ml/reports/manifest.csv', encoding='utf-8'))]
    paths += [f'external/{r["path"]}'
              for r in csv.DictReader(open(RAW / 'external/sources.csv', encoding='utf-8'))]
    return paths


def load(path):
    im = Image.open(RAW / path).convert('RGB')
    w, h = im.size  # same 4:3 limit as training and the app
    if w / h > 4 / 3:
        nw = int(h * 4 / 3); im = im.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
    elif h / w > 4 / 3:
        nh = int(w * 4 / 3); im = im.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
    return np.asarray(im.resize((224, 224), Image.BILINEAR), dtype=np.float32)


def main():
    paths = all_paths()
    done = {}
    if OUT.exists():
        old = np.load(OUT, allow_pickle=False)
        done = dict(zip(old['paths'].tolist(), old['vectors']))
    todo = [p for p in paths if p not in done]
    print(f'{len(paths)} images, {len(todo)} to embed')
    model = keras.applications.EfficientNetB0(include_top=False, weights='imagenet', pooling='avg')
    for s in range(0, len(todo), 64):
        batch = todo[s:s + 64]
        v = model.predict(np.stack([load(p) for p in batch]), verbose=0)
        v /= np.linalg.norm(v, axis=1, keepdims=True)
        done.update(zip(batch, v))
        if (s // 64) % 20 == 0:
            print(f'  {s + len(batch)}/{len(todo)}', flush=True)
    np.savez(OUT, paths=np.array(paths), vectors=np.stack([done[p] for p in paths]).astype(np.float16))
    print('saved', OUT)


if __name__ == '__main__':
    main()
