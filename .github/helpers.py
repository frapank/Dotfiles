#!/usr/bin/env python3
"""Check helper arguments and desktop routing without touching the session."""

import os
from pathlib import Path
import pty
import select
import subprocess
import tempfile
import unittest


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
                        '/usr/local/lib/dotfiles/cli.sh', str(LIB)))
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
