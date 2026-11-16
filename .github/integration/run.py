#!/usr/bin/env python3
"""Run the real installer in disposable Debian QEMU disks, never on the host."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tarfile
import time
import urllib.request

REPO = Path(__file__).resolve().parents[2]
URL = 'https://cloud.debian.org/images/cloud/trixie/latest/'
IMAGE = 'debian-13-genericcloud-amd64.qcow2'


def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def download(directory):
    directory.mkdir(parents=True, exist_ok=True)
    checksums = urllib.request.urlopen(URL + 'SHA512SUMS', timeout=60).read().decode()
    expected = next(line.split()[0] for line in checksums.splitlines()
                    if line.split()[-1] == IMAGE)
    image = directory / IMAGE
    if not image.exists():
        print('Downloading official Debian 13 cloud image', flush=True)
        partial = image.with_suffix('.part')
        with urllib.request.urlopen(URL + IMAGE, timeout=60) as response, partial.open('wb') as out:
            shutil.copyfileobj(response, out)
        partial.rename(image)
    with image.open('rb') as stream:
        if hashlib.file_digest(stream, 'sha512').hexdigest() != expected:
            raise RuntimeError(f'checksum mismatch: {image}')
    return image.resolve()


class VM:
    def __init__(self, disk, directory, key, seed, accel):
        self.directory = directory
        self.disk = disk
        self.key = key
        self.seed = seed
        self.accel = accel
        self.process = None
        with socket.socket() as sock:
            sock.bind(('127.0.0.1', 0))
            self.port = sock.getsockname()[1]

    def ssh(self, command, **kwargs):
        return subprocess.run([
            'ssh', '-F', '/dev/null', '-i', str(self.key), '-p', str(self.port),
            '-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=/dev/null',
            '-o', 'LogLevel=ERROR', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=5',
            '-o', 'ServerAliveInterval=15', '-o', 'ServerAliveCountMax=4',
            'root@127.0.0.1', command,
        ], **kwargs)

    def boot(self):
        self.console = (self.directory / f'{self.disk.stem}.serial.log').open('ab')
        self.process = subprocess.Popen([
            'qemu-system-x86_64', '-machine', f'accel={self.accel}',
            '-cpu', 'max', '-smp', '2', '-m', '2048', '-display', 'none',
            '-serial', 'stdio', '-monitor', 'none', '-no-reboot',
            '-smbios', 'type=1,product=dotfiles-integration',
            '-drive', f'file={self.disk},format=qcow2,if=virtio',
            '-drive', f'file={self.seed},format=raw,media=cdrom,readonly=on',
            '-netdev', f'user,id=net,hostfwd=tcp:127.0.0.1:{self.port}-:22',
            '-device', 'virtio-net-pci,netdev=net,romfile=',
        ], stdout=self.console, stderr=subprocess.STDOUT)
        deadline = time.monotonic() + 600
        while time.monotonic() < deadline:
            if self.process.poll() is not None:
                raise RuntimeError(f'VM exited; see {self.console.name}')
            ready = self.ssh('test -f /var/lib/dotfiles-integration-ready',
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
            if ready.returncode == 0:
                return
            time.sleep(3)
        raise TimeoutError('VM did not become ready within 10 minutes')

    def command(self, command, name):
        log = self.directory / f'{name}.log'
        with log.open('wb') as stream:
            process = self.ssh(command, stdout=stream, stderr=subprocess.STDOUT)
        if process.returncode:
            print(log.read_text(errors='replace')[-12000:], flush=True)
            raise RuntimeError(f'{name} failed, exit {process.returncode}; see {log}')
        print(f'PASS: {name} (log: {log})', flush=True)

    def collect(self, name):
        with (self.directory / f'{name}.tar.gz').open('wb') as stream:
            self.ssh('tar -czf - /var/tmp/dotfiles-integration '
                     '/var/log/debian-postinstall-*.log /var/backups/debian-postinstall '
                     '2>/dev/null', stdout=stream, stderr=subprocess.DEVNULL)

    def stop(self):
        if self.process and self.process.poll() is None:
            self.ssh('systemctl poweroff', stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, timeout=15)
            try:
                self.process.wait(timeout=60)
            except subprocess.TimeoutExpired:
                self.process.terminate()
                self.process.wait(timeout=15)
        if hasattr(self, 'console'):
            self.console.close()


def overlay(image, destination):
    run('qemu-img', 'create', '-q', '-f', 'qcow2', '-F', 'qcow2', '-b',
        str(image), str(destination))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--image', type=Path, help='existing official Debian 13 amd64 cloud image')
    parser.add_argument('--cache', type=Path, default=Path('/tmp/dotfiles-integration-cache'))
    parser.add_argument('--output', type=Path, required=True, help='new directory for disks and logs')
    parser.add_argument('--accel', choices=['tcg', 'kvm'], default='tcg')
    args = parser.parse_args()
    for tool in ('qemu-system-x86_64', 'qemu-img', 'genisoimage', 'ssh', 'ssh-keygen', 'git'):
        if not shutil.which(tool):
            parser.error(f'missing tool: {tool}')
    directory = args.output.resolve()
    directory.mkdir(parents=True, exist_ok=False)
    image = args.image.resolve() if args.image else download(args.cache)
    key = directory / 'id_ed25519'
    run('ssh-keygen', '-q', '-t', 'ed25519', '-N', '', '-f', str(key))
    cloud = {
        'hostname': 'dotfiles-integration', 'disable_root': False, 'ssh_pwauth': False,
        'users': [{'name': 'root', 'ssh_authorized_keys': [key.with_suffix('.pub').read_text().strip()]},
                  {'name': 'tester', 'shell': '/bin/sh', 'lock_passwd': False,
                   'plain_text_passwd': 'integration-only'}],
        'write_files': [{'path': '/etc/dotfiles-integration-guest', 'content': 'disposable\n'}],
        'runcmd': [['touch', '/var/lib/dotfiles-integration-ready']],
    }
    (directory / 'user-data').write_text('#cloud-config\n' + json.dumps(cloud))
    (directory / 'meta-data').write_text('instance-id: dotfiles-integration\n')
    seed = directory / 'seed.iso'
    run('genisoimage', '-quiet', '-output', str(seed), '-volid', 'cidata', '-joliet',
        '-rock', str(directory / 'user-data'), str(directory / 'meta-data'))
    # Include current working changes and untracked test files, but no .git,
    # generated output, credentials or unrelated untracked user files.
    tracked = subprocess.check_output(['git', '-C', str(REPO), 'ls-files', '-z']).decode().split('\0')
    files = {p for p in tracked if p and (REPO / p).is_file()}
    for folder in ('home', 'root', 'script', 'src', '.github/integration'):
        files.update(str(p.relative_to(REPO)) for p in (REPO / folder).rglob('*')
                     if p.is_file() or p.is_symlink())
    archive = directory / 'repo.tar'
    with tarfile.open(archive, 'w') as tar:
        for name in sorted(files):
            tar.add(REPO / name, arcname=name, recursive=False)
    base = directory / 'baseline.qcow2'
    overlay(image, base)
    run('qemu-img', 'resize', '-q', str(base), '24G')
    vm = VM(base, directory, key, seed, args.accel)
    try:
        print('Preparing pristine Debian guest', flush=True)
        vm.boot()
        with archive.open('rb') as stream:
            result = vm.ssh('mkdir -p /home/tester/Dotfiles && tar -xf - -C /home/tester/Dotfiles '
                            '&& chown -R tester:tester /home/tester/Dotfiles', stdin=stream)
        result.check_returncode()
        vm.command('cloud-init status --wait && '
                   'python3 /home/tester/Dotfiles/.github/integration/guest.py seed', 'prepare')
    finally:
        vm.stop()
    guest = 'python3 /home/tester/Dotfiles/.github/integration/guest.py '
    for case in ('install', 'rollback'):
        disk = directory / f'{case}.qcow2'
        overlay(base, disk)
        vm = VM(disk, directory, key, seed, args.accel)
        try:
            print(f'Booting {case} guest', flush=True)
            vm.boot()
            if case == 'install':
                vm.command(guest + 'first', 'first-installation')
                vm.command(guest + 'second', 'second-installation')
                vm.stop()
                vm.boot()
                vm.command(guest + 'check', 'after-reboot')
            else:
                vm.command(guest + 'rollback', 'installation-error')
        finally:
            vm.collect(case)
            vm.stop()
    print('PASS: all three integration scenarios, plus post-reboot check', flush=True)


if __name__ == '__main__':
    main()
