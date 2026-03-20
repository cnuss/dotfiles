#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Laptop setup script — managed via Claude Code
# For: Christian Nuss <christian.nuss@gmail.com>
# ==============================================================================

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Starting setup from $DOTFILES_DIR"

# --- Touch ID for sudo ---
if [[ ! -f /etc/pam.d/sudo_local ]]; then
  echo "==> Enabling Touch ID for sudo..."
  sudo cp /etc/pam.d/sudo_local.template /etc/pam.d/sudo_local
  sudo sed -i '' 's/#auth/auth/' /etc/pam.d/sudo_local
fi

# --- Docker CLI plugins prerequisite ---
sudo mkdir -p /usr/local/cli-plugins

# --- Homebrew ---
if ! command -v brew &>/dev/null; then
  echo "==> Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add brew to PATH for Apple Silicon Macs
  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
else
  echo "==> Homebrew already installed"
fi

# --- Brewfile ---
echo "==> Installing Brewfile packages..."
brew bundle --file="$DOTFILES_DIR/Brewfile"

# --- Rust toolchain (rustup doesn't install a toolchain by default) ---
if command -v rustup &>/dev/null && ! rustup toolchain list | grep -q stable; then
  echo "==> Installing Rust stable toolchain..."
  rustup install stable
  rustup default stable
fi

# --- Symlink dotfiles ---
echo "==> Symlinking dotfiles..."
ln -sf "$DOTFILES_DIR/.zprofile" "$HOME/.zprofile"
ln -sf "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
ln -sf "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"

# --- GPG config ---
echo "==> Configuring gpg..."
mkdir -p "$HOME/.gnupg"
chmod 700 "$HOME/.gnupg"
grep -q "pinentry-mode loopback" "$HOME/.gnupg/gpg.conf" 2>/dev/null || echo "pinentry-mode loopback" >> "$HOME/.gnupg/gpg.conf"
grep -q "allow-loopback-pinentry" "$HOME/.gnupg/gpg-agent.conf" 2>/dev/null || echo "allow-loopback-pinentry" >> "$HOME/.gnupg/gpg-agent.conf"
gpgconf --kill gpg-agent

# --- PGP key from 1Password ---
# Requires: op signin, 1Password app unlocked with CLI integration enabled
echo "==> Importing PGP key from 1Password..."
PGP_RECOVERY_CODE=$(op item get "PGP Key" --fields recovery_code)
op document get "PGP Key File" | \
  gpg --batch --passphrase "$PGP_RECOVERY_CODE" --pinentry-mode loopback --decrypt 2>/dev/null | \
  gpg --import

# Git config is handled by .gitconfig symlink (includes signing key + commit.gpgsign)

# --- SSH key ---
if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
  echo "==> Generating SSH key..."
  ssh-keygen -t ed25519 -C "christian.nuss@gmail.com" -f "$HOME/.ssh/id_ed25519" -N ""
fi
ssh-keyscan github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null

# --- GitHub CLI ---
echo "==> Authenticating with GitHub..."
if ! gh auth status &>/dev/null; then
  gh auth login --web --git-protocol ssh
  gh auth refresh -h github.com -s admin:public_key,write:gpg_key
fi
gh ssh-key add "$HOME/.ssh/id_ed25519.pub" --title "$(hostname) $(date +%Y-%m-%d)" 2>/dev/null || true
gpg --armor --export christian.nuss@gmail.com | gh gpg-key add - 2>/dev/null || true

# --- Tailscale ---
# Install from App Store: https://apps.apple.com/us/app/tailscale/id1475387142
# Then: open Tailscale app and sign in

# --- Claude Code ---
if ! command -v claude &>/dev/null; then
  echo "==> Installing Claude Code..."
  curl -fsSL https://cli.claude.ai/install.sh | sh
fi

echo "==> Setup complete!"
