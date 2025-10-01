#!/usr/bin/env bash
set -euo pipefail

script_dir="$(dirname "$0")"

brew update
brew bundle install --upgrade --global --cleanup

krew install < "$script_dir/krew.txt"

# install tools via mise
(cd "${XDG_CONFIG_HOME}/mise" && mise install)
