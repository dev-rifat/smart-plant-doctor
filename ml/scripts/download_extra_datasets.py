#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Extra rice leaf datasets for model v0.2 - KrishiSathi AI

v0.1 was trained on one district / one season (RiceLeafDiseaseBD) and was
confidently wrong on an internet photo of blast. These public CC BY 4.0
datasets add variety. Only the classes the app knows are downloaded,
mapped to the app's labels.

  multiclass    - "A Rice Leaf Disease Image Dataset for Multi-Class Disease
                  Classification", Mendeley n8jpkpfz5p v1 (mixed sources,
                  includes web images) -> used for TRAINING
  dhanshomadhan - "Dhan-Shomadhan", Mendeley znsxdctwtt v1 (Dhaka division
                  fields) -> kept OUT of training as the unseen-source test

Output: ml/data/raw/external/<dataset>/<label>/<file>
        ml/data/raw/external/sources.csv (file, dataset, label, license, doi)

Standard library only. Re-running skips files already downloaded.

Usage:
  python3 ml/scripts/download_extra_datasets.py
  python3 ml/scripts/download_extra_datasets.py --limit 5   # smoke test
"""

import argparse
import csv
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HEADERS = {'User-Agent': 'KrishiSathi-dataset-downloader/1.0'}

DATASETS = {
    'multiclass': {
        'id': 'n8jpkpfz5p',
        'doi': '10.17632/n8jpkpfz5p.1',
        # filename prefix -> app label; other classes (bacterial blight,
        # hispa, leaf scald, neck blast, narrow brown spot) are skipped.
        'prefixes': {
            'leaf_blast': 'Blast',
            'brown_spot': 'Brown spot',
            'tungro': 'Rice Tungro',
            'sheath_blight': 'Sheath blight',
            'healthy': 'Healthy',
        },
    },
    'dhanshomadhan': {
        'id': 'znsxdctwtt',
        'doi': '10.17632/znsxdctwtt.1',
        # rbf = rice blast field, rb_wb = rice blast white background, ...
        'prefixes': {
            'rbf': 'Blast', 'rb_wb': 'Blast',
            'bsf': 'Brown spot', 'bs_wb': 'Brown spot',
            'rtf': 'Rice Tungro', 'rt_wb': 'Rice Tungro',
            'sbf': 'Sheath blight', 'sb_wb': 'Sheath blight',
        },
    },
}

IMAGE_EXT = {'.jpg', '.jpeg', '.png'}


def get_json(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=60) as r:
        return json.load(r)


def label_for(filename, prefixes):
    stem = Path(filename).stem.lower()
    # "healthy_rice_leaf12" must not match "healthy" by accident, and
    # "narrow_brown_spot3" must not match "brown_spot": require the prefix
    # to be followed only by digits / separators.
    for prefix, label in sorted(prefixes.items(), key=lambda kv: -len(kv[0])):
        if re.fullmatch(re.escape(prefix) + r'[\s_\-()0-9]*', stem):
            return label
    return None


def download(url, dest, size):
    if dest.exists() and dest.stat().st_size == size:
        return 'skipped'
    tmp = dest.with_name(dest.name + '.part')
    for attempt in range(1, 6):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=120) as r:
                data = r.read()
            if size and len(data) != size:
                raise IOError(f'size {len(data)} != {size}')
            tmp.write_bytes(data)
            os.replace(tmp, dest)
            return 'ok'
        except (urllib.error.URLError, IOError, TimeoutError) as e:
            if attempt == 5:
                return f'FAILED {e}'
            time.sleep(2 ** attempt)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default='ml/data/raw/external')
    ap.add_argument('--limit', type=int, default=0, help='files per label (smoke test)')
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    rows, jobs = [], []
    for name, cfg in DATASETS.items():
        meta = get_json(f'https://data.mendeley.com/public-api/datasets/{cfg["id"]}')
        license_name = (meta.get('data_licence') or {}).get('short_name', '?')
        if license_name != 'CC BY 4.0':
            sys.exit(f'[STOP] {name} license is "{license_name}", expected CC BY 4.0 - check before use')
        per_label, skipped = {}, 0
        for f in meta['files']:
            if Path(f['filename']).suffix.lower() not in IMAGE_EXT:
                continue
            label = label_for(f['filename'], cfg['prefixes'])
            if label is None:
                skipped += 1
                continue
            per_label[label] = per_label.get(label, 0) + 1
            if args.limit and per_label[label] > args.limit:
                continue
            dest = out / name / label / f['filename']
            dest.parent.mkdir(parents=True, exist_ok=True)
            details = f['content_details']
            jobs.append((details['download_url'], dest, details.get('size', 0)))
            rows.append([dest.relative_to(out), name, label, license_name, cfg['doi']])
        print(f'{name}: {license_name}, {sum(per_label.values())} files kept {per_label}, {skipped} skipped')

    print(f'downloading {len(jobs)} files ...', flush=True)
    results = {}
    with ThreadPoolExecutor(max_workers=8) as pool:
        for i, res in enumerate(pool.map(lambda j: download(*j), jobs), 1):
            key = res if not res.startswith('FAILED') else 'failed'
            results[key] = results.get(key, 0) + 1
            if i % 250 == 0:
                print(f'  {i}/{len(jobs)} {results}', flush=True)

    with open(out / 'sources.csv', 'w', newline='', encoding='utf-8') as fh:
        w = csv.writer(fh)
        w.writerow(['path', 'dataset', 'label', 'license', 'doi'])
        w.writerows(rows)
    print(f'done: {results} -> {out.resolve()}')


if __name__ == '__main__':
    main()
