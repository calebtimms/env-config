#!/usr/bin/env python3
"""git-helpers.py: the shared zsh setup's Git diff and log helpers, for any shell.

    git-helpers.py gdc   [git-diff-options]                 show a simplified working-tree diff
    git-helpers.py gdo   [git-diff-options]                 the same against origin's default branch
    git-helpers.py gdco  [FILE] [git-diff-options]          write the simplified diff to ./git-diff-commit
    git-helpers.py gdoo  [FILE] [git-diff-options]          write it against origin to ./git-diff-origin
    git-helpers.py gla   [-me] [git-log-options]            show the graph history of all refs
    git-helpers.py glf   [-me] [git-log-options]            the same with each commit's changed files
    git-helpers.py glo   [-me] [git-log-options]            the commits not yet in the upstream branch
    git-helpers.py glao  [FILE] [-me] [git-log-options]     write gla's history to ./git-log-all
    git-helpers.py glfo  [FILE] [-me] [git-log-options]     write glf's to ./git-log-files
    git-helpers.py gloo  [FILE] [-me] [git-log-options]     write glo's to ./git-log-origin

A simplified diff is git diff's output with each per-file header cut to `diff <path>` (the a/ b/ prefixes dropped, and
diff.mnemonicPrefix's c/ i/ o/ w/ 1/ 2/), its index, new file mode, --- and +++ lines dropped, and each hunk header
replaced by `@ Hunk N @`: for reading or sharing, not an apply-ready patch. Colored lines keep their color. On a
terminal, gdc and gdo color it as git diff would (color.diff) and page it through Git's pager (core.pager, GIT_PAGER,
PAGER; LESS=FRX and LV=-c when unset, as Git sets them); elsewhere they print it as Git writes it to a pipe. gdo and
gdoo compare with origin's default branch: the locally recorded origin/HEAD, else the first existing origin/main,
origin/master or origin. They do not fetch.

The graph history (gla, glf, glo) is git log --graph --decorate, one line a commit: hash, age, subject, author and
refs. gla shows every ref (--all), glf adds the names of the files each commit changed (--name-only), and glo shows the
commits on HEAD that have not reached its upstream branch (@{u}..HEAD). They run git log itself, which colors and pages
it on a terminal as it always does; glao, glfo and gloo write the same history to a file instead, as gdco and gdoo do
the diff. -me, anywhere before a --, stands for --author=<git config user.name>, so gla -n 10 -me shows your 10 most
recent commits.

The writers (gdco, gdoo, glao, glfo, gloo) take an output file as their first argument when it does not start with
-; a first -- is dropped and keeps the default file, so gdoo -- src/ and glao -- main pass src/ and main on to Git.
They replace the file only when Git succeeds (through a temporary file renamed over it), refuse to overwrite a file Git
tracks (a path meant for Git, given without --), and print what they wrote. Their exit status is Git's.

The zsh names (gdc, gdo, gdco, gdoo, gla, glf, glo, glao, glfo, gloo) are thin functions over this program in the
.zshrc; it lives in ~/env-config/scripts at home (on PATH through ~/.zshrc), ~ctimms/storage/zsh_setup at work. Python
3.6 or later, standard library only.
"""

import os
import re
import stat
import subprocess
import sys
import tempfile
from typing import IO, List, Optional

COMMANDS = ('gdc', 'gdo', 'gdco', 'gdoo', 'gla', 'glf', 'glo', 'glao', 'glfo', 'gloo')
OUTPUT = {'gdco': './git-diff-commit', 'gdoo': './git-diff-origin', 'glao': './git-log-all',
          'glfo': './git-log-files', 'gloo': './git-log-origin'}
LOG_FORMAT = ('%C(red)%H%C(reset) - %C(green)(%ar)%C(reset) %C(white)%s%C(reset) %C(bold italic white)- %an%C(reset)'
              '%C(auto)%d%C(reset)')

SGR = re.compile(rb'\033\[[0-9;]*m')
LEADING_SGR = re.compile(rb'^(?:\033\[[0-9;]*m)+')
FILE_HEADER = re.compile(rb'^(?:index |new file mode |--- |\+\+\+ )')
PATH_PREFIX = re.compile(rb'^[abciow12]/')
BLANKS = re.compile(rb'[ \t\n]+')


def usage() -> str:
    return __doc__.split('\n\n')[1].replace('    git-helpers.py', 'git-helpers.py') + '\n'


def git(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(['git', *args], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)


class Simplifier:
    """git diff's lines made simpler, one at a time (see the top of this file)."""

    def __init__(self) -> None:
        self.files = self.hunk = 0
        self.header = False

    def line(self, line: bytes) -> Optional[bytes]:
        """The line (without its newline) as shown, or None when it is dropped."""
        plain = SGR.sub(b'', line)
        m = LEADING_SGR.match(line)
        color = m.group(0) if m else b''
        reset = b'\033[m' if color else b''
        if plain.startswith(b'diff --git '):
            words = [w for w in BLANKS.split(plain) if w]
            path = PATH_PREFIX.sub(b'', words[2] if len(words) > 2 else b'', count=1)
            gap = b'\n' if self.files else b''
            self.files += 1
            self.hunk, self.header = 0, True
            return gap + color + b'diff ' + path + reset
        if self.header and FILE_HEADER.match(plain):
            return None
        if plain.startswith(b'@@ '):
            self.header = False
            self.hunk += 1
            return color + b'@ Hunk ' + str(self.hunk).encode() + b' @' + reset
        return line


def simplify(source: IO[bytes], sink: IO[bytes]) -> int:
    """Copy git diff's output to sink, simplified; the number of lines written."""
    s, n = Simplifier(), 0
    for raw in iter(source.readline, b''):
        out = s.line(raw[:-1] if raw.endswith(b'\n') else raw)
        if out is not None:
            sink.write(out + b'\n')
            n += out.count(b'\n') + 1
    return n


def origin_ref() -> Optional[str]:
    """origin's default branch: origin/HEAD, else the first of origin/main, origin/master, origin; None (said why)
    when there is none."""
    if subprocess.run(['git', 'rev-parse', '--git-dir'], stdout=subprocess.DEVNULL).returncode:
        return None
    p = git('symbolic-ref', '--quiet', '--short', 'refs/remotes/origin/HEAD')
    if p.returncode == 0:
        return p.stdout.decode().strip()
    for ref in ('origin/main', 'origin/master', 'origin'):
        if git('rev-parse', '--verify', '--quiet', ref).returncode == 0:
            return ref
    print('No origin remote-tracking reference found.', file=sys.stderr)
    return None


def show_diff(args: List[str]) -> int:
    """gdc and gdo: the simplified diff, colored and paged on a terminal."""
    if not os.isatty(1):
        p = subprocess.Popen(['git', 'diff', *args], stdout=subprocess.PIPE)
        simplify(p.stdout, sys.stdout.buffer)
        sys.stdout.buffer.flush()
        return p.wait()
    color = 'always' if git('config', '--get-colorbool', 'color.diff', 'true').stdout.strip() == b'true' else 'never'
    pager = git('var', 'GIT_PAGER').stdout.decode().strip() or 'cat'
    env = dict(os.environ)
    env.setdefault('LESS', 'FRX')  # as git sets them for its pager when unset
    env.setdefault('LV', '-c')
    diff = subprocess.Popen(['git', 'diff', f'--color={color}', *args], stdout=subprocess.PIPE, env=env)
    view = None if pager == 'cat' else subprocess.Popen(pager, shell=True, stdin=subprocess.PIPE, env=env)
    try:
        simplify(diff.stdout, view.stdin if view else sys.stdout.buffer)
        if view:
            view.stdin.close()
        else:
            sys.stdout.buffer.flush()
    except BrokenPipeError:  # the pager quit early (q in less): stop git too
        diff.kill()
        diff.wait()
        if view:
            view.wait()
        return 0
    status = diff.wait()
    return view.wait() or status if view else status


def tracked(path: str) -> bool:
    return subprocess.run(['git', 'ls-files', '--error-unmatch', '--', path], stdout=subprocess.DEVNULL,
                          stderr=subprocess.DEVNULL).returncode == 0


def write(name: str, args: List[str], run: List[str], diff: bool) -> int:
    """gdco, gdoo, glao, glfo, gloo: Git's output (simplified for a diff) written to the file the first argument
    names, else to the command's own (OUTPUT); run is the Git command, args go after it."""
    out = OUTPUT[name]
    if args[:1] == ['--']:
        args = args[1:]
    elif args and not args[0].startswith('-'):
        out, args = args[0], args[1:]
    if os.path.lexists(out) and tracked(out):
        print(f'{name}: {out} is tracked by Git, so it was not overwritten (to pass it to Git, put -- first: '
              f'{name} -- {out})', file=sys.stderr)
        return 1
    # Written beside the file and renamed over it once Git succeeds, so a failed run leaves the old file. A link or
    # anything else that is not a plain file is written through, as > would.
    # A file in a directory this cannot write to is written in place too.
    tmp = None
    try:
        if not os.path.lexists(out) or stat.S_ISREG(os.lstat(out).st_mode):
            try:
                fd, tmp = tempfile.mkstemp(prefix=f'.{os.path.basename(out)}.', dir=os.path.dirname(out) or '.')
            except PermissionError:
                if not os.path.exists(out):
                    raise
        if tmp is None:
            fd = os.open(out, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o666)
    except OSError as e:
        print(f'{name}: {out}: {e.strerror}', file=sys.stderr)
        return 1
    try:
        with os.fdopen(fd, 'wb') as f:
            p = subprocess.Popen(['git', *run, *args], stdout=subprocess.PIPE)
            lines = simplify(p.stdout, f) if diff else copy(p.stdout, f)
            status = p.wait()
        if status:
            return status
        if tmp:
            if os.path.exists(out):
                os.chmod(tmp, stat.S_IMODE(os.stat(out).st_mode))
            else:
                mask = os.umask(0)
                os.umask(mask)
                os.chmod(tmp, 0o666 & ~mask)
            os.replace(tmp, out)
            tmp = None
    finally:
        if tmp:
            os.unlink(tmp)
    print(f"{name}: wrote {lines} line{'' if lines == 1 else 's'} to {out}")
    return 0


def copy(source: IO[bytes], sink: IO[bytes]) -> int:
    """Copy source to sink; the number of lines (a last one without a newline counts too)."""
    lines, last = 0, b'\n'
    for chunk in iter(lambda: source.read(65536), b''):
        sink.write(chunk)
        lines += chunk.count(b'\n')
        last = chunk[-1:]
    return lines + (last != b'\n')


def me(name: str, args: List[str]) -> Optional[List[str]]:
    """args with each -me before any -- replaced by --author=<git config user.name>; None (said why) without one."""
    out, user = [], None  # type: List[str], Optional[str]
    for i, arg in enumerate(args):
        if arg == '--':
            return out + args[i:]
        if arg == '-me':
            if user is None:
                p = git('config', 'user.name')
                if p.returncode:
                    print('No git config user.name found for -me.', file=sys.stderr)
                    return None
                user = p.stdout.decode().rstrip('\n')
            arg = f'--author={user}'
        out.append(arg)
    return out


def main(argv: List[str]) -> int:
    if not argv or argv[0] in ('-h', '--help'):
        (sys.stdout if argv else sys.stderr).write(usage())
        return 0 if argv else 2
    name, args = argv[0], argv[1:]
    if name not in COMMANDS:
        sys.stderr.write(f'git-helpers.py: unknown command: {name}\n{usage()}')
        return 2
    if name in ('gdo', 'gdoo'):
        ref = origin_ref()
        if ref is None:
            return 1
    if name == 'gdc':
        return show_diff(args)
    if name == 'gdo':
        return show_diff([ref, *args])
    if name in ('gdco', 'gdoo'):
        return write(name, args, ['diff', *([ref] if name == 'gdoo' else [])], diff=True)
    # gla, glf, glo and their writers glao, glfo, gloo, whose file comes first; then -me is expanded in the rest.
    kind, out = name[:3], []  # type: str, List[str]
    if name in OUTPUT:
        if args[:1] == ['--']:
            args = args[1:]
        elif args and not args[0].startswith('-'):
            out, args = args[:1], args[1:]
    if kind == 'glf':
        args = ['--name-only', *args]
    args = me(name, args)
    if args is None:
        return 1
    run = ['log', '--graph', '--decorate', f'--format=tformat:{LOG_FORMAT}',
           *(['@{u}..HEAD'] if kind == 'glo' else ['--all'])]
    if name not in OUTPUT:   # git log itself, with its own pager and colors on a terminal
        try:
            os.execvp('git', ['git', *run, *args])
        except OSError as e:
            print(f'{name}: git: {e.strerror}', file=sys.stderr)
            return 127
    return write(name, [*(out or ['--']), *args], run, diff=False)


if __name__ == '__main__':
    try:
        sys.exit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        sys.exit(130)
    except BrokenPipeError:
        os.dup2(os.open(os.devnull, os.O_WRONLY), 1)
        sys.exit(141)


