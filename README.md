# u-install

Universal package manager wrapper for Linux.

Install software from native repositories, Nix, or AUR — with one command.
User-space packages do not require root.

## Quick Install

```bash
git clone https://github.com/YOUR_USERNAME/u-install.git
cd u-install
./install
```

Then restart your terminal and use:

```bash
u-install neovim
u-uninstall neovim
u-update
```

## Commands

| Command | Description |
|---------|-------------|
| `u-install <package>` | Install from native repo, Nix, or AUR |
| `u-install <package> --nix` | Force install via Nix |
| `u-install <package> --aur` | Force install via AUR (Arch-based) |
| `u-install <package> --native` | Force install via native PM |
| `u-uninstall <package>` | Remove an installed package |
| `u-update` | Update system, Nix, and AUR packages safely |
| `u-update --system` | Update only system packages |
| `u-update --nix` | Update only Nix packages |
| `u-update --aur` | Update only AUR packages |

## Supported Distributions

- **Arch Linux** / Manjaro / EndeavourOS / Garuda (pacman + Nix + AUR)
- **Debian** / Ubuntu / Linux Mint / Pop!_OS (apt + Nix)
- **Fedora** / RHEL / Rocky Linux / AlmaLinux (dnf + Nix)
- **openSUSE** Leap / Tumbleweed (zypper + Nix)
- **Alpine Linux** (apk + Nix)
- **Any Linux** via Nix fallback

## Safety

- System-critical packages (kernel, bootloader, glibc, drivers, systemd) are updated **only** through the native package manager.
- Nix installs are user-local (`~/.nix-profile`) and do not touch `/usr`.
- AUR is supported only on Arch-based systems with `base-devel` installed.

## Files

```
u-install/
├── install          # Self-installer
├── u-install        # Install command
├── u-uninstall      # Uninstall command
├── u-update         # Update command
├── lib/
│   └── u-install.sh # Common library
├── README.md
└── LICENSE
```

## License

MIT
