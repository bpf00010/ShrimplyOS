# 🦐 Shrimply OS: Mantis 🦐

## Project Overview
Shrimply OS is a barebones, Debian-based distribution featuring a hybrid approach that incorporates Linux From Scratch (LFS) compilation principles for core customization while utilizing a robust Debian userland. It features an optional XFCE desktop environment, falling back to LightDM and a Terminal User Interface (TUI) if bypassed.

### Directory Structure
```yaml
project:
  name: "Shrimply OS"
  codename: "Mantis"
  architecture: "x86_64"
  base: "Debian 12 (Bookworm)"
  build_methodology: "Hybrid (debootstrap userland + LFS-compiled custom kernel)"
directory_structure:
  /shrimply-build:
    /assets:
      - splash_shrimp.png
      - lightdm-crustacean-theme.conf
    /configs:
      - apt-sources.list
      - lightdm.conf
      - xfce4-session.rc
    /scripts:
      - 00-bootstrap.sh
      - 01-chroot-setup.sh
      - 02-hardware-detect.sh
      - 03-tui-fallback.sh
    /kernel:
      - .config
      - compile_kernel.sh
```

## System Dependencies and Repository Sources

**Table 1: Barebones Package Dependencies**
| Component | Package Name | Justification |
| :--- | :--- | :--- |
| Base System | `base-files`, `systemd`, `apt` | Absolute minimum Debian userland. |
| TUI Framework | `whiptail`, `dialog` | Required for the crustacean-themed terminal interface. |
| Hardware Detection | `pciutils`, `lshw` | Required to parse PCI buses for NVIDIA Vendor IDs. |
| Display Manager | `lightdm`, `lightdm-gtk-greeter` | Lightweight X11 greeter. |
| Desktop Environment | `xfwm4`, `xfce4-session`, `xfce4-panel` | Modular XFCE components (omitting `xfdesktop` to save RAM). |

**Table 2: Repository Sources (`apt-sources.list`)**
| Repository | URL | Components | Purpose |
| :--- | :--- | :--- | :--- |
| Bookworm Base | `http://deb.debian.org/debian/` | `main contrib non-free non-free-firmware` | Core packages and firmware. |
| Bookworm Security | `http://security.debian.org/` | `main contrib non-free non-free-firmware` | Critical CVE patches. |

**Table 3: Hardware Detection Parameters**
| Hardware | Vendor ID | Class ID | Target Package |
| :--- | :--- | :--- | :--- |
| NVIDIA GPU | `10de` | `0300` (VGA Compatible) | `nvidia-driver`, `firmware-misc-nonfree` |

## LightDM to XFCE Handoff and Minimalization

To keep the resource footprint as minimal as possible while retaining the custom visual aesthetic, we must strip XFCE of its bloated daemons and configure LightDM to be entirely subservient to the crustacean theme.

**1. LightDM Configuration (`/etc/lightdm/lightdm.conf`)**
We disable guest sessions, enforce the XFCE user session, and disable TCP listening to reduce the attack surface.

**2. LightDM GTK Greeter Theming (`/etc/lightdm/lightdm-gtk-greeter.conf`)**
Configured to use the `splash_shrimp.png` background and a dark theme.

**3. XFCE Minimalization Strategy**
By default, `xfce4-session` launches several background daemons (`xfdesktop` for desktop icons, `xfce4-volumed`, `polkit-gnome`). To achieve a barebones state:
*   **Purge `xfdesktop`**: If the user only needs a panel and window manager, do not install `xfdesktop`. This saves approximately 40MB of RAM.
*   **Disable Compositing**: In `xfwm4`, compositing (shadows, transparency) consumes GPU cycles and RAM. Disable it via `xfconf-query -c xfwm4 -p /general/use_compositing -s false`.
*   **Session Cache**: Clear `~/.cache/sessions/` on boot to prevent XFCE from restoring previously opened applications, ensuring a clean, predictable memory footprint upon every graphical ascension.

## Deeper Exploration and References

To further refine Shrimply OS, the following advanced documentation should be appended to your master build reference:

1.  **Debian Live Manual**: For converting this `debootstrap` chroot into a bootable ISO hybrid image using `squashfs` and `overlayfs`.
    *   *Reference*: [Debian Live Systems Manual](https://live-team.pages.debian.net/live-manual/html/live-manual.en.html)
2.  **XFCE Kiosk Mode**: To lock down the XFCE environment and prevent users from altering the crustacean motif or spawning unauthorized panels.
    *   *Reference*: [XFCE Kiosk Documentation](https://docs.xfce.org/xfce/xfce4-session/advanced)
3.  **Advanced Debootstrap & Multistrap**: For cross-compiling the userland if you intend to port Shrimply OS to ARM architectures (e.g., Raspberry Pi).
    *   *Reference*: [Debian Wiki - Multistrap](https://wiki.debian.org/Multistrap)
4.  **Linux From Scratch (LFS) Kernel Configuration**: For stripping the kernel of all unnecessary modules to achieve sub-second boot times.
    *   *Reference*: [LFS Chapter 10 - Making the LFS System Bootable](https://www.linuxfromscratch.org/lfs/view/stable/chapter10/kernel.html)

## UEFI-First ISO Build Workflow

Shrimply OS now uses a **UEFI-first ISO workflow** and treats BIOS hybrid post-processing as optional. In this environment, `live-build` may still call `isohybrid` during finalization even when UEFI is the target. The build script handles this by recovering the generated ISO artifact if `lb build` exits late in the pipeline.

### Expected build command

```bash
bash scripts/05-build-boot-image.sh
```

### Expected output artifacts

- `build/artifacts/shrimplyos-bookworm-amd64.iso`
- `build/artifacts/shrimplyos-bookworm-amd64.iso.sha256`

### Recovery behavior (by design)

If `lb build` returns non-zero near the end of binary image generation, the script will automatically salvage the ISO from known live-build output locations (for example `chroot/binary.hybrid.iso`) and still emit the final artifact and checksum. This is the supported workflow for this project on the current host toolchain.
