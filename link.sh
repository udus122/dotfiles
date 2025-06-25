#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

function make_link () {
    src=$1
    dst=$2

    # $dst がシンボリックリンクでなく存在する場合はスキップ
    if [[ -e $dst && ! -L $dst ]]; then
        echo "$dst already exists and is not a symbolic link. Skipping..."
        return 0
    fi
    # ディレクトリが存在しない場合は作成
    dirpath=$(dirname "$dst")
    [[ ! -d "$dirpath" ]] && mkdir -p "$dirpath"

    ln -fnsv "$src" "$dst"
    
    # If the destination is under "$HOME/.local/bin", add execution permission
    if [[ "$dst" == "$HOME/.local/bin"* ]]; then
        chmod +x "$dst"
    fi
}

find "${SCRIPT_DIR}" -type f -path '*/.*' | while read -r dotfile; do
    [[ "$dotfile" == "${SCRIPT_DIR}/.git"* ]] && continue
    [[ "$dotfile" == "${SCRIPT_DIR}/.github"* ]] && continue
    [[ "$dotfile" == "${SCRIPT_DIR}/.DS_Store" ]] && continue

    make_link "$dotfile" "${HOME}/${dotfile#"$SCRIPT_DIR"/}"
done
