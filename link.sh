#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

function make_link () {
    src=$1
    dst=$2
    # $dst がシンボリックリンクでない場合は終了
    if [[ -e $dst && ! -L $dst ]]; then
        echo "$dst is not a symbolic link"
        return 1
    fi

    ln -fnsv $src $dst
}

find "${SCRIPT_DIR}" -type f -path '*/.*' | while read dotfile; do
    [[ "$dotfile" == "${SCRIPT_DIR}/.git"* ]] && continue
    [[ "$dotfile" == "${SCRIPT_DIR}/.github"* ]] && continue
    [[ "$dotfile" == "${SCRIPT_DIR}/.DS_Store" ]] && continue
    
    make_link "$dotfile" ${HOME}/${dotfile#$SCRIPT_DIR/}
done
