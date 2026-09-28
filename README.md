# Arch Environment Configuration

# env-config

Reproducible configuration, environment backup, and recovery tooling for my
Arch Linux workstation.

The goal of this repository is to make a fresh Arch installation capable of
reconstructing as much of my working environment as is safely practical,
without blindly restoring machine-specific storage, encryption, or boot data.

---

## Overview

The repository separates environment data into three broad categories:

### Automatically restorable

Configuration that can generally be restored safely:

- installed packages
- Zsh / Vim / Kitty / Git dotfiles
- Vim plugins
- KDE / Plasma preferences
- GTK configuration
- desktop launchers and custom assets
- selected user configuration
- selected `/etc` configuration
- `/usr/local/bin`
- systemd enablement

### Reference state

Information that describes what the working system looked like:

- disk/filesystem layout
- LVM layout
- Btrfs subvolumes
- PCI/USB hardware
- host, locale, and time settings
- bootloader state
- Secure Boot state
- systemd state
- kernel command line
- KDE display layout and KWin window-position overrides
- Vim plugin commits
- development-tool inventories

These files live primarily under:

```text
state/
```

They are normally used for comparison and reconstruction rather than copied
directly into the system.

### Guided reconstruction

Configuration that depends heavily on the actual machine and must not be
blindly restored:

- LUKS
- LVM
- Btrfs layout
- `/etc/fstab`
- `/etc/crypttab`
- mkinitcpio
- kernel command line
- systemd-boot
- Unified Kernel Images
- EFI
- Secure Boot
- Windows dual boot
- Snapper setup

---

# Repository layout

```text
env-config/
├── README.md
│
├── dotfiles/
│   ├── git/
│   ├── kitty/
│   ├── vim/
│   └── zsh/
│
├── packages/
│   ├── official.txt
│   ├── foreign.txt
│   ├── all-versioned.txt   exact versions, reference only; not installed from
│   ├── flatpak.txt
│   ├── flatpak-remotes.txt
│   └── code-extensions.txt
│
├── patches/
│   └── vim-obsession.patch
│
├── scripts/
│   ├── bootstrap
│   └── env-save
│
├── state/
│   ├── ...
│   └── user/          reference-only KDE/KWin state; not restored
│
├── system/
│   ├── etc/
│   ├── efi/
│   └── usr/local/bin/
│
└── user/
    ├── .config/
    ├── .local/
    └── .ssh/          only when ~/.ssh/config exists
```

---

# Saving the current environment

Run:

```bash
env-save
```

This updates the package manifests, selected configuration, plugin inventory,
system state, and reconstruction metadata.

`~/.zshrc` puts `scripts/` on `PATH`, so `env-save` and `bootstrap` run from
any directory.

`env-save --no-root` skips sudo. The root-only captures (`system/`, `blkid`,
`efibootmgr`, Btrfs subvolumes and filesystems, and LVM state) are then left
exactly as last saved.

Both scripts operate on `~/env-config` unless `ENV_CONFIG_REPO` points
elsewhere.

`env-save` is intended to be idempotent:

> Running it twice without meaningfully changing the machine should produce
> no Git diff.

After saving:

```bash
cd ~/env-config

git diff
git status --short
```

Review the changes before committing.

Then:

```bash
git add .
git commit -m "Update environment configuration"
git push
```

---

# Package updates

The `update` Zsh command runs the whole update under one sudo session:
`sudo pacman -Syu`, then `yay` (when installed), then `env-save`, then a shell
completion refresh. If the Pacman upgrade fails, `yay` and `env-save` are
skipped.

Each run is logged to `~/.updates/update.<timestamp>.log`, and `~/update.log`
always links to the latest log.

Because Arch does not support partial upgrades, the package bootstrap also
performs a full Pacman system upgrade while restoring explicitly installed
packages.

As a result:

```bash
./scripts/bootstrap packages
```

may upgrade already-installed packages in addition to installing missing ones.

---

# Bootstrap

Bootstrap is run as the normal user, not as root.

```bash
~/env-config/scripts/bootstrap help
```

Main phases:

```text
packages
dotfiles
vim
user
system-safe
services
review
all
```

Storage, encryption, EFI, and Secure Boot configuration are deliberately not
blindly restored.

---

# Fresh Arch recovery

After installing a minimal working Arch environment, creating my normal user,
establishing networking, and restoring GitHub SSH access:

```bash
git clone git@github.com:calebtimms/env-config.git ~/env-config

cd ~/env-config
```

Then reconstruct the system in stages.

---

## 1. Packages

```bash
./scripts/bootstrap packages
```

Restores:

- explicitly installed official Arch packages
- foreign/AUR packages where available
- the selected Yay AUR helper
- Flatpak remotes
- Flatpak applications
- Code OSS extensions

Generated `*-debug` packages are not treated as independent AUR packages.

A foreign package that can no longer be restored is reported rather than
preventing restoration of unrelated packages.

---

## 2. Dotfiles

```bash
./scripts/bootstrap dotfiles
```

Restores GNU Stow-managed configuration for:

- Zsh
- Vim
- Kitty
- Git

Existing conflicting files are backed up before replacement.

---

## 3. Vim plugins

```bash
./scripts/bootstrap vim
```

Vim plugin state is reconstructed from:

```text
state/vim-plugin-git.txt
```

For each Git-managed plugin, the saved state includes:

- path
- remote
- branch
- exact commit
- dirty/clean state

Plugins are restored to their exact saved commit while remaining on their
saved branch.

A plugin saved with local modifications (`DIRTY` in the inventory) needs a
matching `patches/vim-<plugin>.patch`. Bootstrap applies it after checkout and
stops if the patch is missing or doesn't apply cleanly. Currently the only one
is the Vim Obsession compatibility modification:

```text
patches/vim-obsession.patch
```

---

## 4. User configuration

```bash
./scripts/bootstrap user
```

Restores selected portable user configuration including:

- KDE / Plasma
- GTK
- XSettings
- Code OSS settings
- desktop launchers
- custom application icons
- KWin extensions
- user systemd configuration
- SSH client configuration

Existing differing paths are backed up first.

Backups are stored beneath:

```text
~/.local/state/env-config-bootstrap/<timestamp>/
```

SSH private keys and other secrets are intentionally excluded from this
repository.

---

## 5. Safe system configuration

```bash
./scripts/bootstrap system-safe
```

This phase requires sudo.

It previews all proposed changes and requires confirmation before modifying
anything.

Examples of configuration that may be restored automatically include:

```text
/etc/pacman.d/hooks

/etc/modprobe.d
/etc/modules-load.d

/etc/udev/rules.d
/etc/sysctl.d
/etc/tmpfiles.d

/etc/sddm.conf.d
/etc/X11/xorg.conf.d
/etc/environment.d

/etc/NetworkManager/conf.d
/etc/NetworkManager/dispatcher.d

/etc/systemd/*.conf.d

/etc/security/limits.d
/etc/ssh/sshd_config.d

/usr/local/bin
```

Custom unit files and drop-ins under `/etc/systemd/system` and
`/etc/systemd/user` are restored as well, but the enablement symlinks there are
not; the services phase handles enablement.

Existing files are backed up before replacement.

`systemctl daemon-reload` runs afterwards. No services are automatically
restarted.

---

## 6. systemd enablement

```bash
./scripts/bootstrap services
```

The bootstrap distinguishes three separate systemd scopes:

```text
system
global-user
per-user
```

Corresponding operations are approximately:

```bash
sudo systemctl enable UNIT
sudo systemctl --global enable UNIT
systemctl --user enable UNIT
```

Units are enabled but are **not started or restarted**.

Missing units are reported and skipped.

The saved default system target is also restored when necessary.

Changes made by the service phase are recorded under:

```text
~/.local/state/env-config-bootstrap/<timestamp>/services/
```

---

## 7. Review

```bash
./scripts/bootstrap review
```

This performs a read-only comparison between the reconstructed machine and the
saved environment.

It compares every saved file under `system/` against the live machine,
including critical files such as `fstab` and the EFI loader configuration that
are never restored automatically. EFI entries are skipped when `/efi` is not
mounted.

It then compares saved and currently enabled system and per-user units.

It needs sudo to read protected paths. No configuration is modified.

---

# `bootstrap all`

```bash
./scripts/bootstrap all
```

The aggregate action is intentionally conservative. It runs `packages`,
`dotfiles`, `vim`, `user`, and then `review`. It never runs `system-safe` or
`services`.

Critical system/storage/EFI restoration should remain an explicit guided
operation rather than something triggered accidentally by `bootstrap all`.

---

# Critical-system recovery

The following data is saved because it is important for disaster recovery,
but it must not simply be copied onto an arbitrary new installation:

```text
/etc/fstab
/etc/crypttab

/etc/mkinitcpio.conf
/etc/mkinitcpio.d/

/etc/kernel/

/efi/

/etc/snapper/configs/root
```

The new system's actual disk and filesystem identifiers must always be
verified first.

---

## Storage layout

Useful reference files include:

```text
state/lsblk.txt
state/blkid.txt
state/findmnt.txt

state/lvm-pvs.txt
state/lvm-vgs.txt
state/lvm-lvs.txt

state/btrfs-subvolumes.txt
state/btrfs-filesystems.txt
```

Kernel disk names (`nvme0n1`, `sda`) depend on probe order and can swap between
boots, so these files never record them. `lsblk`, `blkid`, and the LVM files
name disks and partitions by their `/dev/disk/by-id` path (for example
`/dev/disk/by-id/nvme-eui.002538a4514042df-part2`), and `findmnt.txt` uses
filesystem UUIDs. `/dev/mapper` names are already stable and are kept.

On a reconstructed system inspect:

```bash
lsblk -f
sudo blkid

sudo pvs
sudo vgs
sudo lvs -a -o +devices

sudo btrfs subvolume list /
```

Confirm the intended:

- Linux disk/partition
- LUKS container
- LVM volume group
- logical volumes
- Btrfs root/home layout
- `/boot`
- EFI System Partition
- `/efi`

Saved UUIDs must not be reused unless the new filesystems genuinely have the
same UUIDs.

---

## `fstab` and `crypttab`

Reference:

```text
system/etc/fstab
system/etc/crypttab
```

Compare them against:

```bash
lsblk -f
sudo blkid
```

Treat the saved versions as templates.

Do not blindly overwrite new files containing different filesystem or LUKS
identifiers.

---

## mkinitcpio and kernel command line

Reference:

```text
system/etc/mkinitcpio.conf
system/etc/mkinitcpio.d/
system/etc/kernel/

state/kernel-cmdline.txt
```

Verify:

- LUKS identifiers
- mapped-device names
- LVM root volume
- mkinitcpio hooks
- kernel command-line storage parameters

before regenerating the boot environment.

---

## systemd-boot / EFI

Reference:

```text
system/efi/
state/bootctl.txt
state/efibootmgr.txt
```

Verify that `/efi` is mounted to the intended EFI System Partition first.

Reinstall/repair systemd-boot from the reconstructed installation rather than
restoring old EFI executables from Git.

Saved loader configuration may be used as a template.

---

## Unified Kernel Images

The system uses Unified Kernel Images.

Reference:

```text
system/etc/kernel/
system/etc/mkinitcpio.d/
state/kernel-cmdline.txt
state/bootctl.txt
```

Regenerate UKIs on the reconstructed installation so that they contain the
new kernel/initramfs and correct disk/encryption identifiers.

Old `.efi` UKI binaries are not stored in Git.

---

## Secure Boot

Secure Boot private keys are intentionally not committed.

Reference:

```text
state/sbctl-status.txt
state/sbctl-verify.json
```

After reconstructing the boot environment:

```bash
sbctl status
sbctl verify
```

Confirm the expected EFI executables are correctly signed.

Enrollment/signing must use separately protected key material.

---

## Windows dual boot

Windows itself is not reconstructed by this repository.

After the Windows EFI environment exists, verify that systemd-boot can discover
or launch Windows as intended.

Use the saved boot/EFI state as a reference when troubleshooting.

---

## Snapper

Reference:

```text
system/etc/snapper/configs/root
state/btrfs-subvolumes.txt
```

After recreating the correct Btrfs layout:

1. install Snapper and snap-pac;
2. configure the root snapshot setup;
3. enable snapshot cleanup;
4. leave timeline snapshots disabled according to the current policy;
5. verify Pacman transactions create pre/post snapshots.

The root Snapper configuration does not protect separate non-Btrfs filesystems
such as the EFI System Partition.

---

# Reference-only development inventories

`env-save` may also record development-tool inventories such as:

```text
cargo-installed.txt
rust-toolchains.txt
uv-tools.txt
pipx.txt
npm-global.txt
```

These are currently informational.

They are deliberately not automatically executed by bootstrap because each
ecosystem has its own versioning and environment semantics.

---

# Bootstrap backups

Any user/system configuration replaced by bootstrap is backed up beneath:

```text
~/.local/state/env-config-bootstrap/<timestamp>/
```

Possible sections include:

```text
user/
system/
services/
```

These backups are local rollback material and are not committed to the
environment repository.

---

# Secrets

Never commit:

- SSH private keys
- Secure Boot private keys
- passwords
- API tokens
- credential stores
- browser profiles
- NetworkManager connection secrets
- private certificates

The repository stores configuration and reconstruction metadata, not
authentication material.

---

# Final validation

After reconstruction:

```bash
env-save

cd ~/env-config
git status --short
```

Then:

```bash
./scripts/bootstrap review
```

An unchanged, faithfully reconstructed environment should not produce noisy
state changes.

Any remaining differences should represent either:

- meaningful configuration drift; or
- intentionally machine-specific values that require review.

---

# Design principle

The goal is:

> Automate what is portable and safe, record what is useful, and require human
> verification for anything capable of making the machine unbootable.

That keeps recovery fast without turning the bootstrap into a blind copy of
machine-specific state.
