#!/usr/bin/env bash
# scripts/install-devkitpro-arch.sh
# Installs devkitPro on Arch Linux and configures the environment for working with the
# dustpq/3ds-project repository and lovepotion/lovebrew. This script is intended to be
# committed into the repository and run locally (with sudo where required).
#
# Usage:
#   chmod +x scripts/install-devkitpro-arch.sh
#   ./scripts/install-devkitpro-arch.sh [--clone-repo] [--lovebrew-path /path/to/lovebrew] [--no-install]
#
# Options:
#   --clone-repo           : clone https://github.com/dustpq/3ds-project.git into ~/code/3ds-project
#   --lovebrew-path <path> : path to a local lovebrew checkout to optionally copy romfs into
#   --no-install           : only clone repo / configure environment, skip installing packages
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

INSTALLER_URL="https://apt.devkitpro.org/install-devkitpro-pacman.sh"
TMPDIR="$(mktemp -d)"
CURL_OPTS="-fsSL"

show_help() {
  cat <<EOF
Usage: $0 [--clone-repo] [--lovebrew-path /path/to/lovebrew] [--no-install]

This script installs devkitPro (using the official pacman installer) and a curated set
of devkitPro packages useful for lovepotion / lovebrew 3DS development, and makes
it convenient to work with the ${REPO_NAME} repository.

Options:
  --clone-repo           Clone ${REPO_GIT_URL} into ~/code/${REPO_NAME} (if not present)
  --lovebrew-path <path> Copy romfs/ from the repo into the specified lovebrew checkout
  --no-install           Do not install packages or run the devkitPro installer; perform only cloning/config steps
  -h, --help             Show this help and exit
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
    -h|--help)
      show_help; exit 0
      ;;
    *)
      echo "Unknown argument: $1"; show_help; exit 2
      ;;
  esac
done

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Error: This script is for Arch Linux. Exiting."
  exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
  echo "Error: pacman not found. This script is intended for Arch Linux or derivatives."
  exit 1
fi

# Install prerequisites and devkitPro + packages unless skipped
if [ "$NO_INSTALL" = false ]; then
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
else
  echo "--no-install specified: skipping installer and package installation steps."
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
 - Open a new shell to ensure any PATH changes made by the devkitPro installer are active.
 - Verify toolchain: which arm-none-eabi-gcc || echo 'arm-none-eabi-gcc not found in PATH yet'
 - If you want the script to automatically add PATH/export lines to your shell profile (~/.bashrc or ~/.profile), ask and I can add that.
 - To add this file to the repository: create scripts/install-devkitpro-arch.sh, commit, and push to your repo.
EOF
