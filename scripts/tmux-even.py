#!/usr/bin/env python3
"""tmux-even.py: even out every split in a tmux window at once (prefix Q in the shared .tmux.conf).

    tmux-even.py [-t PANE] [--tmux BINARY]

Every split in PANE's window shares its space equally among its parts, the outermost split first and each split
inside it after. A split nested in another counts as one part of it, and no pane moves: the result is what prefix q
(tmux's select-layout -E, which evens one split per press, starting at the pane's own) reaches when pressed in the
innermost panes until nothing changes. A size that does not divide evenly gives its first parts one cell more, as tmux
does, and a part that cannot be that small (it holds too many panes) keeps its smallest size while the others share
the rest. Floating panes (tmux 3.8) stay where they are.

It rewrites the window's layout (#{window_layout}: tmux 3.8's JSON, or the checksummed string of older releases) and
applies it with select-layout, which unzooms the window as prefix q does; select-layout -o undoes it. PANE is any pane
target tmux takes (default: the current pane). BINARY is the tmux to run (default: tmux on PATH); the shared
.tmux.conf passes the server's own (/proc/<pid>/exe). It lives beside tmux-kill.py: ~/env-config/scripts at home,
~ctimms/storage/tmux_setup at work. Python 3.6 or later, standard library only.
"""

import argparse
import json
import os
import re
import subprocess
import sys
from typing import Any, Dict, List, Tuple

PROG = os.path.basename(sys.argv[0]) or 'tmux-even.py'
Cell = Dict[str, Any]  # a layout cell as in tmux 3.8's JSON: t (h, v or p), w, h, x, y, c (children), z (floating)
CELL_V1 = re.compile(r'(\d+)x(\d+),(\d+),(\d+)')
PANE_ID_V1 = re.compile(r',(\d+)(?![\dx])')


def parse_v1(text: str, i: int = 0) -> Tuple[Cell, int]:
    """The cell at text[i:] in the older layout string (WxH,X,Y,ID or WxH,X,Y{...} or WxH,X,Y[...]), and its end."""
    m = CELL_V1.match(text, i)
    if not m:
        raise ValueError(f'unexpected layout text: {text[i:i + 30]}')
    cell = dict(zip('whxy', map(int, m.groups())))  # type: Cell
    i = m.end()
    if text[i:i + 1] in ('{', '['):
        cell['t'], close = ('h', '}') if text[i] == '{' else ('v', ']')
        cell['c'] = []
        sep = text[i]
        while sep != close:
            child, i = parse_v1(text, i + 1)
            cell['c'].append(child)
            sep = text[i:i + 1]
            if sep not in (',', close):
                raise ValueError(f'unexpected layout text: {text[i:i + 30]}')
        return cell, i + 1
    cell['t'] = 'p'
    m = PANE_ID_V1.match(text, i)
    if m:
        cell['id'] = m.group(1)
        i = m.end()
    return cell, i


def dump_v1(cell: Cell) -> str:
    text = f"{cell['w']}x{cell['h']},{cell['x']},{cell['y']}"
    if cell['t'] == 'p':
        return text + (f",{cell['id']}" if 'id' in cell else '')
    start, end = '{}' if cell['t'] == 'h' else '[]'
    return text + start + ','.join(dump_v1(child) for child in cell['c']) + end


def checksum_v1(body: str) -> str:
    csum = 0
    for byte in body.encode():
        csum = ((csum >> 1) + ((csum & 1) << 15) + byte) & 0xffff
    return f'{csum:04x}'


def tiled(cell: Cell) -> bool:
    """A pane that is not floating, or a split holding one (what tmux sizes splits by)."""
    if cell['t'] == 'p':
        return 'z' not in cell
    return any(tiled(child) for child in cell['c'])


def smallest(cell: Cell, key: str) -> int:
    """The least width (key w) or height (key h) cell can have: a cell per pane, plus the borders between them."""
    if cell['t'] == 'p':
        return 1
    sizes = [smallest(child, key) for child in cell['c'] if tiled(child)]
    if (cell['t'] == 'h') == (key == 'w'):
        return sum(sizes) + len(sizes) - 1
    return max(sizes)


def share(size: int, least: List[int]) -> List[int]:
    """size, less a border between each two parts, split as evenly as least (each part's smallest size) allows."""
    fixed = {}  # type: Dict[int, int]
    while True:
        free = [i for i in range(len(least)) if i not in fixed]
        if not free:
            raise ValueError('the window is too small to even out')
        each, extra = divmod(size - (len(least) - 1) - sum(fixed.values()), len(free))
        small = [i for i in free if least[i] > each]
        if not small:
            break
        fixed.update((i, least[i]) for i in small)
    sizes = []
    for i in range(len(least)):
        if i in fixed:
            sizes.append(fixed[i])
        else:
            sizes.append(each + (1 if extra > 0 else 0))
            extra -= 1
    return sizes


def even(cell: Cell, x: int, y: int, w: int, h: int) -> None:
    """Place cell at x, y with size w x h, sharing its space equally among its parts and theirs."""
    cell.update(x=x, y=y, w=w, h=h)
    if cell['t'] == 'p':
        return
    parts = [child for child in cell['c'] if tiled(child)]
    across = cell['t'] == 'h'
    sizes = share(w if across else h, [smallest(part, 'w' if across else 'h') for part in parts])
    at = x if across else y
    for part, size in zip(parts, sizes):
        if across:
            even(part, at, y, size, h)
        else:
            even(part, x, at, w, size)
        at += size + 1


def evened(layout: str) -> str:
    """layout with every split evened out, in the same format."""
    if layout.startswith('{'):
        data = json.loads(layout)
        root = data['L']
        even(root, root['x'], root['y'], root['w'], root['h'])
        return json.dumps(data, separators=(',', ':'))
    body = layout.split(',', 1)[1] if ',' in layout else ''
    root, end = parse_v1(body)
    if end != len(body):
        raise ValueError(f'unexpected layout text: {body[end:end + 30]}')
    even(root, root['x'], root['y'], root['w'], root['h'])
    body = dump_v1(root)
    return f'{checksum_v1(body)},{body}'


def main(argv: List[str]) -> int:
    parser = argparse.ArgumentParser(prog=PROG, description='Even out every split in a tmux window at once, keeping '
                                     'its layout (prefix Q in the shared .tmux.conf).')
    parser.add_argument('-t', dest='target', metavar='PANE', help='a pane in the window (default: the current pane)')
    parser.add_argument('--tmux', default='tmux', metavar='BINARY', help='the tmux to run (default: tmux on PATH)')
    args = parser.parse_args(argv)
    target = ['-t', args.target] if args.target else []
    try:
        p = subprocess.run([args.tmux, 'display-message', '-p'] + target + ['#{window_layout}'],
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
    except OSError as e:
        print(f'{PROG}: {args.tmux}: {e.strerror}', file=sys.stderr)
        return 1
    if p.returncode != 0:
        print(f'{PROG}: {p.stderr.strip() or "tmux could not show the layout"}', file=sys.stderr)
        return 1
    try:
        layout = evened(p.stdout.strip())
    except (ValueError, KeyError, TypeError) as e:
        print(f'{PROG}: {e}', file=sys.stderr)
        return 1
    p = subprocess.run([args.tmux, 'select-layout'] + target + [layout], stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE, universal_newlines=True)
    if p.returncode != 0:
        print(f'{PROG}: {p.stderr.strip() or "tmux did not take the new layout"}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        sys.exit(130)

