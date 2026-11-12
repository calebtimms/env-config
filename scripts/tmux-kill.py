#!/usr/bin/env python3
"""tmux-kill.py: save a tmux server's sessions with tmux-resurrect, then end the server.

    tmux-kill.py [SERVER]     save SERVER's sessions, then tmux -L SERVER kill-server
    tmux-kill.py --list       the running servers: name, pid and sessions, a line each

Ending a server ends its sessions and closes every terminal attached to it. Without SERVER, it is the server this shell
is in ($TMUX), else the one for this Cheetah environment ($DDG_FAMILY, as the work .zshrc starts it), else default.
The save runs only when the server has tmux-resurrect loaded (its @resurrect-save-script-path, as the shared tmux setup
loads it), so the next server with that name restores the sessions when it starts; a save that fails leaves the server
running. Both steps run the server's own binary (/proc/<pid>/exe), so they still work after tool-update tmux installs
a release that cannot talk to the running server; the save script, which runs the tmux on PATH against $TMUX, gets
both pointed at that server. Servers are found through ss, from their listening sockets in
${TMUX_TMPDIR:-/tmp}/tmux-<uid>/, so a socket left by a server that died does not count.

TMUX_KILL_PROG names the command in messages (the shared .zshrc's tmux-kill sets it to tmux-kill); else it is this
file's name. It lives beside tmux-project: ~/env-config/scripts at home (on PATH through ~/.zshrc),
~ctimms/storage/tmux_setup at work. Python 3.6 or later, standard library only.
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile
from typing import Dict, List

PROG = os.path.basename(sys.argv[0]) or 'tmux-kill.py'  # main() takes TMUX_KILL_PROG instead when it is set


def socket_dir() -> str:
    return f"{os.environ.get('TMUX_TMPDIR') or '/tmp'}/tmux-{os.getuid()}"


def servers() -> Dict[str, int]:
    """{name: pid} of the running servers, whose sockets ss shows listening (stale ones are not)."""
    try:
        out = subprocess.run(['ss', '-xlpH'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout
    except FileNotFoundError:
        return {}
    pattern = re.compile(' ' + re.escape(socket_dir() + '/') + r'([^ /]+) .*pid=([0-9]+),')
    found = {}  # type: Dict[str, int]
    for line in out.decode('utf-8', 'replace').splitlines():
        m = pattern.search(line)
        if m:
            found[m.group(1)] = int(m.group(2))
    return found


def sessions(name: str, pid: int) -> List[str]:
    p = subprocess.run([f'/proc/{pid}/exe', '-L', name, 'list-sessions', '-F', '#{session_name}'],
                       stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    return p.stdout.decode('utf-8', 'replace').split('\n')[:-1] if p.returncode == 0 else []


def usage() -> str:
    default = os.environ.get('DDG_FAMILY') or 'default'
    return (f'Usage: {PROG} [server] | {PROG} --list\n'
            "Save a tmux server's sessions (tmux-resurrect), then end it (tmux -L server kill-server) and close every "
            f'terminal attached to it. Without a server, the one this shell is in, else {default}. --list lists the '
            'running servers: name, pid and sessions.')


def main(argv: List[str]) -> int:
    global PROG
    PROG = os.environ.pop('TMUX_KILL_PROG', '') or PROG
    if argv[:1] in (['-h'], ['--help']):
        print(usage())
        return 0
    if argv == ['--list']:
        for name, pid in sorted(servers().items()):
            print(f"{name}\t{pid}\t{', '.join(sessions(name, pid))}")
        return 0
    if len(argv) > 1 or argv and argv[0].startswith('-'):
        print(usage(), file=sys.stderr)
        return 2
    tmux = os.environ.get('TMUX', '').split(',')[0]
    server = argv[0] if argv else os.path.basename(tmux) or os.environ.get('DDG_FAMILY') or 'default'
    pid = servers().get(server)
    if pid is None:
        print(f'{PROG}: no tmux server named {server} is running', file=sys.stderr)
        return 1
    exe = f'/proc/{pid}/exe'
    save = subprocess.run([exe, '-L', server, 'show', '-gqv', '@resurrect-save-script-path'], stdout=subprocess.PIPE,
                          stderr=subprocess.DEVNULL).stdout.decode().rstrip('\n')
    if save and os.access(save, os.X_OK):
        # The save script runs the tmux on PATH against $TMUX: point both at this server.
        bin_dir = None
        try:
            bin_dir = tempfile.mkdtemp()
            os.symlink(exe, os.path.join(bin_dir, 'tmux'))
            env = dict(os.environ, TMUX=f'{socket_dir()}/{server},{pid},0',
                       PATH=f"{bin_dir}:{os.environ.get('PATH', '')}")
            env.pop('TMUX_PANE', None)
            saved = subprocess.run([save, 'quiet'], env=env).returncode == 0
        except OSError:
            saved = False
        finally:
            if bin_dir:
                shutil.rmtree(bin_dir, ignore_errors=True)
        if not saved:
            print(f'{PROG}: could not save {server}, so it was left running', file=sys.stderr)
            return 1
    return subprocess.run([exe, '-L', server, 'kill-server']).returncode


if __name__ == '__main__':
    try:
        sys.exit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        sys.exit(130)

