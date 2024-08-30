#!/usr/bin/env bash
set -euo pipefail

# Check operating system
if [ "$(uname)" != "Darwin" ] ; then
  echo "Not macOS!"
  exit 1
fi

brew bundle --global
