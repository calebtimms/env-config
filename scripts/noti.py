#!/usr/bin/env python3
"""noti.py: run a command with a log of its own, then email its result; follow those logs.

    noti.py [-f] COMMAND [ARGS...]           run COMMAND in the background (here and waited for with -f), then email
    noti.py [-f] -c|-- 'SHELL EXPRESSION'    the same for an expression, which $SHELL -c runs
    noti.py -l|--list                        list the runs started in this directory, newest first, numbered
    noti.py -t|--tail [N | NAME]             follow a run started here: the newest still running, else the newest

In the background, each run writes its own log, $NOTI_LOG_DIR/by-path/<physical directory>/noti.<name>.<YYMMDD-HHMMSS>
.log (.1.log, .2.log... when a run started in the same second holds that name; the name is claimed atomically), where
<name> is the command's (an expression's first word), and noti.py prints its path and returns at once. The log starts
with a header (Command, Directory, Result, Start Time, End Time, Duration), then the command's stdout and stderr under
Output:, or (none). While the command runs, Result says Running and the times -; when it ends they are filled in, in
place (the fields are padded to fixed widths), and Result is Passed, Failed or Killed by SIG<name>, with the exit code.
Then the log is rewritten as a terminal would have shown it: each line keeps only its text after its last carriage
return (a progress bar leaves its final state), and escape sequences (colors, cursor moves) go. The cleaned copy is
renamed over the log, so a follower (tail -f, -t) keeps reading the raw file it has open. The command's stdin is
/dev/null, so a read gets end-of-file instead of stopping it. The email, to NOTI_EMAIL, else WORK_EMAIL (required; the
work zsh template's placeholder address counts as unset), through mailx or else mail, has a title line, then the same
fields, the last 20 lines of output and the log path, each section's lines after a bullet (so a long line that Outlook
wraps never reads as the next one), and a signature naming noti and the host. A mail failure is noted at the end of the
log.

Run from a shell other than the shared zsh setup's, a background run is detached from the terminal (it outlives it) and
noti.py prints its pid: kill <pid> stops it, and the email says Killed by SIGTERM; HUP and INT are reported the same
way. Only kill -9 leaves no email, and a log that still says Running. -f runs the command here, with the terminal, and
emails Command, Directory, Result and Time; Ctrl+C stops it without an email, and noti.py -f returns its exit status.

-l lists this directory's runs (as started from its physical path): number, result, start time and command. -t follows
one: the newest still running (and says how many are), else the newest; NAME picks among one command's runs (the name
in noti.<name>..., so ./run_tests finds run_tests), N the Nth in -l's list. For a running job it shows the last 20
lines and follows the output, progress bars and colors included, until the job ends, then prints its result; Ctrl+C
stops only the following. For a finished run it shows the last 20 lines of the cleaned log and the result. A job ended
with kill -9 (or a reboot) leaves its log saying Running, so -t follows it until Ctrl+C.

Settings come from the environment: NOTI_EMAIL (else WORK_EMAIL), NOTI_LOG_DIR (default $WORK_STORAGE_ROOT/.noti_logs
when WORK_STORAGE_ROOT is set, as at work, else ~/.noti_logs), and NOTI_PROG, the name messages use (the .zshrc's noti
and tn set it); none is passed on to the command. The .zshrc's noti and tn are thin functions over this program, which
lives in ~/env-config/scripts at home (on PATH through ~/.zshrc), ~ctimms/storage/zsh_setup at work; its noti keeps
what only zsh can do: the command is a job of that shell (jobs, kill %N), an expression sees its variables and
functions, and -f runs in it (a cd stays). Python 3.6 or later, standard library only.
"""

import os
import re
import shutil
import signal
import socket
import stat
import subprocess
import sys
import time
import traceback
from typing import Dict, List, Optional, Tuple

PROG = os.path.basename(sys.argv[0]) or 'noti.py'  # main() takes NOTI_PROG instead when it is set
PLACEHOLDER = 'firstname.lastname@intel.com'  # the address the shared zsh template once set: no one's to mail
LOG_NAME = re.compile(r'noti\.(.+)\.([0-9]{6}-[0-9]{6})(?:\.([0-9]+))?\.log')
ESCAPE = re.compile(rb'\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07\x1b\n]*(?:\x07|\x1b\\)?|[()*+][^\n]|[^\n])?')
TRAILING_CR = re.compile(rb'\r+(?=\n?\Z)')
UP_TO_CR = re.compile(rb'[^\n]*\r')
OUTPUT = b'\n\nOutput:\n'  # what ends the header


def usage() -> str:
    return (f"Usage:\t{PROG} [-f] <command> [args...]\n\t{PROG} [-f] -c '<shell expression>'\n"
            f"\t{PROG} [-f] -- '<shell expression>'\n\t{PROG} -l|--list\n\t{PROG} -t|--tail [N | name]\n"
            'Options:\n\t-f, --foreground\tRun here and wait instead of in the background.\n'
            "\t-l, --list\t\tList this directory's noti logs, newest first, numbered.\n"
            '\t-t, --tail\t\tFollow the newest run here still running, else the newest (or the Nth, or name\'s).')


def say(text: str) -> None:
    print(f'{PROG}: {text}', file=sys.stderr)


# --- Settings and names ----------------------------------------------------------------------------------------------


def work_email() -> Optional[str]:
    """NOTI_EMAIL, else WORK_EMAIL, when it is a real address; else None, and why on stderr."""
    mail = os.environ.get('NOTI_EMAIL') or os.environ.get('WORK_EMAIL', '')
    if mail and mail != PLACEHOLDER:
        return mail
    state = f"still the template's placeholder, {mail}" if mail else 'not configured'
    say(f'the email address is {state}; set NOTI_EMAIL (~/.zshrc) or WORK_EMAIL (~/.zshrc.local at work).')
    return None


def log_root() -> str:
    storage = os.environ.get('WORK_STORAGE_ROOT')
    default = f'{storage}/.noti_logs' if storage else os.path.expanduser('~/.noti_logs')
    return os.environ.get('NOTI_LOG_DIR') or default


def logical_cwd() -> str:
    """The current directory as the shell names it ($PWD, symbolic links kept), when PWD is right."""
    pwd = os.environ.get('PWD', '')
    try:
        if pwd.startswith('/') and os.path.samestat(os.stat(pwd), os.stat('.')):
            return pwd
    except OSError:
        pass
    return os.getcwd()


def by_path() -> str:
    """This directory's log directory: by-path/<physical path> ("/" is __root__), as the shared zsh's vl keeps
    sessions."""
    return os.path.join(log_root(), 'by-path', os.getcwd().lstrip('/') or '__root__')


def file_name(name: str) -> str:
    """A command name as it goes in a log's name: each character but letters, digits, . _ and - made _."""
    return re.sub(r'[^\w.-]', '_', name)


def visible(text: str) -> str:
    """Control characters shown as zsh's (V) shows them: \\n, \\t, ^[, ^?..."""
    out = []
    for c in text:
        o = ord(c)
        if c == '\n':
            out.append('\\n')
        elif c == '\t':
            out.append('\\t')
        elif o < 32:
            out.append('^' + chr(o + 64))
        elif o == 127:
            out.append('^?')
        elif o > 127 and not c.isprintable():
            out.append(f'\\u{o:04x}')
        else:
            out.append(c)
    return ''.join(out)


def now_text(epoch: float) -> str:
    return time.strftime('%Y-%m-%d %H:%M:%S %Z', time.localtime(epoch))


def header(command: str, directory: str, result: str, start: str, end: str, duration: str) -> str:
    """The fields that head a log and its email. Result, End Time and Duration are padded to fixed widths, so the
    finished header is exactly as long as the running one and can be written over it in place."""
    return (f"{'Command:':<12}{visible(command)}\n{'Directory:':<12}{visible(directory)}\n"
            f"{'Result:':<12}{result[:33]:<33}\n{'Start Time:':<12}{start}\n{'End Time:':<12}{end[:25]:<25}\n"
            f"{'Duration:':<12}{duration[:9]:<9}\n")


def read_header(log: str) -> Dict[str, str]:
    """The header's fields (Command, Result, Start Time...), padding trimmed; {} until the job has written it."""
    try:
        with open(log, 'rb') as f:
            lines = [f.readline() for _ in range(6)]
    except OSError:
        return {}
    fields = {}
    for line in lines:
        text = line.decode('utf-8', 'surrogateescape').rstrip('\n')
        key, _, value = text.partition(':')
        fields[key] = value.strip(' ')
    return fields if fields.get('Result') else {}


def running(log: str) -> bool:
    """Whether the log's job has not ended, including before it writes the header."""
    return os.path.isfile(log) and read_header(log).get('Result', 'Running') == 'Running'


# --- Logs ------------------------------------------------------------------------------------------------------------


def new_log(prefix: str) -> Optional[str]:
    """A new empty log, prefix.<YYMMDD-HHMMSS>.log, or .1.log, .2.log... when runs started in the same second already
    hold that name. Creation is atomic, so runs never share a log."""
    base = f"{prefix}.{time.strftime('%y%m%d-%H%M%S')}"
    try:
        os.makedirs(os.path.dirname(prefix), exist_ok=True)
    except OSError:
        return None
    n = 0
    while True:
        log = f'{base}.{n}.log' if n else f'{base}.log'
        try:
            os.close(os.open(log, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o666))
            return log
        except FileExistsError:
            n += 1
        except OSError:
            return None


def tidy(log: str) -> None:
    """Rewrite a finished log as a terminal showed it: each line keeps only its text after the last carriage return
    (spinners, progress bars), and escape sequences (colors, cursor moves) are dropped. The cleaned copy is renamed over
    the log, so a follower keeps the raw file it has open instead of seeing the log shrink."""
    with open(log, 'rb') as f:
        data = f.read()
    if b'\r' not in data and b'\x1b' not in data:
        return
    out = []
    parts = data.split(b'\n')  # lines end at newlines only, as perl reads them
    for line in [part + b'\n' for part in parts[:-1]] + ([parts[-1]] if parts[-1] else []):
        if b'\r' in line or b'\x1b' in line:
            line = ESCAPE.sub(b'', line)
            line = TRAILING_CR.sub(b'', line, count=1)
            line = UP_TO_CR.sub(b'', line, count=1)
        out.append(line)
    clean = log + '.tidy'
    with open(clean, 'wb') as f:
        f.write(b''.join(out))
    os.chmod(clean, stat.S_IMODE(os.stat(log).st_mode))
    os.rename(clean, log)


def last_lines(f, n: int, start: int = 0) -> bytes:
    """The last n lines of the open file f from offset start on, as tail -n shows them (a last line without a
    newline counts); f is left at its end."""
    end = f.seek(0, os.SEEK_END)
    pos, data = end, b''
    while pos > start and (data[:-1] if data.endswith(b'\n') else data).count(b'\n') < n:
        step = min(65536, pos - start)
        pos -= step
        f.seek(pos)
        data = f.read(step) + data
    f.seek(end)
    body = data[:-1] if data.endswith(b'\n') else data
    cut = len(body)
    for _ in range(n):
        cut = body.rfind(b'\n', 0, cut)
        if cut < 0:
            return data
    return data[cut + 1:]


# --- Mail ------------------------------------------------------------------------------------------------------------


def section(title: str, items: List[bytes]) -> bytes:
    """One section of an email in grdlnoti.py's layout: a blank line, the title, then each line after a bullet;
    nothing when there are no lines."""
    if not items:
        return b''
    return b'\n' + title.encode() + b'\n' + b''.join('• '.encode() + item + b'\n' for item in items)


def send_mail(subject: str, body: bytes, to: str) -> bool:
    mailer = shutil.which('mailx') or shutil.which('mail')
    if not mailer:
        say('neither mailx nor mail is available')
        return False
    try:
        return subprocess.run([mailer, '-s', subject, to], input=body).returncode == 0
    except OSError:
        return False


def report(name: str, command: str, directory: str, status: str, result: str, start: str, end: str, duration: str,
           tail: Optional[List[bytes]], log: Optional[str], to: str) -> bool:
    """Email the result, laid out as grdlnoti.py's emails are."""
    enc = lambda text: text.encode('utf-8', 'surrogateescape')  # noqa: E731
    body = enc(f"{name} {result.lower()} in {os.path.basename(directory.rstrip('/')) or '/'}\n")
    body += section('Command', [enc(visible(command))]) + section('Directory', [enc(visible(directory))])
    body += section('Result', [enc(status)])
    body += section('Time', [enc(f'Start Time  {start}'), enc(f'End Time    {end}'), enc(f'Duration    {duration}')])
    body += section('Last 20 Lines of Output', tail or []) + section('Log', [enc(log)] if log else [])
    body += enc(f"\n-- \nnoti on {socket.gethostname().split('.')[0]}\n")
    return send_mail(f'Noti {result}: {name} [{os.path.basename(directory.rstrip("/"))}]', body, to)


def outcome(status: int, signame: str) -> Tuple[str, str]:
    """The result (Passed, Failed, Killed) and the status line, as Killed by SIGTERM (exit code 143)."""
    result = 'Killed' if signame else 'Failed' if status else 'Passed'
    return result, f"{result}{' by SIG' + signame if signame else ''} (exit code {status})"


def duration_text(seconds: int) -> str:
    return f'{seconds // 3600:02d}:{seconds % 3600 // 60:02d}:{seconds % 60:02d}'


# --- Running ---------------------------------------------------------------------------------------------------------


def start(name: str, command: str) -> Optional[Tuple[str, int]]:
    """A new log for a run of command, its header saying Running: (its path, the start time); None, and why on
    stderr, when it cannot be created."""
    t0 = int(time.time())
    log_dir = by_path()
    log = new_log(os.path.join(log_dir, f'noti.{file_name(name)}'))
    if log is None:
        say(f'could not create a log in {log_dir}')
        return None
    with open(log, 'w', encoding='utf-8', errors='surrogateescape') as f:
        f.write(header(command, logical_cwd(), 'Running', now_text(t0), '-', '-') + '\nOutput:\n')
    return log, t0


def finish(name: str, log: str, t0: int, status: int, signame: str, to: str) -> None:
    """A background run has ended: clean its log, fill in its header, and email the result. stdout and stderr are
    the log's from then on (a mail failure is noted there)."""
    with open(log, 'rb') as f:
        head = f.read(65536)
    fields = [line[12:].decode('utf-8', 'surrogateescape') for line in head.split(b'\n')[:6]]
    command, directory, begun = fields[0], fields[1], fields[3]
    end = time.time()
    result, text = outcome(status, signame)
    duration = duration_text(int(end) - t0)
    tidy(log)
    fd = os.open(log, os.O_WRONLY | os.O_APPEND)  # the cleaned copy, now in the raw log's place
    sys.stdout.flush()
    sys.stderr.flush()
    os.dup2(fd, 1)
    os.dup2(fd, 2)
    os.close(fd)
    out = head.find(OUTPUT)  # where the command's output starts
    out = out + len(OUTPUT) if out >= 0 else len(head)
    if os.path.getsize(log) <= out:
        with open(log, 'ab') as f:
            f.write(b'(none)\n')
    with open(log, 'r+b') as f:
        f.write(header(command, directory, text, begun, now_text(end), duration).encode('utf-8', 'surrogateescape'))
        # Its last 20 lines, as tail -n 20 and $(...) give them: trailing empty lines dropped after the cut.
        tail = last_lines(f, 20, out).rstrip(b'\n').split(b'\n')
    if not report(name, command, directory, text, result, begun, now_text(end), duration, tail, log, to):
        say('command completed, but notification email failed')


def run_background(argv: List[str], name: str, command: str, to: str) -> int:
    """Start the run detached from the terminal, in a log of its own, and return; it emails when it ends."""
    started = start(name, command)
    if started is None:
        return 1
    log, t0 = started
    sys.stdout.flush()
    sys.stderr.flush()
    pid = os.fork()
    if pid:
        print(f'{PROG}: {name} running in the background as pid {pid} (kill {pid} stops it); log: {log}')
        return 0
    try:
        os.setsid()  # a session of its own: the terminal's hang-up and Ctrl+C never reach it
        null = os.open(os.devnull, os.O_RDONLY)
        fd = os.open(log, os.O_WRONLY | os.O_APPEND)
        os.dup2(null, 0)
        os.dup2(fd, 1)
        os.dup2(fd, 2)
        os.close(null)
        os.close(fd)
        got = []  # type: List[str]
        try:
            proc = subprocess.Popen(argv, preexec_fn=os.setpgrp)
        except OSError as e:
            print(f'{PROG}: {argv[0]}: {e.strerror}', flush=True)
            status = 127
        else:
            # kill <pid>, a hang-up or INT ends the command (its process group) too, and the email says which.
            def forward(signum: int, frame: object) -> None:
                got.append(signal.Signals(signum).name[3:])
                try:
                    os.killpg(proc.pid, signum)
                except OSError:
                    pass

            for sig in (signal.SIGHUP, signal.SIGINT, signal.SIGTERM):
                signal.signal(sig, forward)
            status = proc.wait()
            status = 128 - status if status < 0 else status
        finish(name, log, t0, status, got[-1] if got else '', to)
        code = status
    except BaseException:
        traceback.print_exc()  # into the log
        code = 1
    os._exit(code & 0xff)


def run_foreground(argv: List[str], name: str, command: str, to: str) -> int:
    """Run here with the terminal, then email; Ctrl+C stops it without an email."""
    t0, directory = int(time.time()), logical_cwd()
    try:
        status = subprocess.call(argv)
    except OSError as e:
        say(f'{argv[0]}: {e.strerror}')
        status = 127
    status = 128 - status if status < 0 else status
    mail_foreground(name, command, directory, t0, status, '', to)
    return status


def mail_foreground(name: str, command: str, directory: str, t0: int, status: int, signame: str, to: str) -> None:
    end = time.time()
    result, text = outcome(status, signame)
    if not report(name, command, directory, text, result, now_text(t0), now_text(end), duration_text(int(end) - t0),
                  None, None, to):
        say('command completed, but notification email failed')


# --- Following -------------------------------------------------------------------------------------------------------


def logs(name: Optional[str] = None) -> List[str]:
    """The logs of the runs started in this directory (of command name only, when given), newest first by the start
    stamp in their names (a log's modification time moves while its job writes)."""
    directory = by_path()
    try:
        entries = os.listdir(directory)
    except OSError:
        return []
    found = []
    for entry in entries:
        m = LOG_NAME.fullmatch(entry)
        path = os.path.join(directory, entry)
        if m and (name is None or m.group(1) == name) and os.path.isfile(path):
            found.append((f'{m.group(2)}.{(m.group(3) or "0").zfill(4)[-4:]}', path))
    return [path for _, path in sorted(found, reverse=True)]


def list_logs() -> int:
    found = logs()
    if not found:
        say(f'no noti logs from {logical_cwd()}')
        return 1
    for i, log in enumerate(found, 1):
        h = read_header(log) or {'Result': 'Running'}
        print(f"{i:3d}  {h['Result'].split(' ')[0]:<7}  {h.get('Start Time', ''):<23}  "
              f"{h.get('Command') or os.path.basename(log)}")
    return 0


def complete() -> int:
    """For the shared zsh's Tab completion of tn: log<TAB>N:result  start  command, then name<TAB>command name."""
    found = logs()
    for i, log in enumerate(found, 1):
        h = read_header(log) or {'Result': 'Running'}
        print(f"log\t{i}:{h['Result'].split(' ')[0][:7]:<7}  {h.get('Start Time', '')}  {h.get('Command', '')}")
    names = []  # type: List[str]
    for log in found:
        m = LOG_NAME.fullmatch(os.path.basename(log))
        if m and m.group(1) not in names:
            names.append(m.group(1))
    for name in names:
        print(f'name\t{name}')
    return 0


def follow(log: str) -> None:
    """Show the log's last 20 lines and follow it while its job runs, then read it to the end (the raw file, which
    the cleaned copy replaces only by name). Ctrl+C stops only the following."""
    out = sys.stdout.buffer
    try:
        with open(log, 'rb') as f:
            out.write(last_lines(f, 20))
            out.flush()
            checked = 0.0
            while True:
                chunk = f.read(65536)
                if chunk:
                    out.write(chunk)
                    out.flush()
                    continue
                if time.monotonic() - checked >= 1:
                    checked = time.monotonic()
                    if not running(log):
                        out.write(f.read())
                        out.flush()
                        return
                time.sleep(0.2)
    except KeyboardInterrupt:
        out.flush()


def tail(which: str) -> int:
    if re.fullmatch('[0-9]+', which) and int(which) >= 1:
        found = logs()
        log = found[int(which) - 1] if int(which) <= len(found) else ''
    else:
        found = logs(file_name(os.path.basename(which)) if which else None)
        live = [log for log in found if running(log)]
        log = (live or found or [''])[0]
        if len(live) > 1:
            say(f'{len(live)} noti jobs are running here; following the newest ({PROG} -l lists them)')
    if not log:
        quoted = f' "{which}"' if which else ''
        say(f'no noti log{quoted} from {logical_cwd()} ({PROG} -l lists them)')
        return 1
    h = read_header(log)
    what = h.get('Command') or os.path.basename(log)
    if running(log):
        print(f'{PROG}: following {what}; Ctrl+C stops only {PROG}', flush=True)
        follow(log)
    else:
        with open(log, 'rb') as f:
            sys.stdout.buffer.write(last_lines(f, 20))
        sys.stdout.buffer.flush()
    if running(log):
        print(f'{PROG}: {what} is still running; log: {log}')
    else:
        h = read_header(log)
        if h:
            print(f"{PROG}: {h.get('Command', '')}: {h['Result']} in {h.get('Duration', '')}; log: {log}")
    return 0


# --- Main ------------------------------------------------------------------------------------------------------------


def main(argv: List[str]) -> int:
    global PROG
    PROG = os.environ.pop('NOTI_PROG', '') or PROG
    args = list(argv)
    if args[:1] in (['-h'], ['--help']):
        print(usage())
        return 0
    if args[:1] in (['-l'], ['--list']):
        return list_logs()
    if args[:1] in (['-t'], ['--tail']):
        return tail(args[1] if len(args) > 1 else '')
    # The shared .zshrc's noti, which runs the command itself: _start [--foreground] NAME COMMAND prints the new log's
    # path (none with --foreground) and the start time; _end NAME LOG|- START STATUS SIGNAL [COMMAND DIRECTORY]
    # finishes the log and emails (- for a foreground run, which has no log). _complete serves tn's Tab completion.
    if args[:1] == ['_start'] and len(args) in (3, 4):
        foreground = args[1] == '--foreground'
        if len(args) != 3 + foreground or work_email() is None:
            return 2
        if foreground:
            print(int(time.time()))
            return 0
        started = start(args[1], args[2])
        if started is None:
            return 1
        print(f'{started[0]}\n{started[1]}')
        return 0
    if args[:1] == ['_end'] and len(args) in (6, 8):
        to = work_email()
        if to is None:
            return 2
        name, log, t0, status, signame = args[1], args[2], int(args[3]), int(args[4]), args[5]
        if log == '-' and len(args) == 8:
            mail_foreground(name, args[6], args[7], t0, status, signame, to)
        else:
            finish(name, log, t0, status, signame, to)
        return status
    if args == ['_complete']:
        return complete()
    foreground = args[:1] in (['-f'], ['--foreground'])
    if foreground:
        args = args[1:]
    if not args:
        print(usage(), file=sys.stderr)
        return 2
    if args[0] in ('-c', '--'):
        if len(args) != 2:
            print(usage(), file=sys.stderr)
            return 2
        command = args[1]
        try:
            first = (re.split(r'\s+', command.strip()) or [''])[0]
        except ValueError:
            first = ''
        name = os.path.basename(first) or 'shell'
        run = [os.environ.get('SHELL') or '/bin/sh', '-c', command]
    else:
        command = ' '.join(shell_quote(arg) for arg in args)
        name, run = os.path.basename(args[0]), args
    to = work_email()
    if to is None:
        return 2
    return run_foreground(run, name, command, to) if foreground else run_background(run, name, command, to)


def shell_quote(arg: str) -> str:
    """arg quoted for a shell, backslash style, as zsh's (q) quotes it."""
    if arg == '':
        return "''"
    return re.sub(r'([^\w@%+=:,./-])', r'\\\1', arg, flags=re.ASCII)


if __name__ == '__main__':
    try:
        sys.exit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        sys.exit(130)
    except BrokenPipeError:
        os.dup2(os.open(os.devnull, os.O_WRONLY), 1)
        sys.exit(141)


