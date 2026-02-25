# 🦐 Shrimply OS Build Kickoff (Post-Reboot) 🦐

## Current State
- Local git repository initialized and initial commit created.
- WSL installation command completed successfully.
- Host reboot is required before WSL can be used.

## 1) Reboot Requirement
Run this in elevated PowerShell if you want immediate restart:

```powershell
Restart-Computer -Force
```

## 2) First-boot WSL setup (after reboot)

```powershell
wsl --status
wsl --install -d Ubuntu
wsl -d Ubuntu
```

Inside Ubuntu:

```bash
sudo apt update
sudo apt install -y debootstrap xz-utils wget curl ca-certificates gnupg lsb-release whiptail dialog pciutils
```

## 3) Move project into Linux FS for reliable permissions/chroot
Inside Ubuntu:

```bash
mkdir -p ~/src
cp -r /mnt/c/Users/igdes/ShrimplyOS ~/src/ShrimplyOS
cd ~/src/ShrimplyOS
chmod +x scripts/*.sh kernel/compile_kernel.sh
```

## 4) Start bootstrap stage
Inside Ubuntu:

```bash
sudo bash scripts/00-bootstrap.sh
```

## 5) LFS discipline constraints used in this project
- LFS-style source compilation is limited to kernel and isolated tooling.
- Debian userland ABI-managed packages remain under apt/dpkg control.
- Do not replace glibc/coreutils/systemd with from-source builds in this hybrid model.

## 6) NVIDIA install behavior
- Detection occurs in `scripts/02-hardware-detect.sh` via PCI vendor ID `10de`.
- Installer prompt offers proprietary driver installation using Debian packages.
- If declined, system remains on open-source stack.

## 7) Minimal LightDM/XFCE handoff policy
- Default target is `multi-user.target`.
- TUI runs first and asks whether to isolate into `graphical.target`.
- XFCE package set intentionally excludes bulky components.

## 8) Build validation checkpoints
1. `debootstrap` completes without keyring or repository errors.
2. Chroot package install completes without unresolved dependencies.
3. LightDM config files present under `/etc/lightdm`.
4. TUI and NVIDIA prompt render correctly via `whiptail`.
5. `systemctl isolate graphical.target` transitions cleanly.

## 9) Known host-side blockers
- No `gh` CLI is installed yet.
- GitHub repo creation requires either:
  - GitHub username + PAT token, or
  - `gh auth login` after installing GitHub CLI.
