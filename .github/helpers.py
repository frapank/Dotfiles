#!/usr/bin/env python3
"""Check helper arguments and desktop routing without touching the session."""

import contextlib
import io
import os
from pathlib import Path
import pty
import re
import select
import runpy
import shlex
import subprocess
import tempfile
import time
import unittest
from unittest import mock


REPO = Path(__file__).resolve().parents[1]
LIB = REPO / 'root/helpers/usr/local/lib/dotfiles/cli.sh'


class Helpers(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dotfiles-helpers-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.log = self.root / 'calls'
        self.env = dict(os.environ, HOME=str(self.root),
                        XDG_RUNTIME_DIR=str(self.root), XDG_STATE_HOME=str(self.root / 'state'),
                        PATH=f'{self.bin}:/usr/bin:/bin', NO_COLOR='1')
        for folder in ('home/bin/.local/bin', 'home/services/.local/bin',
                       'home/tmux/.local/bin', 'root/logs/usr/local/bin',
                       'root/usb/usr/local/bin'):
            for source in (REPO / folder).iterdir():
                if source.is_file():
                    dest = self.bin / source.name
                    dest.write_text(source.read_text().replace(
                        '/usr/local/lib/dotfiles/cli.sh', str(LIB))
                        .replace('/run/usb-pending', str(self.root / 'usb-pending'))
                        .replace('/var/lib/maint-status', str(self.root / 'maint-status')))
                    dest.chmod(0o700)

    def mock(self, name, body='exit 0'):
        path = self.bin / name
        path.write_text(f'#!/bin/sh\nprintf "%s\\n" "{name} $*" >>"{self.log}"\n{body}\n')
        path.chmod(0o700)

    def run_helper(self, *args, code=0, **env):
        result = subprocess.run([str(self.bin / args[0]), *args[1:]],
                                env=dict(self.env, **env), text=True,
                                capture_output=True, timeout=10)
        self.assertEqual(result.returncode, code, (args, result.stdout, result.stderr))
        return result

    def calls(self):
        return self.log.read_text() if self.log.exists() else ''

    def test_help(self):
        for path in sorted(self.bin.iterdir()):
            if path.name in ('audio', 'browser', 'files', 'office', 'pdf', 'photo', 'video'):
                continue
            with self.subTest(name=path.name):
                result = self.run_helper(path.name, '--help')
                self.assertIn('Usage:', result.stdout)
                self.assertNotIn('\033', result.stdout)
                self.assertEqual(result.stderr, '')

    def test_status_has_no_notifications(self):
        self.mock('notify-send', 'exit 99')
        self.mock('nmcli', 'echo "${RADIO:-enabled}"')
        self.mock('bluetoothctl', 'echo "Powered: ${POWERED:-yes}"')
        self.mock('services', 'exit "${SERVICE_STATUS:-0}"')
        self.mock('pgrep', 'exit "${RECORDING:-1}"')
        for name in ('wifi', 'bluetooth', 'awake', 'nightlight', 'record'):
            with self.subTest(name=name):
                self.assertIn(self.run_helper(name, 'status').stdout.splitlines()[0], ('on', 'off'))
        self.assertEqual(self.run_helper('wifi', 'status', RADIO='disabled').stdout, 'off\n')
        self.assertEqual(self.run_helper('bluetooth', 'status', POWERED='no').stdout, 'off\n')
        self.assertEqual(self.run_helper('nightlight', 'status', SERVICE_STATUS='3').stdout,
                         'off\ntemperature=4000\n')
        self.assertEqual(self.run_helper('record', 'status', RECORDING='0').stdout, 'on\n')
        (self.root / 'awake').touch()
        self.assertEqual(self.run_helper('awake', 'status').stdout, 'on\nuntil=never\n')
        self.assertNotIn('notify-send', self.calls())

    def test_status_errors(self):
        self.mock('nmcli', 'exit 1')
        self.mock('bluetoothctl', 'exit 1')
        self.mock('services', 'exit 1')
        for name in ('wifi', 'bluetooth', 'nightlight'):
            self.run_helper(name, 'status', code=1)

    def test_invalid_actions_have_no_effect(self):
        self.mock('pgrep', 'exit 0')
        for name in ('pkill', 'nmcli', 'bluetoothctl', 'nm-connection-editor',
                     'blueman-manager', 'services', 'notify-send', 'wpctl', 'flock'):
            self.mock(name, 'exit 99')
        for name in ('record', 'wifi', 'bluetooth', 'awake', 'nightlight', 'desktop'):
            self.run_helper(name, 'invalid-action', code=2)
            self.run_helper(name, 'status', 'extra', code=2)
        self.run_helper('desktop', 'volume', 'up', 'extra', code=2)
        self.run_helper('desktop', 'volume', 'invalid', code=2)
        self.run_helper('record', '--invalid-option', code=2)
        self.run_helper('failed-logins', '--notify', 'extra', code=2)
        self.assertEqual(self.calls(), '')
        self.run_helper('isolate', '--invalid-option', code=125)

    def test_failed_radio_query_has_no_action(self):
        self.mock('nmcli', 'exit 1')
        self.mock('bluetoothctl', 'exit 1')
        self.mock('notify-send')
        for name in ('wifi', 'bluetooth'):
            for action in ('toggle', 'info'):
                self.run_helper(name, action, code=1)
        self.assertNotIn('power', self.calls())
        self.assertNotIn('wifi on', self.calls())
        self.assertNotIn('wifi off', self.calls())
        self.assertNotIn('notify-send', self.calls())

    def test_metadata_arguments(self):
        for args in ((), ('unknown',), ('clean',), ('show',)):
            self.run_helper('metadata', *args, code=2)

    def test_settings(self):
        for name, manager in [('wifi', 'nm-connection-editor'), ('bluetooth', 'blueman-manager')]:
            self.mock(manager)
            self.run_helper(name)
            self.run_helper(name, 'settings')
            self.assertEqual(self.calls().count(manager), 2)

    def test_desktop_routes(self):
        self.mock('flock')
        self.mock('pkill')
        self.mock('wpctl', 'case $1 in get-volume) echo "Volume: 0.50" ;; esac')
        self.mock('notify-send')
        self.mock('pactl')
        self.mock('foot')
        self.run_helper('desktop', 'volume', 'up')
        self.run_helper('osd', 'volume', 'down')
        self.run_helper('desktop', 'mic', 'info')
        self.run_helper('indicator', 'mic')
        self.run_helper('desktop', 'dns', 'logs')
        self.assertIn('wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+', self.calls())
        self.assertIn('wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-', self.calls())
        self.assertEqual(self.calls().count('Not in use'), 2)
        self.assertIn('foot logs -p service dnscrypt-proxy boot', self.calls())

    def test_metadata_compatibility(self):
        self.mock('metadata', 'printf "<%s>\\n" "$@"')
        result = self.run_helper('metadata-remover', '-c', 'a file.jpg')
        self.assertEqual(result.stdout, '<clean>\n<-c>\n<a file.jpg>\n')
        result = self.run_helper('metadata-remover', 'show', '-name.jpg')
        self.assertEqual(result.stdout, '<show>\n<-name.jpg>\n')

    def test_open_failure_status(self):
        self.run_helper('open', '--dry-run', str(self.root / 'missing'), code=1)
        self.run_helper('open', '--invalid-option', code=2)

    def wait_for_call(self, text):
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            if text in self.calls():
                return
            time.sleep(0.02)
        self.fail(f'missing call: {text}\n{self.calls()}')

    def test_desktop_status_is_read_only(self):
        self.mock('notify-send', 'exit 99')
        self.mock('pkill', 'exit 99')
        self.mock('wpctl', 'echo "Volume: 0.50"')
        self.mock('pactl')
        self.mock('fuser', 'exit 1')
        self.mock('systemctl', 'echo inactive; exit 3')
        self.mock('usb', 'echo "No devices"')
        self.assertEqual(self.run_helper('desktop', 'volume', 'status').stdout, 'on\nvolume=50\n')
        self.assertEqual(self.run_helper('desktop', 'mic', 'status').stdout,
                         'on\nvolume=50\nin_use=none\n')
        self.assertEqual(self.run_helper('desktop', 'cam', 'status').stdout, 'off\n')
        self.assertEqual(self.run_helper('desktop', 'dns', 'status').stdout, 'inactive\n')
        self.assertIn('No devices', self.run_helper('desktop', 'usb', 'status').stdout)
        self.assertIn('running=', self.run_helper('desktop', 'reboot', 'status').stdout)
        self.assertNotIn('notify-send', self.calls())
        self.assertNotIn('pkill', self.calls())

    def test_desktop_mute_actions(self):
        self.mock('wpctl', 'case $1 in get-volume) echo "Volume: 0.50" ;; esac')
        for name in ('notify-send', 'pkill', 'flock', 'audio'):
            self.mock(name)
        for topic, target in [('volume', '@DEFAULT_AUDIO_SINK@'),
                              ('mic', '@DEFAULT_AUDIO_SOURCE@')]:
            for action, value in [('on', '0'), ('off', '1'), ('toggle', 'toggle')]:
                self.run_helper('desktop', topic, action)
                self.assertIn(f'wpctl set-mute {target} {value}', self.calls())
            self.run_helper('desktop', topic, 'settings')
        self.assertIn('audio -t 2', self.calls())

    def test_logs_aliases_and_timer_info(self):
        self.mock('services')
        self.run_helper('awake', 'logs')
        self.run_helper('nightlight', 'logs')
        self.assertIn('services logs idle', self.calls())
        self.assertIn('services logs nightlight', self.calls())
        self.mock('notify-send')
        self.mock('pgrep', 'exit 1')
        self.assertEqual(self.run_helper('timer', 'status').stdout,
                         self.run_helper('timer', 'list').stdout)
        self.run_helper('timer', 'info')
        self.assertIn('Middle click: cancel all', self.calls())
        self.run_helper('timer', 'info', 'extra', code=2)

    def test_record_on_does_not_stop(self):
        self.mock('pgrep', 'exit 0')
        self.mock('pkill', 'exit 99')
        self.run_helper('record', 'on')
        self.run_helper('record', 'on', 'region', '--no-audio')
        self.assertNotIn('pkill', self.calls())
        self.run_helper('record', 'on', 'invalid', code=2)

    def test_file_notification_actions(self):
        folder = self.root / 'a folder'
        folder.mkdir()
        file = folder / "a 'quoted' file.png"
        file.write_bytes(b'image')
        self.mock('notify-send', 'printf "%s" "${CHOICE:-}"')
        for name in ('open', 'files', 'swappy', 'wl-copy'):
            self.mock(name)
        for action, expected in [('default', f'open -- {file}'),
                                 ('folder', f'files {folder}'),
                                 ('edit', f'swappy -f {file} -o {file}')]:
            result = subprocess.run(['sh', '-c', '. "$1"; notify_file App Saved "$2" edit',
                                     'sh', str(LIB), str(file)],
                                    env=dict(self.env, CHOICE=action), capture_output=True,
                                    text=True, timeout=5)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(expected, self.calls())
        self.assertIn('folder=Show in folder', self.calls())

    def test_screenshot_folder_action(self):
        folder = self.root / 'shots'
        self.mock('xdg-user-dir', 'echo "$HOME/shots"')
        self.mock('slurp', 'echo "0,0 10x10"')
        self.mock('grim', 'for file; do :; done; printf image >"$file"')
        self.mock('wl-copy')
        self.mock('notify-send', 'echo folder')
        self.mock('files')
        self.run_helper('screenshot')
        self.wait_for_call(f'files {folder}')
        self.assertEqual(len(list(folder.glob('*.png'))), 1)

    def test_dns_notification_actions(self):
        self.mock('logs', 'echo "Resolver failed"')
        self.mock('notify-send', 'printf "%s" "${CHOICE:-}"')
        self.mock('foot')
        self.run_helper('desktop', 'dns', 'info', CHOICE='logs')
        self.assertIn('foot logs -p service dnscrypt-proxy boot', self.calls())
        self.run_helper('desktop', 'dns', 'info', CHOICE='restart')
        self.assertIn('foot -H doas systemctl restart dnscrypt-proxy.service', self.calls())
        self.assertIn('restart=Restart', self.calls())

    def test_snap_restore_print_path(self):
        namespace = runpy.run_path(str(REPO / 'root/maint/usr/local/bin/snap'))
        restore = namespace['restore']
        source = self.root / 'source.txt'
        source.write_text('old version')
        dest = self.root / 'restored file.txt'
        fd = os.open(self.root, os.O_RDONLY | os.O_DIRECTORY)
        self.addCleanup(os.close, fd)
        with mock.patch.dict(restore.__globals__, {
                'pick': lambda *_: ('2026-11-20_1200', self.root),
                'rel_path': lambda path: (str(path), 'source.txt'),
                'lookup': lambda *_: (fd, 'source.txt')}):
            out, err = io.StringIO(), io.StringIO()
            with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
                restore([], 'today', str(source), str(dest), True)
            self.assertEqual(out.getvalue(), f'{dest}\n')
            self.assertIn('Copied', err.getvalue())
            self.assertEqual(dest.read_text(), 'old version')
            with self.assertRaises(SystemExit), contextlib.redirect_stderr(io.StringIO()):
                restore([], 'today', str(source), str(dest), True)
            self.assertEqual(dest.read_text(), 'old version')

    def test_snapshot_ui_notification(self):
        dest = self.root / 'restored file.txt'
        dest.write_text('restored')
        self.mock('snap', f'case $1 in restore) printf "%s\\n" {shlex.quote(str(dest))} ;; '
                  '*) printf "SNAPSHOT SIZE\\nnow current\\n2026-11-20_1200 old\\n" ;; esac')
        self.mock('fzf', 'printf "2026-11-20_1200 old\\n"')
        self.mock('notify-send', 'echo folder')
        self.mock('files')
        src = (REPO / 'root/maint/usr/local/libexec/snap-ui').read_text()
        path = self.bin / 'snap-ui'
        path.write_text(src.replace('/usr/local/lib/dotfiles/cli.sh', str(LIB))
                        .replace('SNAP=/usr/local/bin/snap', f'SNAP={self.bin / "snap"}'))
        path.chmod(0o700)
        result = subprocess.run([str(path), 'restore', str(dest)], env=self.env,
                                input='\n', text=True, capture_output=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.wait_for_call(f'files {self.root}')
        self.assertIn('snap restore --print-path 2026-11-20_1200 --', self.calls())

    def test_record_completion_folder_action(self):
        self.mock('pgrep', 'exit 1')
        self.mock('slurp', 'echo "0,0 10x10"')
        self.mock('setsid')
        self.mock('xdg-user-dir', 'echo "$HOME/videos"')
        self.mock('wf-recorder', 'while [ "$1" != -f ]; do shift; done; printf video >"$2"')
        self.mock('notify-send', 'case "$*" in *"Recording saved"*) echo folder ;; esac')
        self.mock('files')
        self.run_helper('record', 'on', 'region', '--no-audio')
        self.wait_for_call(f'files {self.root / "videos"}')
        self.assertEqual(self.calls().count('Recording saved'), 1)
        self.assertEqual(len(list((self.root / 'videos').glob('*.mp4'))), 1)

    def test_metadata_completion_actions(self):
        source = self.root / "my 'photo'.png"
        source.write_bytes(b'photo')
        self.mock('file', 'echo image/png')
        self.mock('exiftool', 'cp in.png out.png')
        for name in ('ffmpeg', 'ffprobe', 'mat2'):
            self.mock(name)
        self.mock('bwrap', 'while [ "$1" != -- ]; do shift; done; shift; exec "$@"')
        self.mock('notify-send', 'echo default')
        self.mock('open')
        self.run_helper('metadata', 'clean', '-c', '--notify', str(source))
        dest = source.with_name("my 'photo'.clean.png")
        self.wait_for_call(f'open -- {dest}')
        self.assertEqual(source.read_bytes(), b'photo')
        self.assertEqual(dest.read_bytes(), b'photo')

    def test_metadata_failure_has_no_result_actions(self):
        source = self.root / 'photo.png'
        source.write_bytes(b'photo')
        self.mock('file', 'echo image/png')
        self.mock('exiftool', 'exit 1')
        for name in ('ffmpeg', 'ffprobe', 'mat2'):
            self.mock(name)
        self.mock('bwrap', 'while [ "$1" != -- ]; do shift; done; shift; exec "$@"')
        self.mock('notify-send')
        self.run_helper('metadata', 'clean', '--notify', str(source), code=1)
        self.wait_for_call('Metadata removal failed')
        self.assertNotIn('folder=Show', self.calls())
        self.assertEqual(source.read_bytes(), b'photo')

    def test_usb_notification_keeps_selected_port(self):
        pending = self.root / 'usb-pending'
        pending.write_text('1 1-2 First device\n')
        self.mock('notify-send', f'printf "2 3-4 Second device\\n" >{shlex.quote(str(pending))}; echo allow')
        self.mock('foot')
        self.run_helper('desktop', 'usb', 'info')
        self.assertIn('foot -H usb allow 1-2', self.calls())
        self.assertNotIn('foot -H usb allow 3-4', self.calls())

    def test_maintenance_notification_actions(self):
        source = (REPO / 'root/maint/usr/local/sbin/maint').read_text()
        function = re.search(r'^notify_job\(\) \{.*?^\}', source, re.M | re.S)[0]
        self.mock('notify-send', 'printf "%s" "${CHOICE:-}"')
        self.mock('foot')
        for action, expected in [('retry', 'foot --hold -- doas /usr/local/sbin/maint retry update'),
                                 ('default', 'foot -- /usr/local/bin/logs -p service maint')]:
            result = subprocess.run(['sh', '-c', 'as_user() { "$@"; }\n' + function +
                                     '\nnotify_job update; wait'], env=dict(self.env, CHOICE=action),
                                    text=True, capture_output=True, timeout=5)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(expected, self.calls())
        self.assertIn('retry=Retry', self.calls())

    def test_services_logs_keeps_old_alias(self):
        unit = self.root / '.config/systemd/user/idle.service'
        unit.parent.mkdir(parents=True)
        unit.write_text('[Install]\nWantedBy=g0wm-session.target\n')
        self.mock('logs')
        self.run_helper('services', 'logs', 'idle')
        self.run_helper('services', 'log', 'idle')
        self.assertEqual(self.calls().count('logs -n service idle'), 2)

    def test_record_off_does_not_start(self):
        self.mock('pgrep', 'exit 1')
        self.mock('wf-recorder', 'exit 99')
        self.run_helper('record', 'off')
        self.run_helper('record', 'stop')
        self.assertNotIn('\nwf-recorder ', '\n' + self.calls())

    def test_maintenance_info_actions(self):
        (self.root / 'maint-status').write_text('failed=update scrub\n')
        self.mock('notify-send', 'printf "%s" "${CHOICE:-}"')
        self.mock('foot')
        self.run_helper('desktop', 'maint', 'info', CHOICE='logs')
        self.assertIn('foot logs -p service maint', self.calls())
        self.run_helper('desktop', 'maint', 'info', CHOICE='retry')
        self.assertIn('foot -H doas /usr/local/sbin/maint retry', self.calls())
        self.assertIn('retry=Retry', self.calls())

    def test_no_color_on_terminal(self):
        master, slave = pty.openpty()
        try:
            result = subprocess.Popen([str(self.bin / 'timer'), '--help'], env=self.env,
                                      stdout=slave, stderr=subprocess.PIPE)
            os.close(slave)
            output = b''
            while select.select([master], [], [], 5)[0]:
                try:
                    chunk = os.read(master, 4096)
                except OSError:
                    break
                if not chunk:
                    break
                output += chunk
            self.assertEqual(result.wait(timeout=5), 0)
            self.assertNotIn(b'\033', output)
            self.assertIn(b'Usage:', output)
            result.stderr.close()
        finally:
            os.close(master)


if __name__ == '__main__':
    unittest.main()
