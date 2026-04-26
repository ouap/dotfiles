#!/usr/bin/env bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# Small logging helpers to keep installer output readable.
log() {
  printf "\033[1;34m==>\033[0m %s\n" "$1"
}

warn() {
  printf "\033[1;33mWarning:\033[0m %s\n" "$1"
}

die() {
  printf "\033[1;31mError:\033[0m %s\n" "$1" >&2
  exit 1
}

ensure_xcode_cli_tools() {
  if xcode-select -p >/dev/null 2>&1; then
    return
  fi

  # Homebrew depends on Apple's command line developer tools.
  warn "Xcode Command Line Tools are not installed."
  warn "A macOS installer prompt may open. Re-run this script after the installation finishes."
  xcode-select --install || true
  exit 1
}

ensure_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    return
  fi

  # Install Homebrew only when it is missing.
  log "Installing Homebrew"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    die "Homebrew installation finished, but brew was not found."
  fi
}

ensure_homebrew_in_path() {
  if command -v brew >/dev/null 2>&1; then
    eval "$(brew shellenv)"
  elif [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

backup_path() {
  local target="$1"

  # Keep a copy of existing local config before replacing it.
  mkdir -p "$BACKUP_DIR$(dirname "$target")"
  mv "$target" "$BACKUP_DIR$target"
  warn "Moved existing $target to $BACKUP_DIR$target"
}

link_file() {
  local source="$1"
  local target="$2"
  local target_dir

  target_dir="$(dirname "$target")"
  mkdir -p "$target_dir"

  # Relink existing symlinks, but backup real files/directories first.
  if [[ -L "$target" ]]; then
    local current_source
    current_source="$(readlink "$target")"

    if [[ "$current_source" == "$source" ]]; then
      log "Already linked: $target"
      return
    fi

    rm "$target"
  elif [[ -e "$target" ]]; then
    backup_path "$target"
  fi

  ln -s "$source" "$target"
  log "Linked $target -> $source"
}

install_brew_bundle() {
  log "Installing Homebrew packages and apps"
  brew bundle --file "$DOTFILES_DIR/Brewfile"
}

install_fzf_shell_integration() {
  local fzf_install

  fzf_install="$(brew --prefix)/opt/fzf/install"
  if [[ -x "$fzf_install" ]]; then
    log "Installing fzf shell integration"
    "$fzf_install" --key-bindings --completion --no-update-rc
  fi
}

link_dotfiles() {
  log "Linking dotfiles"

  link_file "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
  link_file "$DOTFILES_DIR/starship/starship.toml" "$HOME/.config/starship.toml"
  link_file "$DOTFILES_DIR/ghostty/config" "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
}

offer_raycast_import() {
  local raycast_config="$DOTFILES_DIR/raycast/raycast.rayconfig"

  if [[ ! -f "$raycast_config" ]]; then
    return
  fi

  log "Raycast config is available at: $raycast_config"

  # Raycast imports settings from its app UI when opening the export file.
  if [[ -d "/Applications/Raycast.app" ]]; then
    warn "Raycast settings usually need to be imported manually from the .rayconfig file."
    warn "Opening the file now so Raycast can import it."
    open "$raycast_config" || true
  fi
}


main() {
  # Bootstrap the Mac first, then install packages, then link user config.
  ensure_xcode_cli_tools
  ensure_homebrew_in_path
  ensure_homebrew
  install_brew_bundle
  install_fzf_shell_integration
  link_dotfiles
  offer_raycast_import

  log "Done. Restart terminal or run: source ~/.zshrc"
}

main "$@"
