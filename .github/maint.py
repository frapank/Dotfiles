#!/usr/bin/env python3
"""Check maintenance state, scheduling and locking with disposable jobs."""

import fcntl
import os
from pathlib import Path
import select
import shlex
import subprocess
import tempfile
import time
import unittest


REPO = Path(__file__).resolve().parents[1]
SOURCE = REPO / 'root/maint/usr/local/sbin/maint'
RUNTIME = REPO / 'root/maint/usr/local/lib/maint.sh'
CLI = REPO / 'root/helpers/usr/local/lib/dotfiles/cli.sh'
JOBS = 'home thumbs trash update disks kernels packages firmware integrity cves vesktop scrub blocklist'.split()


class Maintenance(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dotfiles-maint-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.state = self.root / 'state'
        self.public = self.root / 'public'
        self.script = self.root / 'maint'
        self.extra = ''
        self.env = dict(os.environ, NO_COLOR='1')

    def build(self):
        source = SOURCE.read_text().rsplit('\nmain "$@"', 1)[0]
        source = source.replace('/usr/local/lib/dotfiles/cli.sh', str(CLI))
        source = source.replace('/usr/local/lib/maint.sh', str(RUNTIME))
        source = source.replace('/usr/local/sbin/maint', str(self.script))
        source += f'\nSTATE={shlex.quote(str(self.state))}\nPUBLIC={shlex.quote(str(self.public))}\n'
        source += '''
id() { printf '0\n'; }
snapshots() { :; }
grub_quiet() { return 0; }
notify_job() { printf '%s\n' "$1" >>"$STATE/notified"; }
ready() { return 0; }
'''
        for name in JOBS:
            source += f'job_{name}() {{ printf "{name} output\\n"; return "${{JOB_{name}_RC:-0}}"; }}\n'
        source += self.extra + '\nmain "$@"\n'
        self.script.write_text(source)
        self.script.chmod(0o700)

    def run_maint(self, *args, code=0, **env):
        self.build()
        result = subprocess.run([str(self.script), *args], env=dict(self.env, **env),
                                capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, code, (args, result.stdout[-2000:], result.stderr))
        return result

    def record(self, name):
        return dict(line.split('=', 1) for line in
                    (self.state / 'jobs' / name / 'state').read_text().splitlines())

    def seed(self, name, state='ok', **values):
        path = self.state / 'jobs' / name / 'state'
        path.parent.mkdir(parents=True, exist_ok=True)
        data = dict(state=state, attempt='100', success='90', finished='101',
                    duration='1', pid='0', start='0', boot='', reason='previous result')
        data.update({key: str(value) for key, value in values.items()})
        path.write_text(''.join(f'{key}={value}\n' for key, value in data.items()))

    def test_attempt_and_success_are_separate(self):
        success = int(time.time()) - 90000
        self.seed('home', success=success)
        self.run_maint('home', code=1, JOB_home_RC='1')
        state = self.record('home')
        self.assertEqual(state['state'], 'failed')
        self.assertEqual(int(state['success']), success)
        self.assertGreater(int(state['attempt']), success)
        self.assertGreaterEqual(int(state['finished']), int(state['attempt']))
        self.assertIn(f'job_home_success={success}', self.public.read_text())
        self.run_maint('home')
        state = self.record('home')
        self.assertEqual(state['state'], 'ok')
        self.assertGreater(int(state['success']), success)
        self.assertFalse((self.state / 'home.failed').exists())

    def test_postponement_keeps_last_success(self):
        self.seed('home', success=50)
        self.extra = 'job_home() { postpone "Low free space"; return 2; }'
        self.run_maint('home')
        state = self.record('home')
        self.assertEqual(state['state'], 'postponed')
        self.assertEqual(state['success'], '50')
        self.assertEqual(state['reason'], 'Low free space')
        self.assertIn('postponed=home', self.public.read_text())
        self.assertNotIn('failed=home', self.public.read_text())

    def test_notified_failure_still_returns_failure(self):
        self.run_maint('update', code=1, JOB_update_RC='3')
        self.assertEqual(self.record('update')['state'], 'failed')
        self.assertFalse((self.state / 'notified').exists())

    def test_run_continues_after_failure(self):
        self.extra = "JOBS='home thumbs'"
        self.run_maint('run', code=1, JOB_home_RC='1')
        self.assertEqual(self.record('home')['state'], 'failed')
        self.assertEqual(self.record('thumbs')['state'], 'ok')

    def test_postponement_is_not_a_failed_run(self):
        self.extra = "JOBS='home thumbs'\njob_home() { postpone 'On battery'; return 2; }"
        self.run_maint('run')
        self.assertEqual(self.record('home')['state'], 'postponed')
        self.assertEqual(self.record('thumbs')['state'], 'ok')

    def test_running_state_is_visible(self):
        self.extra = 'job_home() { sleep 2; echo completed; }'
        self.build()
        proc = subprocess.Popen([str(self.script), 'home'], env=self.env,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            path = self.state / 'jobs/home/state'
            deadline = time.monotonic() + 3
            while not path.exists() and time.monotonic() < deadline:
                time.sleep(0.02)
            self.assertTrue(path.exists())
            result = subprocess.run([str(self.script), 'status', 'home'], env=self.env,
                                    capture_output=True, text=True, timeout=5)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('running', result.stdout)
            self.assertEqual(self.record('home')['state'], 'running')
            self.assertEqual(proc.wait(timeout=6), 0)
            self.assertEqual(self.record('home')['state'], 'ok')
        finally:
            proc.communicate(timeout=6)

    def test_interrupted_run_can_be_retried(self):
        self.seed('home', 'running', pid=99999999, boot='previous-boot')
        result = self.run_maint('status', 'home')
        self.assertIn('interrupted', result.stdout)
        self.run_maint('retry')
        self.assertEqual(self.record('home')['state'], 'ok')

    def test_retry_waits_for_lock(self):
        self.seed('home', 'failed')
        lock = (self.state / 'lock').open('w')
        self.addCleanup(lock.close)
        fcntl.flock(lock, fcntl.LOCK_EX)
        self.build()
        proc = subprocess.Popen([str(self.script), 'retry', 'home'], env=self.env,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            self.assertTrue(select.select([proc.stdout], [], [], 3)[0])
            self.assertIn('Retry queued', proc.stdout.readline())
            self.assertIsNone(proc.poll())
            self.assertEqual(self.record('home')['state'], 'failed')
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)
            out, err = proc.communicate(timeout=6)
        self.assertEqual(proc.returncode, 0, (out, err))
        self.assertEqual(self.record('home')['state'], 'ok')

    def test_retry_rechecks_failures_after_waiting(self):
        self.seed('home', 'failed')
        with (self.state / 'lock').open('w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            self.build()
            proc = subprocess.Popen([str(self.script), 'retry'], env=self.env,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            try:
                self.assertTrue(select.select([proc.stdout], [], [], 3)[0])
                self.assertIn('Retry queued', proc.stdout.readline())
                self.seed('home', 'ok', success=int(time.time()))
            finally:
                fcntl.flock(lock, fcntl.LOCK_UN)
                out, err = proc.communicate(timeout=6)
        self.assertEqual(proc.returncode, 0, err)
        self.assertIn('No failed jobs', out)
        self.assertEqual(self.record('home')['attempt'], '100')

    def test_plan_is_read_only(self):
        runtime = RUNTIME.read_text().replace('ready() {', 'real_ready() {', 1)
        renamed = self.root / 'runtime'
        renamed.write_text(runtime)
        self.extra = f'. {shlex.quote(str(renamed))}\n' + '''
ready() { real_ready "$@"; }
pgrep() { return 0; }
apt_busy() { return 1; }
battery() { echo 18; }
'''
        result = self.run_maint('plan', 'update')
        self.assertIn('postpone', result.stdout)
        self.assertIn('Battery at 18%', result.stdout)
        self.assertFalse(self.state.exists())
        self.assertFalse(self.public.exists())

    def test_plan_reports_next_due(self):
        self.seed('home', success=int(time.time()))
        before = (self.state / 'jobs/home/state').read_bytes()
        result = self.run_maint('plan', 'home')
        self.assertIn('wait', result.stdout)
        self.assertIn('Next due:', result.stdout)
        self.assertEqual((self.state / 'jobs/home/state').read_bytes(), before)
        self.assertFalse(self.public.exists())

    def test_status_is_read_only_and_has_no_scrub_dependency(self):
        result = self.run_maint('status', 'home')
        self.assertIn('LAST SUCCESS', result.stdout)
        self.assertIn('Last attempt: never', result.stdout)
        self.assertIn('Duration:', result.stdout)
        self.assertFalse(self.state.exists())

    def test_legacy_files_are_preserved(self):
        self.state.mkdir()
        data = self.state / 'integrity'
        data.write_text('/usr/bin/changed-file\n')
        self.run_maint('integrity')
        self.assertEqual(data.read_text(), '/usr/bin/changed-file\n')
        self.assertEqual(self.record('integrity')['state'], 'ok')

    def test_failed_legacy_timestamp_is_not_a_success(self):
        self.state.mkdir()
        (self.state / 'update').touch()
        (self.state / 'update.failed').touch()
        result = self.run_maint('status', 'update')
        self.assertIn('unknown', result.stdout)
        self.assertIn('never', result.stdout)

    def test_logs_and_permissions(self):
        self.run_maint('home')
        result = self.run_maint('logs', 'home')
        self.assertEqual(result.stdout, 'home output\n')
        self.assertEqual((self.state / 'jobs/home/state').stat().st_mode & 0o777, 0o600)
        self.assertEqual((self.state / 'jobs/home/log').stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.public.stat().st_mode & 0o777, 0o644)

    def test_logs_are_bounded(self):
        self.extra = 'job_home() { head -c 300000 /dev/zero | tr "\\000" x; }'
        self.run_maint('home')
        self.assertEqual((self.state / 'jobs/home/log').stat().st_size, 262144)
        self.assertLessEqual(len(self.record('home')['reason']), 240)

    def test_scheduler_retries_failure_after_one_hour(self):
        now = int(time.time())
        self.seed('disks', 'failed', attempt=now, finished=now)
        result = self.run_maint('plan', 'disks')
        self.assertIn('wait', result.stdout)
        self.seed('disks', 'failed', attempt=now-3700, finished=now-3700)
        result = self.run_maint('plan', 'disks')
        self.assertIn('run', result.stdout)

    def test_signal_exit_is_interrupted(self):
        self.seed('home', success=90)
        self.extra = "job_home() { sh -c 'kill -TERM $$'; }"
        self.run_maint('home', code=1)
        state = self.record('home')
        self.assertEqual(state['state'], 'interrupted')
        self.assertEqual(state['success'], '90')
        self.assertIn('interrupted', self.run_maint('status', 'home').stdout)

    def test_retry_multiple_jobs_aggregates_failures(self):
        self.run_maint('retry', 'home', 'thumbs', code=1, JOB_home_RC='1')
        self.assertEqual(self.record('home')['state'], 'failed')
        self.assertEqual(self.record('thumbs')['state'], 'ok')

    def test_fastfetch_uses_success_and_current_state(self):
        success = int(time.time()) - 3 * 86400
        self.seed('update', success=success)
        self.run_maint('update', code=1, JOB_update_RC='1')
        source = (REPO / 'home/fastfetch/.config/fastfetch/maint.sh').read_text()
        path = self.root / 'fastfetch'
        path.write_text(source.replace('/var/lib/maint-status', str(self.public)))
        result = subprocess.run(['sh', str(path), 'update'], capture_output=True, text=True, check=True)
        self.assertEqual(result.stdout, '3 days ago\n')
        self.public.write_text('failed=\nrunning=update\npostponed=\n')
        result = subprocess.run(['sh', str(path), 'status'], capture_output=True, text=True, check=True)
        self.assertEqual(result.stdout, 'running: update\n')
        self.public.write_text('failed=\nrunning=\npostponed=scrub\n')
        result = subprocess.run(['sh', str(path), 'status'], capture_output=True, text=True, check=True)
        self.assertEqual(result.stdout, 'postponed: scrub\n')

    def test_plan_checks_home_filesystem_without_writes(self):
        runtime = RUNTIME.read_text().replace('ready() {', 'real_ready() {', 1)
        renamed = self.root / 'runtime'
        renamed.write_text(runtime)
        self.extra = f'. {shlex.quote(str(renamed))}\n' + '''
ready() { real_ready "$@"; }
stat() { echo ext4; }
'''
        result = self.run_maint('plan', 'home')
        self.assertIn('blocked', result.stdout)
        self.assertIn('not a Btrfs subvolume', result.stdout)
        self.assertFalse(self.state.exists())

    def test_clock_rollback_does_not_block_scheduling(self):
        future = int(time.time()) + 86400 * 30
        self.seed('home', success=future, finished=future)
        result = self.run_maint('plan', 'home')
        self.assertNotIn('Next due:', result.stdout)
        self.assertIn('run', result.stdout)

    def test_notification_actions_do_not_keep_job_lock(self):
        self.extra = '''
as_user() { sleep 2; }
job_home() { notify_do App Summary Body action=Action true; }
'''
        self.run_maint('home')
        with (self.state / 'lock').open('w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            fcntl.flock(lock, fcntl.LOCK_UN)

    def test_invalid_arguments_have_no_effect(self):
        for args in [('status', 'unknown'), ('logs', '../home'), ('retry', 'unknown'),
                     ('run', 'extra'), ('home', 'extra'), ('plan', 'home', 'extra')]:
            self.run_maint(*args, code=2)
        self.assertFalse(self.state.exists())


if __name__ == '__main__':
    unittest.main()
