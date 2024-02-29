#!/usr/bin/env bash
set -euo pipefail

set -v  # verbose mode(入力されたコマンドをそのままエコー出力)

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

if [[ "$OSTYPE" == "darwin"* ]]; then
  # MacOS向けのコマンド
  echo "Running on MacOS"
  # Disable Character Picker in VSCode for Smooth cursor movement in VSCode Neovim.
  defaults write com.microsoft.VSCode ApplePressAndHoldEnabled -bool false
elif [[ "$OSTYPE" == "linux"* ]]; then
  # Linux向けのコマンド
  echo "Running on Linux"
fi

# git configの設定
# userなどは環境固有の設定にしたいためあえて設定しない
git config --global --unset-all include.path >/dev/null 2>&1  # include.pathを一度リセット
# aliasを追加する
git config --global --add include.path "$XDG_CONFIG_HOME/git/alias"
# deltaの設定を追加する
git config --global --add include.path "$XDG_CONFIG_HOME/delta/config"
# rebase時に自動的にautosquashモードにする
git config --global --replace-all rebase.autosquash true
