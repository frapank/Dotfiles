# Installer integration tests

Run from the repository, with QEMU, qemu-img, genisoimage, OpenSSH and Python 3.11+
installed:

```sh
python3 .github/integration/run.py --output /tmp/dotfiles-integration
```

The output directory must not exist. The runner downloads the official Debian 13
amd64 cloud image and checks its SHA-512 against Debian's published checksum.
`--image /path/to/image.qcow2` uses an already verified local image. TCG works
without root or KVM; `--accel kvm` can speed up a host with accessible `/dev/kvm`.
Allow up to an hour on a software-emulated VM. The VM needs internet access for
APT. The host's system configuration is never changed, and the base image is
opened only as a backing file for disposable overlays.

The essential profile is **locale, cli, logs, dirs, doas**. Tests drive the real
installer's interactive menu through a PTY; no APT, filesystem or systemd commands
are mocked. A prepared clean baseline branches into two independent VM disks:

1. **First installation:** check installed configuration contents, ownership and
   modes, retained personal files, folders, locale, groups, doas, sudo removal,
   watchdog activation and editor startup.
2. **Second installation:** run the same installer again and compare managed
   files, permissions, installed package names, manual package marks, shell,
   groups, service state and watchdog sysctls. No extra home backups should
   appear. Reboot and check the installed state again.
3. **Error during installation:** on the other clean disk, insert a deliberate
   failing command after the last selected step, in the guest's disposable copy
   of the installer. Check nonzero exit, the real rollback running, no failed undo
   operations, and restoration of baseline files, symlinks, modes, groups, shell,
   package names/manual marks, service state and watchdog sysctls. This includes
   personal sudo rules and a locked root account, to check replacement with doas.
   The injection never modifies the host's checkout and adds no failure hooks to
   the production installer.

These cover this essential profile, not desktop compilation, graphical login,
AppArmor enforcement, hardware, Btrfs recovery or package-version downgrades.
Package versions and generated package caches are not part of rollback assertions.

Host logs and guest console/installer logs are retained in the output directory.
Guest artifacts include baseline/installed state and a JSON rollback diff when
state differs. GitHub Actions uploads logs even on failure. VM disks stay local
and are not uploaded. Do not run `guest.py` on the host; it requires both the
disposable guest marker and the QEMU-specific DMI product name.
