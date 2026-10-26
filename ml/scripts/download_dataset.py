#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
RiceLeafDiseaseBD v3 partial downloader - KrishiSathi AI (Phase 1)

The full ZIP on Mendeley is ~5.6 GB. We only need:
  - "Original images/<class>/*.jpg"            (~3.3 GB, clean photos for classification)
  - "Annotated images (...)/<class>/labels/*.txt" (tiny, YOLO boxes, kept for later)
  - "Dataset metadata.xlsx"                     (original filenames -> capture time)

We deliberately SKIP "Annotated images (...)/<class>/visuals/*.jpg": those are
the same photos with red rectangles drawn on them. Training a classifier on
them would teach it to look for red boxes instead of disease.

The S3 host supports HTTP Range requests, so members are read straight out of
the remote ZIP without downloading the whole archive. Standard library only.
Every extracted file is CRC-checked by zipfile. Re-running resumes: files that
already exist with the right size are skipped.

Usage:
  python3 ml/scripts/download_dataset.py                 # everything we need
  python3 ml/scripts/download_dataset.py --limit 20      # quick smoke test
  python3 ml/scripts/download_dataset.py --dry-run       # list what would be fetched
"""

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
import zipfile
from pathlib import Path

DATASET_ID = '86s4jzj2m4'
VERSION = 3
ZIP_NAME = 'RiceLeafDiseaseBD.zip'
EXPECTED_ZIP_SIZE = 5632829086
FILES_API = (f'https://data.mendeley.com/public-api/datasets/{DATASET_ID}'
             f'/files?folder_id=root&version={VERSION}')

READ_AHEAD = 4 * 1024 * 1024  # bytes fetched per HTTP request
RETRIES = 5
HEADERS = {'User-Agent': 'KrishiSathi-dataset-downloader/1.0'}  # default urllib UA gets 403


def wanted(name):
    """Return the local relative path for a ZIP member we keep, else None."""
    if name.endswith('/'):
        return None
    parts = name.split('/')
    if parts[-1] == 'Dataset metadata.xlsx':
        return 'Dataset metadata.xlsx'
    if len(parts) == 4 and parts[1] == 'Original images':
        return f'Original images/{parts[2]}/{parts[3]}'
    if len(parts) == 5 and parts[1].startswith('Annotated images') and parts[3] == 'labels':
        return f'labels/{parts[2]}/{parts[4]}'
    return None


class HttpRangeFile:
    """Minimal seekable read-only file over HTTP Range requests, with read-ahead."""

    def __init__(self, url):
        self.pos = 0
        self.buf_start = 0
        self.buf = b''
        # Probe with a 1-byte range GET: follows the Mendeley -> S3 redirect,
        # gives us the final URL and total size, and proves Range support.
        req = urllib.request.Request(url, headers={**HEADERS, 'Range': 'bytes=0-0'})
        with urllib.request.urlopen(req, timeout=60) as r:
            if r.status != 206:
                raise RuntimeError('Server does not support Range requests')
            self.url = r.geturl()
            self.size = int(r.headers['Content-Range'].rsplit('/', 1)[1])

    def seekable(self):
        return True

    def tell(self):
        return self.pos

    def seek(self, offset, whence=0):
        if whence == 0:
            self.pos = offset
        elif whence == 1:
            self.pos += offset
        else:
            self.pos = self.size + offset
        return self.pos

    def _fetch(self, start, length):
        end = min(start + length, self.size) - 1
        for attempt in range(1, RETRIES + 1):
            try:
                req = urllib.request.Request(self.url, headers={**HEADERS, 'Range': f'bytes={start}-{end}'})
                with urllib.request.urlopen(req, timeout=120) as r:
                    data = r.read()
                if len(data) != end - start + 1:
                    raise IOError(f'short read {len(data)} != {end - start + 1}')
                return data
            except (urllib.error.URLError, IOError, TimeoutError) as e:
                if attempt == RETRIES:
                    raise
                wait = 2 ** attempt
                print(f'  [retry {attempt}/{RETRIES}] {e} - waiting {wait}s', flush=True)
                time.sleep(wait)

    def read(self, n=-1):
        if n is None or n < 0:
            n = self.size - self.pos
        if n == 0 or self.pos >= self.size:
            return b''
        buf_end = self.buf_start + len(self.buf)
        if not (self.buf_start <= self.pos and self.pos + n <= buf_end):
            self.buf_start = self.pos
            self.buf = self._fetch(self.pos, max(n, READ_AHEAD))
        off = self.pos - self.buf_start
        data = self.buf[off:off + n]
        self.pos += len(data)
        return data


def resolve_zip_url():
    with urllib.request.urlopen(urllib.request.Request(FILES_API, headers=HEADERS), timeout=60) as r:
        files = json.load(r)
    entry = next((f for f in files if f['filename'] == ZIP_NAME), None)
    if entry is None:
        sys.exit(f'[ERROR] {ZIP_NAME} not listed in dataset v{VERSION}. Check the Mendeley page.')
    if entry['size'] != EXPECTED_ZIP_SIZE:
        print(f'[WARNING] ZIP size changed: {entry["size"]} (expected {EXPECTED_ZIP_SIZE}). '
              'The dataset may have been updated - re-check the README.')
    return entry['content_details']['download_url']


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--out', default='ml/data/raw/riceleafdiseasebd', help='destination folder')
    ap.add_argument('--limit', type=int, default=0, help='only fetch N images per class (smoke test)')
    ap.add_argument('--dry-run', action='store_true')
    args = ap.parse_args()

    out = Path(args.out)
    print(f'Resolving download URL for {ZIP_NAME} (v{VERSION}) ...')
    zf = zipfile.ZipFile(HttpRangeFile(resolve_zip_url()))

    members = []
    per_class = {}
    for info in zf.infolist():
        rel = wanted(info.filename)
        if rel is None:
            continue
        if args.limit and rel.startswith('Original images/'):
            cls = rel.split('/')[1]
            per_class[cls] = per_class.get(cls, 0) + 1
            if per_class[cls] > args.limit:
                continue
        members.append((info, rel))
    if args.limit:
        keep = {Path(r).stem for _, r in members if r.startswith('Original images/')}
        members = [(i, r) for i, r in members
                   if not r.startswith('labels/') or Path(r).stem in keep]

    # Read in archive order so the read-ahead buffer streams sequentially.
    members.sort(key=lambda m: m[0].header_offset)
    total_bytes = sum(i.file_size for i, _ in members)
    print(f'{len(members)} files selected, {total_bytes / 1e9:.2f} GB uncompressed')
    if args.dry_run:
        for _, rel in members[:20]:
            print('  ', rel)
        return

    done = skipped = 0
    started = time.time()
    for idx, (info, rel) in enumerate(members, 1):
        dest = out / rel
        if dest.exists() and dest.stat().st_size == info.file_size:
            skipped += 1
            continue
        dest.parent.mkdir(parents=True, exist_ok=True)
        tmp = dest.with_name(dest.name + '.part')
        with zf.open(info) as src, open(tmp, 'wb') as dst:  # raises BadZipFile on CRC mismatch
            while chunk := src.read(1 << 20):
                dst.write(chunk)
        os.replace(tmp, dest)
        done += 1
        if done % 200 == 0 or idx == len(members):
            mins = (time.time() - started) / 60
            print(f'  {idx}/{len(members)} files ({mins:.1f} min)', flush=True)

    print(f'\nDone. extracted={done} already_present={skipped} -> {out.resolve()}')
    print('Next: python ml/scripts/inspect_dataset.py ml/data/raw/riceleafdiseasebd')


if __name__ == '__main__':
    main()
