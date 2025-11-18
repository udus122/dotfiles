#!/usr/bin/env bash
set -euo pipefail

if ! type brew >/dev/null 2>&1; then
  # Install brew if not installed
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [ "$(uname -m)" = "arm64" ]; then
    # ARM版Mac(M*)用
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    # Intel版Mac用
    eval "$(/usr/local/bin/brew shellenv)"
  fi
else
  echo "Homebrew is already installed."
fi

# Install xcode
# Check if command line tools are installed
if ! xcode-select --print-path >/dev/null 2>&1; then
  # Install command line tools
  echo "Command line tools not found. Installing..."
  xcode-select --install
else
  echo "Command line tools are already installed."
fi

# Disable Character Picker in VSCode, Obsidian for Smooth cursor movement in VSCode Neovim.
defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false
defaults write md.obsidian ApplePressAndHoldEnabled -bool false
echo "install Rosetta 2"
sudo softwareupdate --install-rosetta

# AppleShowAllFilesを有効化
defaults write com.apple.finder AppleShowAllFiles -bool true

# git configの設定
# グローバルで設定されたGitのユーザー名が存在しなければ、ユーザーに名前を尋ねて設定する
if [ -z "$(git config --global --get user.name)" ]; then
  echo "Git username is not set. Please enter your username: "
  read -r user_name
  git config --global user.name "$user_name"
  echo "Git username has been set to: $user_name"
else
  echo "Git username is already set. Skipping..."
fi
# グローバルで設定されたGitのメールアドレスが存在しなければ、ユーザーにメールアドレスを尋ねて設定する
if [ -z "$(git config --global --get user.email)" ]; then
  echo "Git email is not set. Please enter your email: "
  read -r user_email
  git config --global user.email "$user_email"
  echo "Git email has been set to: $user_email"
else
  echo "Git email is already set. Skipping..."
fi
echo "Configuring Git includes..."
git config --global -az-unset-all include.path >/dev/null 2>&1  # include.pathを一度リセット
echo "Adding common Git configuration..."
git config --global --add include.path "$XDG_CONFIG_HOME/git/common"
echo "Adding alias Git configuration..."
git config --global --add include.path "$XDG_CONFIG_HOME/git/alias"
echo "Adding delta Git configuration..."
git config --global --add include.path "$XDG_CONFIG_HOME/delta/config"
