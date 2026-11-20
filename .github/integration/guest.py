#!/usr/bin/env python3
"""Integration assertions. Only run inside the disposable QEMU guest."""

import hashlib
import json
import os
from pathlib import Path
import pty
import pwd
import select
import shutil
import signal
import stat
import subprocess
import sys
import time

HOME = Path('/home/tester')
REPO = HOME / 'Dotfiles'
ARTIFACTS = Path('/var/tmp/dotfiles-integration')
PROFILE = 'locale cli logs dirs doas'
FAILURE = 'dotfiles integration: injected failure'


def check(condition, message):
    if not condition:
        raise AssertionError(message)


def run(*args):
    return subprocess.check_output(args, text=True).strip()


def guard():
    check(os.geteuid() == 0, 'guest tests need root')
    check(Path('/etc/dotfiles-integration-guest').read_text().strip() ==
          'disposable', 'missing disposable guest marker')
    check(Path('/sys/class/dmi/id/product_name').read_text().strip() ==
          'dotfiles-integration', 'this is not the integration VM')
    ARTIFACTS.mkdir(exist_ok=True)


def entry(path):
    if not path.exists() and not path.is_symlink():
        return None
    st = path.lstat()
    result = [stat.S_IMODE(st.st_mode), st.st_uid, st.st_gid]
    if path.is_symlink():
        result += ['link', os.readlink(path)]
    elif path.is_file():
        result += ['file', hashlib.sha256(path.read_bytes()).hexdigest()]
    else:
        result += ['dir']
    return result


def paths():
    # Include every file/directory installed by this profile, even if absent at
    # baseline, plus legacy configs moved aside and pre-existing user data.
    result = {
        '/etc/default/locale', '/etc/locale.conf', '/etc/locale.gen', '/etc/apt/sources.list',
        '/etc/apt/sources.list.d/debian.sources', '/etc/doas.conf',
        '/etc/apt/preferences.d/90-no-sudo',
        '/etc/polkit-1/rules.d/30-wheel.rules',
        '/etc/sudoers', '/etc/sudoers.d',
        str(HOME / '.bashrc'), str(HOME / '.bash_profile'),
        str(HOME / '.vimrc'), str(HOME / '.tmux.conf'), str(HOME / '.ctags'),
        str(HOME / 'personal-git'), str(HOME / 'Documents'),
        str(HOME / 'Documents/keep.txt'), str(HOME / 'Downloads'),
    }
    for name in ('apt', 'locale', 'logs', 'session', 'watchdog', 'cli', 'helpers'):
        for p in (REPO / 'root' / name).rglob('*'):
            if p.is_file():
                result.add('/' + str(p.relative_to(REPO / 'root' / name)))
    for name in ('bash', 'ctags', 'nvim', 'vim', 'tmux', 'ripgrep', 'fetch',
                 'git', 'lazygit', 'xdg'):
        for p in (REPO / 'home' / name).rglob('*'):
            result.add(str(HOME / p.relative_to(REPO / 'home' / name)))
    for name in ('Desktop', 'Get', 'Random', 'Media', 'Media/Music',
                 'Media/Pictures', 'Media/Videos'):
        result.add(str(HOME / name))
    if Path('/etc/sudoers.d').is_dir():
        result.update(str(p) for p in Path('/etc/sudoers.d').rglob('*'))
    return sorted(result)


def service_state():
    return {key: subprocess.run(['systemctl', key, 'watchdog.service'],
                               capture_output=True, text=True).stdout.strip()
            for key in ('is-enabled', 'is-active')}


def package_state():
    return run('dpkg-query', '-W', '-f=${binary:Package}\t${db:Status-Status}\n')


def snapshot():
    return {
        'files': {p: entry(Path(p)) for p in paths()},
        'service': service_state(),
        'shell': pwd.getpwnam('tester').pw_shell,
        'groups': run('id', '-nG', 'tester').split(),
        'manual': run('apt-mark', 'showmanual').splitlines(),
        'packages': sorted(line.split('\t')[0] for line in package_state().splitlines()
                           if line.endswith('\tinstalled')),
        'sysctl': {key: run('sysctl', '-n', key) for key in (
            'kernel.print-fatal-signals', 'kernel.panic', 'kernel.panic_on_oops',
            'fs.suid_dumpable')},
    }


def write(path, text, mode=0o644, user=False):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    path.chmod(mode)
    if user:
        u = pwd.getpwnam('tester')
        os.chown(path, u.pw_uid, u.pw_gid)


def seed():
    check(run('passwd', '-S', 'root').split()[1] == 'L', 'root must be locked for the sudo regression')
    check(run('passwd', '-S', 'tester').split()[1] == 'P', 'tester needs a usable password')
    check(shutil.which('sudo') is not None, 'baseline must include sudo to exercise its replacement')
    sudoers = Path('/etc/sudoers')
    write(sudoers, sudoers.read_text() + '\n# personal sudoers fixture: keep on rollback\n', 0o440)
    write('/etc/sudoers.d/99-integration', '# personal sudo drop-in\n', 0o440)
    # Both fixtures being replaced and fixtures which must survive unchanged.
    write('/etc/default/locale', 'LANG=C.UTF-8\n')
    write('/etc/apt/apt.conf.d/40-debian-postinstall', '// original config\n', 0o640)
    write('/usr/local/bin/logs', '#!/bin/sh\necho original-logs\n', 0o750)
    write('/etc/systemd/system/watchdog.service',
          '[Unit]\nDescription=Original test watchdog\n[Service]\n'
          'ExecStart=/bin/sleep infinity\n[Install]\nWantedBy=multi-user.target\n')
    subprocess.run(['systemctl', 'daemon-reload'], check=True)
    for name, text in {
        '.bashrc': '# personal bashrc\nexport KEEP_ME=original\n',
        '.bash_profile': '# personal profile\n',
        '.vimrc': '" personal vimrc\n',
        '.tmux.conf': '# personal tmux\n',
        '.ctags': '--languages=C\n',
        'personal-git': '[user]\n    name = Integration Fixture\n',
        'Documents/keep.txt': 'keep this document\n',
    }.items():
        write(HOME / name, text, 0o640, user=True)
    u = pwd.getpwnam('tester')
    for name in ('.config/git', '.local/bin', 'Documents', 'Downloads'):
        p = HOME / name
        p.mkdir(parents=True, exist_ok=True)
    os.symlink('../../personal-git', HOME / '.config/git/config')
    write(HOME / '.local/bin/tmux-project', '#!/bin/sh\necho original\n', 0o750, True)
    for p in HOME.rglob('*'):
        os.lchown(p, u.pw_uid, u.pw_gid)
    subprocess.run(['usermod', '-s', '/bin/sh', 'tester'], check=True)
    (ARTIFACTS / 'baseline.json').write_text(json.dumps(snapshot(), indent=2))


def install(name, fail=False):
    installer = REPO / 'script/install.sh'
    original = installer.read_text()
    if fail:
        # Instrument only the guest's disposable copy, after the last selected
        # step. All real steps, ERR handling and rollback run unchanged.
        needle = '        "${st#*:}"\n'
        check(original.count(needle) == 1, 'installer step loop changed')
        installer.write_text(original.replace(needle, needle +
            '        if [[ ${st#*:} == do_doas ]]; then\n'
            '            run "' + FAILURE + '" /bin/false\n'
            '        fi\n'))
    pid, fd = pty.fork()
    if pid == 0:
        os.environ.update(TERM='dumb', LC_ALL='C')
        os.chdir(REPO)
        os.execv(str(installer), [str(installer), '-u', 'tester'])
    deadline = time.monotonic() + 1800
    pending = b''
    state = 0
    status = None
    try:
        with (ARTIFACTS / f'{name}.console.log').open('wb') as log:
            while time.monotonic() < deadline:
                if select.select([fd], [], [], 1)[0]:
                    try:
                        data = os.read(fd, 65536)
                    except OSError:
                        break
                    if not data:
                        break
                    log.write(data)
                    log.flush()
                    # Stream actual output to the host's scenario log.
                    sys.stdout.buffer.write(data)
                    sys.stdout.flush()
                    pending += data
                    if state < 2 and b'> ' in pending:
                        os.write(fd, (f'n {PROFILE}\n' if state == 0 else '\n').encode())
                        state += 1
                        pending = b''
                    elif state == 2 and b'Proceed?' in pending:
                        os.write(fd, b'y\n')
                        state += 1
                        pending = b''
                    pending = pending[-8192:]
                done, status_value = os.waitpid(pid, os.WNOHANG)
                if done:
                    status = status_value
                    # Drain remaining PTY output before closing.
                    while select.select([fd], [], [], 0)[0]:
                        try:
                            data = os.read(fd, 65536)
                        except OSError:
                            break
                        if not data:
                            break
                        log.write(data)
                    break
            else:
                raise TimeoutError(f'{name}: installer exceeded 30 minutes')
    except BaseException:
        if status is None:
            os.kill(pid, signal.SIGTERM)
        raise
    finally:
        os.close(fd)
        if status is None:
            _, status = os.waitpid(pid, 0)
        if fail:
            installer.write_text(original)
    check(state == 3, f'{name}: installer did not reach confirmation')
    code = os.waitstatus_to_exitcode(status)
    console = (ARTIFACTS / f'{name}.console.log').read_text(errors='replace')
    if fail:
        check(code != 0, 'injected failure returned success')
        check(FAILURE in console and 'Rolling back' in console,
              'failure happened before the injection/rollback')
        check('could not undo:' not in console, 'rollback reported an undo failure')
    else:
        check(code == 0, f'{name}: installer exited {code}')
        check('Done.' in console, f'{name}: missing completion message')
    logs = sorted(Path('/var/log').glob('debian-postinstall-*.log'))
    check(bool(logs), 'missing installer log')
    latest = logs[-1]
    shutil.copy2(latest, ARTIFACTS / f'{name}.installer.log')
    check(f'sections: {PROFILE} ' in latest.read_text(), 'unexpected selected sections')


def assert_installed():
    check(pwd.getpwnam('tester').pw_shell == '/bin/bash', 'login shell not set')
    groups = run('id', '-nG', 'tester').split()
    check('wheel' in groups and 'systemd-journal' in groups, 'groups not applied')
    for name in ('Desktop', 'Get', 'Random', 'Media/Music', 'Media/Pictures', 'Media/Videos'):
        check((HOME / name).is_dir(), f'missing user directory {name}')
    check((HOME / 'Documents/keep.txt').read_text() == 'keep this document\n',
          'existing document lost')
    check(not (HOME / 'Downloads').exists(), 'empty legacy Downloads not moved aside')
    check('export KEEP_ME=original' in (HOME / '.bashrc').read_text(), 'personal bashrc lost')
    check((HOME / '.bashrc').read_text().splitlines()[0] ==
          '[ -f "$HOME/.bashrc_dotfile" ] && . "$HOME/.bashrc_dotfile"', 'missing bash hook')
    u = pwd.getpwnam('tester')
    for name in ('bash', 'ctags', 'nvim', 'vim', 'tmux', 'ripgrep', 'fetch', 'git', 'lazygit', 'xdg'):
        for src in (REPO / 'home' / name).rglob('*'):
            if not src.is_file():
                continue
            dst = HOME / src.relative_to(REPO / 'home' / name)
            expected = src.read_bytes().replace(b'@HOME@', str(HOME).encode())
            check(dst.is_file() and not dst.is_symlink(), f'missing regular file {dst}')
            check(dst.read_bytes() == expected, f'incorrect content {dst}')
            st = dst.stat()
            check(st.st_uid == u.pw_uid and stat.S_IMODE(st.st_mode) ==
                  (0o700 if os.access(src, os.X_OK) else 0o600), f'incorrect permissions {dst}')
    for name in ('apt', 'locale', 'logs', 'session', 'watchdog', 'cli', 'helpers'):
        for src in (REPO / 'root' / name).rglob('*'):
            if not src.is_file():
                continue
            dst = Path('/') / src.relative_to(REPO / 'root' / name)
            check(dst.read_bytes() == src.read_bytes(), f'incorrect system file {dst}')
            mode = 0o755 if str(dst).startswith(('/usr/local/bin/', '/usr/local/libexec/')) else 0o644
            if str(dst).startswith('/etc/sysctl.d/'):
                mode = 0o600
            st = dst.stat()
            check(st.st_uid == 0 and st.st_gid == 0 and stat.S_IMODE(st.st_mode) == mode,
                  f'incorrect system permissions {dst}')
    check(Path('/etc/doas.conf').read_text() == 'permit :wheel\n', 'incorrect doas config')
    check(stat.S_IMODE(Path('/etc/doas.conf').stat().st_mode) == 0o400, 'doas permissions')
    check(stat.S_IMODE(Path('/usr/bin/doas').stat().st_mode) & stat.S_ISUID, 'doas lacks setuid')
    check(not shutil.which('sudo'), 'sudo still installed')
    check('en_US.utf8' in run('locale', '-a'), 'locale not generated')
    locale_config = Path('/etc/locale.conf').read_text()
    check('LANG=en_US.UTF-8' in locale_config and 'LC_COLLATE=C' in locale_config,
          'system locale settings missing')
    check(Path('/etc/default/locale').is_symlink() and
          Path('/etc/default/locale').resolve() == Path('/etc/locale.conf'), 'legacy locale link missing')
    check(service_state() == {'is-enabled': 'enabled', 'is-active': 'active'},
          'watchdog not enabled and active')
    check('Usage: logs' in run('/usr/local/bin/logs', '--help'), 'logs help failed')
    # Actual program startup, with the newly installed configs.
    subprocess.run(['runuser', '-u', 'tester', '--', 'env', f'HOME={HOME}',
                    'nvim', '--headless', '+qa'], check=True, timeout=30, cwd=HOME)
    with (ARTIFACTS / 'vim-startup.log').open('w') as log:
        subprocess.run(['runuser', '-u', 'tester', '--', 'env', f'HOME={HOME}',
                        'vim', '-N', '-es', '-V1', '-u', str(HOME / '.vim/vimrc'), '+qa'],
                       check=True, timeout=30, cwd=HOME, stdout=log, stderr=subprocess.STDOUT)


def first():
    install('first')
    assert_installed()
    (ARTIFACTS / 'installed.json').write_text(json.dumps(snapshot(), indent=2))
    print('\nPASS: first installation', flush=True)


def second():
    before = json.loads((ARTIFACTS / 'installed.json').read_text())
    backups = sorted(str(p) for p in (HOME / '_backup').rglob('*'))
    time.sleep(1)  # installer backup names have second resolution
    install('second')
    assert_installed()
    check(snapshot() == before, 'second installation changed managed state')
    check(sorted(str(p) for p in (HOME / '_backup').rglob('*')) == backups,
          'second installation needlessly backed up user files')
    print('\nPASS: second installation is idempotent', flush=True)


def rollback():
    before = json.loads((ARTIFACTS / 'baseline.json').read_text())
    install('rollback', fail=True)
    after = snapshot()
    (ARTIFACTS / 'after-rollback.json').write_text(json.dumps(after, indent=2))
    differences = {key: {'before': before[key], 'after': after[key]}
                   for key in before if before[key] != after[key]}
    (ARTIFACTS / 'rollback-diff.json').write_text(json.dumps(differences, indent=2))
    check(not differences, f'rollback did not restore: {", ".join(differences)}; see rollback-diff.json')
    print('\nPASS: injected failure restored baseline', flush=True)


if __name__ == '__main__':
    guard()
    actions = {'seed': seed, 'first': first, 'second': second,
               'rollback': rollback, 'check': assert_installed}
    actions[sys.argv[1]]()
