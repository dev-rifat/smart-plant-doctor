#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Train/val/test split for model v0.2 - KrishiSathi AI

  RiceLeafDiseaseBD   -> keeps its v1 split (ml/data/splits)
  multiclass          -> new group-wise 70/15/15 split, added to v1's
  dhanshomadhan       -> never trained on: "ood_test", the unseen-source check

Web-collected datasets often contain copies of other datasets (here: 289
multiclass images were copies of Dhan-Shomadhan), so before splitting,
every multiclass image that is a near-duplicate of any RiceLeafDiseaseBD or
Dhan-Shomadhan image is dropped - otherwise the v1 test set or the
unseen-source test would leak into training.

Near-duplicate = cosine similarity >= 0.90 of ImageNet EfficientNetB0
embeddings (ml/scripts/embed_images.py). dHash was tried first and is
useless on white-background photos: it flagged 572 different leaves as
cross-class copies. Calibration: identical files 1.000, random pairs
p99.9 0.867; by eye, cross-class pairs >= 0.90 were the same leaf
stretched/cropped and labelled two different diseases.

Also reports how often each class has a white background per source: if one
class is mostly on white paper the model can learn the background instead
of the disease.

Paths in the output are relative to ml/data/raw.

Usage:
  python ml/scripts/make_splits_v2.py
"""

import csv
import hashlib
import json
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np
from PIL import Image
from sklearn.model_selection import StratifiedGroupKFold

RAW = Path('ml/data/raw')
V1 = Path('ml/data/splits')
OUT = Path('ml/data/splits_v2')
REPORT = Path('ml/reports/split_v2_report.txt')
DUP_SIM = 0.90

_emb = np.load('ml/reports/embeddings.npz')
_vec = np.nan_to_num(_emb['vectors'].astype(np.float32))
_row = {p: i for i, p in enumerate(_emb['paths'].tolist())}


def vectors(paths):
    return _vec[[_row[p] for p in paths]]


def white_share(path):
    """Share of border pixels that are near-white (photo on white paper)."""
    with Image.open(path) as im:
        rgb = np.asarray(im.convert('RGB').resize((64, 64)), dtype=np.int16)
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    return float((border.min(axis=1) > 215).mean())


def pairs_within(a, b, min_sim):
    """Index pairs (i in a, j in b) with cosine similarity >= min_sim."""
    out = []
    for s in range(0, len(a), 512):
        sim = a[s:s + 512] @ b.T
        ii, jj = np.nonzero(sim >= min_sim)
        out += [(int(i) + s, int(j)) for i, j in zip(ii, jj)]
    return out


class UnionFind:
    def __init__(self, n):
        self.p = list(range(n))

    def find(self, x):
        while self.p[x] != x:
            self.p[x] = self.p[self.p[x]]
            x = self.p[x]
        return x

    def union(self, a, b):
        self.p[self.find(a)] = self.find(b)


def main():
    lines = []

    def log(*parts):
        line = ' '.join(str(p) for p in parts)
        print(line)
        lines.append(line)

    labels = json.loads((V1 / 'labels.json').read_text())
    label_of = {c: i for i, c in enumerate(labels)}

    # v1 data, paths re-rooted at ml/data/raw.
    v1 = {}
    for split in ('train', 'val', 'test'):
        for r in csv.DictReader(open(V1 / f'{split}.csv', encoding='utf-8')):
            v1[f'riceleafdiseasebd/{r["path"]}'] = (split, r['class'], r['group_id'])

    ext = list(csv.DictReader(open(RAW / 'external/sources.csv', encoding='utf-8')))
    rows = []
    for r in ext:
        p = RAW / 'external' / r['path']
        try:
            white = white_share(p)
        except Exception as e:  # noqa: BLE001
            log(f'  unreadable, skipped: {r["path"]} ({e})')
            continue
        rows.append({**r, 'rel': f'external/{r["path"]}', 'white': white,
                     'md5': hashlib.md5(p.read_bytes()).hexdigest()})
    mc = [r for r in rows if r['dataset'] == 'multiclass']
    ds = [r for r in rows if r['dataset'] == 'dhanshomadhan']

    log('=' * 70)
    log('SPLIT v0.2 - KrishiSathi AI')
    log('=' * 70)
    log(f'RiceLeafDiseaseBD (v1 split kept): {len(v1)}   multiclass: {len(mc)}   dhanshomadhan: {len(ds)}')

    # ---- cross-dataset leakage -------------------------------------------
    rl_vec = vectors(list(v1))
    mc_vec = vectors([r['rel'] for r in mc])
    ds_vec = vectors([r['rel'] for r in ds])
    drop = {}
    for name, other in (('RiceLeafDiseaseBD', rl_vec), ('Dhan-Shomadhan', ds_vec)):
        hits = pairs_within(mc_vec, other, DUP_SIM)
        for i, _ in hits:
            drop.setdefault(i, f'near_duplicate_of_{name}')
        log(f'multiclass images near-identical to {name}: {len({i for i, _ in hits})}')
    ds_vs_rl = pairs_within(ds_vec, rl_vec, DUP_SIM)
    log(f'Dhan-Shomadhan images near-identical to RiceLeafDiseaseBD: {len({i for i, _ in ds_vs_rl})}'
        ' (dropped from the unseen-source test)')
    ds_drop = {i for i, _ in ds_vs_rl}

    # ---- multiclass: duplicates inside the dataset ------------------------
    uf = UnionFind(len(mc))
    conflicts = set()
    for i, j in pairs_within(mc_vec, mc_vec, DUP_SIM):
        if i >= j:
            continue
        if mc[i]['label'] != mc[j]['label']:
            conflicts |= {i, j}
        uf.union(i, j)
    for i in conflicts:
        drop.setdefault(i, 'near_identical_in_other_class')
    seen_md5 = set()
    for i, r in enumerate(mc):
        if r['md5'] in seen_md5:
            drop.setdefault(i, 'exact_copy')
        seen_md5.add(r['md5'])
    log(f'multiclass dropped: {len(drop)} {dict(Counter(drop.values()))}')

    keep = [i for i in range(len(mc)) if i not in drop]
    groups = np.array([uf.find(i) for i in keep])
    log(f'multiclass near-duplicate groups: {len(set(groups))} for {len(keep)} images'
        f' (largest {Counter(groups).most_common(1)[0][1]})')

    # ---- split multiclass by group, most class-balanced of 100 seeds -------
    y = np.array([label_of[mc[i]['label']] for i in keep])
    idx = np.arange(len(keep))

    def split(seed):
        k = StratifiedGroupKFold(n_splits=7, shuffle=True, random_state=seed)
        rest, test = next(k.split(idx, y, groups))
        k = StratifiedGroupKFold(n_splits=6, shuffle=True, random_state=seed)
        tr, va = next(k.split(rest, y[rest], groups[rest]))
        return {'train': rest[tr], 'val': rest[va], 'test': test}

    target = {'train': 0.70, 'val': 0.15, 'test': 0.15}

    def worst(s):
        return max(abs((y[v] == c).sum() / max((y == c).sum(), 1) - target[k])
                   for k, v in s.items() for c in set(y))

    best = min(range(100), key=lambda seed: worst(split(seed)))
    mc_split = split(best)
    shared = set(groups[mc_split['train']]) & (set(groups[mc_split['val']]) | set(groups[mc_split['test']]))
    log(f'multiclass split seed {best}, worst class deviation {100 * worst(mc_split):.1f} pts,'
        f' groups shared across splits: {len(shared)}')

    # ---- write -----------------------------------------------------------
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / 'labels.json').write_text(json.dumps(labels, indent=2) + '\n')
    out = defaultdict(list)
    for path, (s, cls, g) in v1.items():
        out[s].append((path, cls, label_of[cls], 'riceleafdiseasebd', g))
    for s, ids in mc_split.items():
        for k in ids:
            r = mc[keep[k]]
            out[s].append((r['rel'], r['label'], label_of[r['label']], 'multiclass', f'mc{groups[k]}'))
    for i, r in enumerate(ds):
        if i not in ds_drop:
            out['ood_test'].append((r['rel'], r['label'], label_of[r['label']], 'dhanshomadhan', f'ds{i}'))
    for s, items in out.items():
        with open(OUT / f'{s}.csv', 'w', newline='', encoding='utf-8') as f:
            w = csv.writer(f)
            w.writerow(['path', 'class', 'label', 'source', 'group_id'])
            w.writerows(sorted(items))

    log('')
    log('## COUNTS (rows: class, columns: split / source)')
    for s in ('train', 'val', 'test', 'ood_test'):
        c = Counter((src, cls) for _, cls, _, src, _ in out[s])
        log(f'  {s:8s} total {len(out[s]):5d}  ' + ', '.join(
            f'{cls}: ' + '+'.join(str(c[(src, cls)]) for src in ('riceleafdiseasebd', 'multiclass', 'dhanshomadhan') if c[(src, cls)])
            for cls in labels if any(c[(src, cls)] for src in ('riceleafdiseasebd', 'multiclass', 'dhanshomadhan'))))

    log('')
    log('## WHITE BACKGROUND SHARE (border pixels near-white), by source and class')
    for name, items in (('multiclass', [mc[i] for i in keep]), ('dhanshomadhan', ds)):
        by = defaultdict(list)
        for r in items:
            by[r['label']].append(r['white'] > 0.5)
        log(f'  {name}: ' + ', '.join(f'{k} {100 * np.mean(v):.0f}%' for k, v in sorted(by.items())))
    log('  (RiceLeafDiseaseBD is all field photos.) A class that is mostly white-background in one')
    log('  source but not others is a shortcut risk - the v0.2 report must check accuracy per source.')

    REPORT.write_text('\n'.join(lines) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
