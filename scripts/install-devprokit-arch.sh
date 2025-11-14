#!/usr/bin/env bash
# scripts/install-devkitpro-arch.sh
# Installs or configures devkitPro on systems that already provide pacman (Arch, msys2, etc.)
# and configures the environment for working with the dustpq/3ds-project repository and
# lovepotion/lovebrew.
#
# This script supports:
#  - Running the official devkitPro pacman installer (default)
#  - Configuring an existing pacman install to use devkitPro repos/keyring
#    (useful for Arch, msys2, Alpine, Void, Fedora users who use pacman)
#
# Usage:
#   chmod +x scripts/install-devkitpro-arch.sh
#   ./scripts/install-devkitpro-arch.sh [--clone-repo] [--lovebrew-path /path/to/lovebrew] [--no-install]
#       [--use-system-pacman] [--devkitpro-path /opt/devkitpro]
#
# Options:
#   --clone-repo             : clone https://github.com/dustpq/3ds-project.git into ~/code/3ds-project
#   --lovebrew-path <path>   : path to a local lovebrew checkout to optionally copy romfs into
#   --no-install             : only clone repo / configure environment, skip installing packages
#   --use-system-pacman      : Do NOT run the official devkitPro installer; instead configure
#                              the current system pacman by importing keys, installing keyring,
#                              and appending devkitPro repo entries to /etc/pacman.conf
#   --devkitpro-path <path>  : Suggested DEVKITPRO base path to write to /etc/profile.d (default: /opt/devkitpro)
#   -h, --help               : Show this help and exit
set -euo pipefail

REPO_GIT_URL="https://github.com/dustpq/3ds-project.git"
REPO_NAME="3ds-project"
DEST_DIR_DEFAULT="$HOME/code/$REPO_NAME"

RECOMMENDED_PACKAGES=(
  devkitARM
  libctru
  citro2d
  citro3d
  libsndfile
  libogg
  libvorbis
  libpng
  libjpeg-turbo
  freetype2
  zlib
)

# Official installer used by many distributions (will install dkp-pacman and configure repos)
INSTALLER_URL="https://apt.devkitpro.org/install-devkitpro-pacman.sh"
TMPDIR="$(mktemp -d)"
CURL_OPTS="-fsSL"

show_help() {
  cat <<EOF
Usage: $0 [--clone-repo] [--lovebrew-path /path/to/lovebrew] [--no-install]
          [--use-system-pacman] [--devkitpro-path /opt/devkitpro]

This script installs or configures devkitPro and a curated set of packages useful
for lovepotion / lovebrew 3DS development, and makes it convenient to work with
the ${REPO_NAME} repository.

Options:
  --clone-repo           Clone ${REPO_GIT_URL} into ~/code/${REPO_NAME} (if not present)
  --lovebrew-path <path> Copy romfs/ from the repo into the specified lovebrew checkout
  --no-install           Do not install packages or run the devkitPro installer; perform only cloning/config steps
  --use-system-pacman    Configure the existing pacman installation (import key, install keyring,
                         and add devkitPro repo entries) instead of running the official installer.
  --devkitpro-path <p>   Path to set as DEVKITPRO in profile.d (default: /opt/devkitpro)
  -h, --help             Show this help and exit

Notes:
 - If you already used the devkitPro installer (dkp-pacman), do NOT use --use-system-pacman.
 - For msys2 users: run without sudo; this script will avoid sudo where possible but may request it.
EOF
}

cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

# Parse args
CLONE_REPO=false
LOVEBOOT_PATH=""
NO_INSTALL=false
USE_SYSTEM_PACMAN=false
DEVKITPRO_PATH="/opt/devkitpro"

while [[ ${#} -gt 0 ]]; do
  case "$1" in
    --clone-repo)
      CLONE_REPO=true
      shift
      ;;
    --lovebrew-path)
      LOVEBOOT_PATH="$2"; shift 2
      ;;
    --no-install)
      NO_INSTALL=true
      shift
      ;;
    --use-system-pacman)
      USE_SYSTEM_PACMAN=true
      shift
      ;;
    --devkitpro-path)
      DEVKITPRO_PATH="$2"; shift 2
      ;;
    -h|--help)
      show_help; exit 0
      ;;
    *)
      echo "Unknown argument: $1"; show_help; exit 2
      ;;
  esac
done

if [[ "$(uname -s)" != "Linux" && -z "${MSYSTEM-}" ]]; then
  echo "Warning: This script assumes a pacman-based environment (Arch, msys2, etc.)."
  echo "Continuing, but be sure pacman is present if you want installation/config steps."
fi

if ! command -v pacman >/dev/null 2>&1; then
  echo "Error: pacman not found. This script is intended for Arch Linux, msys2, or other pacman systems."
  exit 1
fi

# Helpers for pacman-based manual setup
KEYID="BC26F752D25B92CE272E0F44F7FD5492264BB9D0"
KEYSERVERS=(
  "keyserver.ubuntu.com"
  "hkps://keys.openpgp.org"
  "keyserver.pgp.com"
)

detect_musl() {
  # Returns 0 if musl libc detected
  if command -v ldd >/dev/null 2>&1; then
    if ldd --version 2>&1 | grep -qi musl; then
      return 0
    fi
  fi
  return 1
}

append_repo_if_missing() {
  local name="$1"
  local block="$2"
  if ! grep -q "^\[$name\]" /etc/pacman.conf 2>/dev/null || ! grep -q "Server" /etc/pacman.conf; then
    echo "Adding [$name] repo to /etc/pacman.conf"
    # Use sudo tee -a to append
    printf "\n%s\n" "$block" | sudo tee -a /etc/pacman.conf >/dev/null
  else
    echo "Repo [$name] seems to already exist in /etc/pacman.conf; skipping append"
  fi
}

install_devkitpro_via_pacman_config() {
  echo "== Manual pacman-based devkitPro configuration selected"

  # Suggest environment variables (not exported by default)
  echo "Suggested environment variables for using system-installed devkitPro:"
  echo "  DEVKITPRO=${DEVKITPRO_PATH}"
  echo "  DEVKITARM=\${DEVKITPRO}/devkitARM"
  echo "  DEVKITPPC=\${DEVKITPRO}/devkitPPC"
  echo

  echo "== 1) Importing devkitPro GPG key for package validation"
  local imported=false
  for ks in "${KEYSERVERS[@]}"; do
    echo "Trying keyserver: $ks"
    if sudo pacman-key --recv-keys "$KEYID" --keyserver "$ks" 2>/dev/null; then
      imported=true
      break
    fi
  done
  if ! $imported; then
    echo "pacman-key recv failed on the configured keyservers. You may need to run the following manually:"
    echo "  sudo pacman-key --recv $KEYID --keyserver keyserver.ubuntu.com"
    echo "Or see https://wiki.archlinux.org/title/pacman/GnuPG for debugging keyserver issues."
  else
    echo "Locally signing the key..."
    sudo pacman-key --lsign-keys "$KEYID" || true
  fi

  echo "== 2) Installing devkitpro keyring package from upstream"
  if ! sudo pacman -U --noconfirm "https://pkg.devkitpro.org/devkitpro-keyring.pkg.tar.zst"; then
    echo "Failed to install devkitpro-keyring via pacman -U. Attempting to populate keyring..."
    sudo pacman-key --populate devkitpro || true
  fi

  echo "== 3) Adding devkitPro repository entries to /etc/pacman.conf (if missing)"
  # Always add dkp-libs
  block_libs="[dkp-libs]
Server = https://pkg.devkitpro.org/packages"
  append_repo_if_missing "dkp-libs" "$block_libs"

  # Add Linux host repo or musl variant or msys2/windows depending on system
  if [[ -n "${MSYSTEM-}" ]]; then
    # MSYS2 environment - use windows repo
    block_win="[dkp-windows]
Server = https://pkg.devkitpro.org/packages/windows/\$arch/"
    append_repo_if_missing "dkp-windows" "$block_win"
  else
    if detect_musl; then
      block_musl="[dkp-linux-musl]
Server = https://pkg.devkitpro.org/packages/linux-musl/\$arch/"
      append_repo_if_missing "dkp-linux-musl" "$block_musl"
    else
      block_linux="[dkp-linux]
Server = https://pkg.devkitpro.org/packages/linux/\$arch/"
      append_repo_if_missing "dkp-linux" "$block_linux"
    fi
  fi

  echo "== 4) Refreshing pacman DB and upgrading (may prompt for sudo/pass)"
  sudo pacman -Syu --noconfirm || echo "pacman -Syu returned non-zero (you may wish to run it manually)"

  echo "Manual pacman configuration complete. You can now install devkitPro packages, e.g.:"
  echo "  sudo pacman -S --needed ${RECOMMENDED_PACKAGES[*]}"
  echo
}

# Install prerequisites and devkitPro + packages unless skipped
if [ "$NO_INSTALL" = false ]; then
  if [ "$USE_SYSTEM_PACMAN" = true ]; then
    install_devkitpro_via_pacman_config
  else
    echo "== Default: using the official devkitPro pacman installer (recommended for most users)"
    echo "If you prefer to configure your existing pacman manually, re-run with --use-system-pacman"

    echo "== 1) Installing base prerequisites via pacman..."
    sudo pacman -Syu --needed --noconfirm base-devel git curl wget python unzip rsync make cmake pkgconf || {
      echo "Failed to install prerequisites with pacman. Please fix pacman/network and retry."; exit 1
    }

    echo "== 2) Downloading the official devkitPro pacman installer"
    INSTALLER_SH="$TMPDIR/install-devkitpro-pacman.sh"
    if ! curl $CURL_OPTS "$INSTALLER_URL" -o "$INSTALLER_SH"; then
      echo "Failed to download devkitPro installer. Check network or visit https://devkitpro.org/wiki/Getting_Started"; exit 1
    fi
    chmod +x "$INSTALLER_SH"

    echo "== 3) Running the devkitPro installer (this will request sudo)..."
    sudo bash "$INSTALLER_SH"

    echo "== 4) Installing curated devkitPro packages for lovepotion / lovebrew:"
    printf "  -> %s\n" "${RECOMMENDED_PACKAGES[@]}"
    read -r -p "Proceed to install the packages above now? [Y/n] " yn
    yn=${yn:-Y}
    if [[ "$yn" =~ ^[Yy]$ ]]; then
      sudo pacman -S --needed --noconfirm "${RECOMMENDED_PACKAGES[@]}" || {
        echo "Package installation encountered an error. You can retry manually: sudo pacman -S ${RECOMMENDED_PACKAGES[*]}"; exit 1
      }
    else
      echo "Skipping package installation as requested."
    fi
  fi
else
  echo "--no-install specified: skipping installer and package installation steps."
fi

# Optionally write environment profile for system installs if requested / appropriate
maybe_write_profile() {
  # Write /etc/profile.d/devkitpro.sh with suggested environment variables if sudo available.
  local profile="/etc/profile.d/devkitpro.sh"
  if [ -w /etc/profile.d ] || sudo test -d /etc/profile.d; then
    if ! sudo test -f "$profile"; then
      echo "Would you like me to create $profile to export DEVKITPRO and DEVKITARM/DEVKITPPC? [y/N]"
      read -r do_write
      do_write=${do_write:-N}
      if [[ "$do_write" =~ ^[Yy]$ ]]; then
        echo "Writing $profile (requires sudo)..."
        sudo tee "$profile" >/dev/null <<EOF
# devkitPro environment for system-installed devkitPro
export DEVKITPRO=${DEVKITPRO_PATH}
export DEVKITARM=\${DEVKITPRO}/devkitARM
export DEVKITPPC=\${DEVKITPRO}/devkitPPC
# Add toolchains to PATH if they exist (user may want to adjust shell-specific files)
if [ -d "\${DEVKITARM}/bin" ]; then
  export PATH="\${DEVKITARM}/bin:\${PATH}"
fi
EOF
        echo "$profile created. Open a new shell or source it to pick up changes."
      fi
    else
      echo "$profile already exists; skipping creation."
    fi
  else
    echo "Cannot write to /etc/profile.d (sudo required). To set environment variables, add:"
    echo "  export DEVKITPRO=${DEVKITPRO_PATH}"
    echo "  export DEVKITARM=\$DEVKITPRO/devkitARM"
  fi
}

# Ask to write profile only if we used manual pacman configuration or the user installed via installer
if [ "$NO_INSTALL" = false ]; then
  maybe_write_profile
fi

# Clone the repo if requested or if not running from inside the repo
CURRENT_DIR="$(pwd)"
IS_IN_REPO=false
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  # check remote
  remote_url="$(git config --get remote.origin.url || true)"
  if [[ "$remote_url" == "${REPO_GIT_URL}" || "$remote_url" == "git@github.com:dustpq/${REPO_NAME}.git" || "$CURRENT_DIR" =~ "/${REPO_NAME}" ]]; then
    IS_IN_REPO=true
  fi
fi

if $CLONE_REPO; then
  DEST_DIR="$DEST_DIR_DEFAULT"
  mkdir -p "$(dirname "$DEST_DIR")"
  if [ -d "$DEST_DIR/.git" ]; then
    echo "Repo already exists at $DEST_DIR; pulling latest changes"
    (cd "$DEST_DIR" && git pull --ff-only) || echo "Warning: pull failed"
  else
    echo "Cloning ${REPO_GIT_URL} -> $DEST_DIR"
    git clone "$REPO_GIT_URL" "$DEST_DIR" || { echo "Clone failed"; exit 1; }
  fi
  IS_IN_REPO=true
  CURRENT_DIR="$DEST_DIR"
fi

# If we're inside the repo (or just cloned it), offer to copy romfs into lovebrew
if $IS_IN_REPO; then
  echo "Detected repository context at: $CURRENT_DIR"
  if [ -z "$LOVEBOOT_PATH" ]; then
    read -r -p "If you have a local lovepotion/lovebrew checkout where you want romfs copied, enter its path now (or leave empty to skip): " LOVEBOOT_PATH
  fi

  if [ -n "$LOVEBOOT_PATH" ]; then
    if [ ! -d "$LOVEBOOT_PATH" ]; then
      echo "lovebrew path $LOVEBOOT_PATH does not exist. Would you like to clone lovepotion/lovebrew into ~/code/lovebrew? [y/N]"
      read -r clone_lb
      clone_lb=${clone_lb:-N}
      if [[ "$clone_lb" =~ ^[Yy]$ ]]; then
        mkdir -p ~/code
        git clone https://github.com/lovepotion/lovebrew.git ~/code/lovebrew || echo "Failed to clone lovebrew; continuing"
        LOVEBOOT_PATH=~/code/lovebrew
      else
        echo "Skipping lovebrew clone; skipping romfs copy."
        LOVEBOOT_PATH=""
      fi
    fi
  fi

  if [ -n "$LOVEBOOT_PATH" ]; then
    if [ ! -d "$CURRENT_DIR/romfs" ]; then
      echo "Warning: no romfs/ directory found in repository at $CURRENT_DIR/romfs"
      read -r -p "Create empty romfs/ now and continue? [y/N] " create_romfs
      create_romfs=${create_romfs:-N}
      if [[ "$create_romfs" =~ ^[Yy]$ ]]; then
        mkdir -p "$CURRENT_DIR/romfs"
        touch "$CURRENT_DIR/romfs/.gitkeep"
      else
        echo "Skipping romfs copy."
      fi
    fi

    if [ -d "$CURRENT_DIR/romfs" ]; then
      DEST="$LOVEBOOT_PATH/romfs/$REPO_NAME"
      echo "Copying romfs/ -> $DEST"
      rm -rf "$DEST"
      mkdir -p "$DEST"
      rsync -av --delete "$CURRENT_DIR/romfs/" "$DEST/" || echo "rsync failed"
      echo "romfs copied."

      read -r -p "Run make in $LOVEBOOT_PATH now (if a Makefile exists) to build the homebrew ROM? [y/N] " do_build
      do_build=${do_build:-N}
      if [[ "$do_build" =~ ^[Yy]$ ]]; then
        if [ -f "$LOVEBOOT_PATH/Makefile" ]; then
          (cd "$LOVEBOOT_PATH" && make) || echo "Build failed or returned non-zero"
        else
          echo "No Makefile found in $LOVEBOOT_PATH; skipping build. Follow lovebrew README for build instructions."
        fi
      fi
    fi
  fi
else
  echo "Not running inside ${REPO_NAME} repository and --clone-repo not specified. To operate on the repo, re-run with --clone-repo or run this script from inside the repository."
fi

# Final notes and verification
cat <<EOF


Setup complete (or skipped per options). A few final checks/suggestions:
 - Open a new shell to ensure any PATH changes made by the devkitPro installer or /etc/profile.d are active.
 - Verify toolchain: which arm-none-eabi-gcc || echo 'arm-none-eabi-gcc not found in PATH yet'
 - If you used --use-system-pacman you may want to add:
     export DEVKITPRO=${DEVKITPRO_PATH}
     export DEVKITARM=\$DEVKITPRO/devkitARM
     export DEVKITPPC=\$DEVKITPRO/devkitPPC
   to your shell profile (~/.bashrc, ~/.profile) or create /etc/profile.d/devkitpro.sh as suggested.
 - To add this file to the repository: create scripts/install-devkitpro-arch.sh, commit, and push to your repo.
EOF
