#!/usr/bin/env bash
set -euo pipefail

# Install brew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
if [ "$(uname -m)" = "arm64" ] ; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Install xcode
# Check if command line tools are installed
if ! xcode-select --print-path &> /dev/null; then
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

