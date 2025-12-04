# Antigravity Installer (Arch Linux)

Unofficial installer for **Google Antigravity** on Arch-based Linux distributions (Arch, Manjaro, Garuda, etc.).

## Features

- **Automated Fetching**: Grabs the latest build directly from Google's APT repository.
- **Smart Updates**: Checks your installed version and only updates if a newer release is available.
- **Security**: Verifies package integrity via SHA256 checksums.
- **Sandboxing**: Applies Chrome-style sandbox permissions for stability.
- **Integration**: Installs to `/opt/antigravity`, creates a `/usr/local/bin/antigravity` launcher, and sets up desktop entries and icons.

## Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/MrHummerberg/antigravity-arch
   cd antigravity-arch
   ```

2. **Run the installer:**
   ```bash
   chmod +x antigravity-installer.sh
   ./antigravity-installer.sh
   ```

   The script will automatically fetch, verify, and install the latest version.

## Usage

- **Run Antigravity:**
  ```bash
  antigravity
  ```

- **Update:**
  Run the installer script again. It will detect if a new version is available.
  ```bash
  ./antigravity-installer.sh
  ```

- **Force Reinstall:**
  To force a re-download and installation of the current version:
  ```bash
  ./antigravity-installer.sh --force
  ```

- **Uninstall:**
  ```bash
  ./antigravity-installer.sh --uninstall
  ```

## Requirements

The script requires standard system utilities:
- `curl`
- `bsdtar` (libarchive)
- `sha256sum` (coreutils)
- `awk`
- `sudo`

## Disclaimer

This is an **unofficial** installer and is not affiliated with Google. Use at your own risk.
