# u-install

Universal package manager wrapper for Linux.

Install software from native repositories, Nix, or AUR — with one command. No root required for user-space packages.

## Installation

```bash
git clone https://github.com/runvoid/u-install.git
cd u-install
./install
```

Or directly:

```bash
curl -fsSL https://raw.githubusercontent.com/runvoid/u-install/main/install | bash
```

## Commands

| Command | Description |
|---------|-------------|
| `u-install <package>` | Install a package from native repo, Nix, or AUR |
| `u-uninstall <package>` | Remove an installed package |
| `u-update` | Update system and user packages safely |

## Supported Distributions

- **Arch Linux** / Manjaro / EndeavourOS / Garuda (pacman + Nix + AUR)
- **Debian** / Ubuntu / Linux Mint / Pop!_OS (apt + Nix)
- **Fedora** / RHEL / Rocky Linux / AlmaLinux (dnf + Nix)
- **openSUSE** Leap / Tumbleweed (zypper + Nix)
- **Alpine Linux** (apk + Nix)
- **Any Linux** via Nix fallback

## Structure

```
u-install/
├── install          # Self-installer
├── u-install        # Install command
├── u-uninstall      # Uninstall command
├── u-update         # Update command
├── lib/
│   └── u-install.sh # Common functions
├── README.md
└── LICENSE
```

## Safety

- System-critical packages (kernel, bootloader, drivers, glibc) are updated **only** through the native package manager.
- User-space packages can be installed without root via Nix.
- AUR is supported only on Arch-based systems.

## License

MIT
