#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Convert a '# %%' percent-format .py file into a Colab-ready .ipynb (stdlib only).

Usage:
  python ml/scripts/py_to_ipynb.py ml/notebooks/train_rice_classifier.py
"""

import json
import sys
from pathlib import Path


def convert(src):
    cells, kind, lines = [], None, []

    def flush():
        while lines and not lines[-1].strip():
            lines.pop()
        if kind and lines:
            text = [ln[2:] if kind == 'markdown' and ln.startswith('# ') else
                    ('' if kind == 'markdown' and ln.strip() == '#' else ln) for ln in lines]
            source = [ln + '\n' for ln in text[:-1]] + [text[-1]]
            cell = {'cell_type': kind, 'metadata': {}, 'source': source}
            if kind == 'code':
                cell.update(execution_count=None, outputs=[])
            cells.append(cell)

    for line in Path(src).read_text(encoding='utf-8').splitlines():
        if line.startswith('# %%'):
            flush()
            kind, lines = ('markdown' if '[markdown]' in line else 'code'), []
        elif kind:
            if not lines and not line.strip():
                continue
            lines.append(line)
    flush()

    return {
        'nbformat': 4, 'nbformat_minor': 5, 'cells': cells,
        'metadata': {
            'accelerator': 'GPU',
            'colab': {'provenance': [], 'gpuType': 'T4'},
            'kernelspec': {'name': 'python3', 'display_name': 'Python 3'},
            'language_info': {'name': 'python'},
        },
    }


if __name__ == '__main__':
    src = Path(sys.argv[1])
    out = src.with_suffix('.ipynb')
    nb = convert(src)
    out.write_text(json.dumps(nb, indent=1, ensure_ascii=False) + '\n', encoding='utf-8')
    print(f'{out} ({len(nb["cells"])} cells)')
