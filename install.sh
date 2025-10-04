#!/usr/bin/env bash
set -euo pipefail

script_dir="$(dirname "$0")"

brew update
brew bundle install --upgrade --global --cleanup

( # Install krew
  cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" &&
  ./"${KREW}" install krew
)

kubectl krew install < "$script_dir/krew.txt"

# install tools via mise
(cd "${XDG_CONFIG_HOME}/mise" && mise install)

# Native Install Claude Code
curl -fsSL https://claude.ai/install.sh | bash
