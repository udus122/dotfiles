#!/usr/bin/env bash
set -euo pipefail

script_dir="$(dirname "$0")"

# Check operating system
if [ "$(uname)" != "Darwin" ] ; then
  echo "Not macOS!"
  exit 1
fi

brew bundle --global

krew install < "$script_dir/krew.txt"
