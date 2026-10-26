#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Group-wise train/val/test split - KrishiSathi AI (Phase 1)

Input : ml/reports/manifest.csv (from inspect_dataset.py)
Output: ml/data/splits/{train,val,test}.csv, labels.json, excluded.csv
        ml/reports/split_report.txt

Rules (see ml/docs/PHASE1_FINDINGS.md for the evidence behind each):
  1. Drop every image whose identical file is filed under another class.
  2. Drop every image with a near-identical image (dHash <= CONFLICT_BITS)
     in another class - checked by eye: these are the same leaf, two labels.
  3. Drop extra exact copies within a class (keep the first).
  4. Split by group_id with StratifiedGroupKFold so no burst / near-duplicate
     group appears in two splits.

Usage:
  python ml/scripts/make_splits.py
"""

import argparse
import csv
import json
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np
from sklearn.model_selection import StratifiedGroupKFold

CONFLICT_BITS = 6
LEAK_CHECK_BITS = 4
POPCOUNT = np.array([bin(i).count('1') for i in range(256)], dtype=np.uint8)


def close_pairs(hashes, max_bits):
    h = np.array([int(x, 16) for x in hashes], dtype=np.uint64)
    for start in range(0, len(h), 256):
        block = h[start:start + 256, None] ^ h[None, :]
        dist = POPCOUNT[block.view(np.uint8)].reshape(block.shape + (8,)).sum(-1)
        ii, jj = np.nonzero(dist <= max_bits)
        for i, j in zip(ii + start, jj):
            if i < j:
                yield int(i), int(j)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--manifest', default='ml/reports/manifest.csv')
    ap.add_argument('--out', default='ml/data/splits')
    ap.add_argument('--report', default='ml/reports/split_report.txt')
    ap.add_argument('--test', type=float, default=0.15)
    ap.add_argument('--val', type=float, default=0.15)
    ap.add_argument('--seed', type=int, default=42, help='first seed tried')
    ap.add_argument('--seed-trials', type=int, default=100, help='seeds tried for best class balance')
    args = ap.parse_args()

    rows = list(csv.DictReader(open(args.manifest, encoding='utf-8')))
    lines = []

    def log(*parts):
        line = ' '.join(str(p) for p in parts)
        print(line)
        lines.append(line)

    # ---- exclusions -------------------------------------------------------
    excluded = {}
    classes_by_md5 = defaultdict(set)
    for r in rows:
        classes_by_md5[r['md5']].add(r['class'])
    for i, r in enumerate(rows):
        if len(classes_by_md5[r['md5']]) > 1:
            excluded[i] = 'identical_file_in_other_class'
    for i, j in close_pairs([r['dhash'] for r in rows], CONFLICT_BITS):
        if rows[i]['class'] != rows[j]['class']:
            for k in (i, j):
                excluded.setdefault(k, f'near_identical_in_other_class(dhash<={CONFLICT_BITS})')
    seen = set()
    for i, r in enumerate(rows):
        key = (r['md5'], r['class'])
        if key in seen:
            excluded.setdefault(i, 'duplicate_copy_same_class')
        seen.add(key)

    log('=' * 70)
    log('GROUP-WISE SPLIT - KrishiSathi AI (Phase 1)')
    log('=' * 70)
    log(f'manifest rows: {len(rows)}   excluded: {len(excluded)}')
    for reason, n in Counter(excluded.values()).most_common():
        log(f'  {n:5d}  {reason}')
    log('  excluded per class: ' + str(dict(Counter(rows[i]['class'] for i in excluded))))

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    with open(out / 'excluded.csv', 'w', newline='', encoding='utf-8') as f:
        w = csv.writer(f)
        w.writerow(['path', 'class', 'reason'])
        for i in sorted(excluded):
            w.writerow([rows[i]['path'], rows[i]['class'], excluded[i]])

    kept = [r for i, r in enumerate(rows) if i not in excluded]

    # ---- labels: alphabetical, fixed now so the app uses the same order ----
    class_names = sorted({r['class'] for r in kept})
    label_of = {c: i for i, c in enumerate(class_names)}
    (out / 'labels.json').write_text(json.dumps(class_names, indent=2) + '\n', encoding='utf-8')

    # ---- split --------------------------------------------------------------
    y = np.array([label_of[r['class']] for r in kept])
    groups = np.array([r['group_id'] for r in kept])
    idx = np.arange(len(kept))

    def split_with(seed):
        sgkf = StratifiedGroupKFold(n_splits=round(1 / args.test), shuffle=True, random_state=seed)
        rest, test = next(sgkf.split(idx, y, groups))
        sgkf = StratifiedGroupKFold(n_splits=round((1 - args.test) / args.val), shuffle=True,
                                    random_state=seed)
        tr, va = next(sgkf.split(rest, y[rest], groups[rest]))
        return {'train': rest[tr], 'val': rest[va], 'test': test}

    target = {'train': 1 - args.test - args.val, 'val': args.val, 'test': args.test}

    def worst_deviation(split):
        # Largest gap between a class's share in a split and the target share.
        return max(abs((y[v] == c).sum() / (y == c).sum() - target[k])
                   for k, v in split.items() for c in range(len(class_names)))

    # Big groups make single splits lumpy. Pick the most class-balanced seed;
    # this looks only at labels, never at model results, so it cannot leak.
    seeds = range(args.seed, args.seed + args.seed_trials)
    best_seed = min(seeds, key=lambda s: worst_deviation(split_with(s)))
    split_idx = split_with(best_seed)

    # ---- verify -------------------------------------------------------------
    log('')
    log('## CHECKS')
    group_sets = {k: set(groups[v]) for k, v in split_idx.items()}
    md5_sets = {k: {kept[i]['md5'] for i in v} for k, v in split_idx.items()}
    ok = True
    for a, b in (('train', 'val'), ('train', 'test'), ('val', 'test')):
        g = len(group_sets[a] & group_sets[b])
        m = len(md5_sets[a] & md5_sets[b])
        ok &= g == 0 and m == 0
        log(f'  {a:5s} vs {b:5s}: shared groups {g}, shared identical files {m}')
    which = np.empty(len(kept), dtype=object)
    for k, v in split_idx.items():
        which[v] = k
    leaks = Counter()
    for i, j in close_pairs([r['dhash'] for r in kept], LEAK_CHECK_BITS):
        if which[i] != which[j]:
            leaks[tuple(sorted((which[i], which[j])))] += 1
    log(f'  near-identical pairs (dhash<={LEAK_CHECK_BITS}) across splits: {dict(leaks) or 0}')
    ok &= not leaks
    log(f'  RESULT: {"PASS" if ok else "FAIL"}')

    # ---- report + files -----------------------------------------------------
    log('')
    log('## CLASS COUNTS PER SPLIT')
    log(f'  {"class":15s}' + ''.join(f'{k:>16s}' for k in split_idx) + f'{"total":>8s}')
    for c in class_names:
        n = {k: int((y[v] == label_of[c]).sum()) for k, v in split_idx.items()}
        tot = sum(n.values())
        log(f'  {c:15s}' + ''.join(f'{n[k]:>8d} ({100 * n[k] / tot:4.1f}%)' for k in split_idx) + f'{tot:>8d}')
    tot = len(kept)
    log(f'  {"ALL":15s}' + ''.join(f'{len(v):>8d} ({100 * len(v) / tot:4.1f}%)' for v in split_idx.values())
        + f'{tot:>8d}')
    log(f'  groups: ' + ', '.join(f'{k} {len(group_sets[k])}' for k in split_idx))
    log('')
    log(f'labels.json (model output order): {class_names}')
    log(f'seed: {best_seed} (best of {args.seed_trials}; worst class deviation '
        f'{100 * worst_deviation(split_idx):.1f} points from target)')

    for k, v in split_idx.items():
        with open(out / f'{k}.csv', 'w', newline='', encoding='utf-8') as f:
            w = csv.writer(f)
            w.writerow(['path', 'class', 'label', 'group_id'])
            for i in sorted(v, key=lambda i: kept[i]['path']):
                w.writerow([kept[i]['path'], kept[i]['class'], label_of[kept[i]['class']], kept[i]['group_id']])
    Path(args.report).write_text('\n'.join(lines) + '\n', encoding='utf-8')
    log(f'Written: {out}/train.csv, val.csv, test.csv, labels.json, excluded.csv; {args.report}')


if __name__ == '__main__':
    main()
