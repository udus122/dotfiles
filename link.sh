#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKIPPED="$(mktemp)"
IGNORED="$(mktemp)"
MISSING="$(mktemp)"
trap 'rm -f "$SKIPPED" "$IGNORED" "$MISSING"' EXIT

# --check: リンクを作らず、まだ $HOME に配られていないものを列挙して終わる。
# 配る条件をこのスクリプトの外に写すと、判定だけが古びて嘘をつくため、
# 検出も同じ walk の上に載せる。
MODE=link
[[ "${1:-}" == "--check" ]] && MODE=check

# git が無視しているファイルは $HOME に配らない。
# このリポジトリには追跡しないローカル専用の設定が置かれることがあり、
# それを配ると管理外のファイルが $HOME に増えてしまう。
(cd "$SCRIPT_DIR" && git ls-files --others --ignored --exclude-standard) > "$IGNORED" 2>/dev/null || true

function make_link () {
    src=$1
    dst=$2

    # $dst がシンボリックリンクでなく存在する場合はスキップ
    # （スキップされたファイルはこのリポジトリの管理から外れて内容が乖離するため、
    #   最後にまとめて警告する）
    if [[ -e $dst && ! -L $dst ]]; then
        [[ $MODE == check ]] && return 0
        echo "$dst already exists and is not a symbolic link. Skipping..."
        echo "$dst" >> "$SKIPPED"
        return 0
    fi

    # 実体を伴わないものだけを未作成として数える。実体があって
    # リンクでないものは上で除いてあり、人間が承知の上で置いている。
    if [[ $MODE == check ]]; then
        [[ -e $dst || -L $dst ]] || echo "$dst" >> "$MISSING"
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

find "${SCRIPT_DIR}" \( -type f -o -type l \) -path '*/.*' | while read -r dotfile; do
    [[ "$dotfile" == "${SCRIPT_DIR}/.git"* ]] && continue
    [[ "$dotfile" == "${SCRIPT_DIR}/.github"* ]] && continue
    [[ "$dotfile" == "${SCRIPT_DIR}/.DS_Store" ]] && continue
    grep -qxF "${dotfile#"$SCRIPT_DIR"/}" "$IGNORED" && continue
    # karabiner はこのあとディレクトリごとリンクするので、配下は個別に扱わない
    [[ "$dotfile" == "${SCRIPT_DIR}/.config/karabiner"* ]] && continue

    make_link "$dotfile" "${HOME}/${dotfile#"$SCRIPT_DIR"/}"
done

# Karabiner-Elements はディレクトリごとシンボリックリンクを作成する（個別に作成すると上書きされる）
# https://karabiner-elements.pqrs.org/docs/manual/misc/configuration-file-path/
if [[ $MODE == check ]]; then
    [[ -e "$HOME/.config/karabiner" || -L "$HOME/.config/karabiner" ]] \
        || echo "$HOME/.config/karabiner" >> "$MISSING"
else
    ln -fns "${SCRIPT_DIR}/.config/karabiner" "$HOME/.config/karabiner"
fi

if [[ $MODE == check ]]; then
    [[ -s "$MISSING" ]] || exit 0
    cat "$MISSING"
    exit 1
fi

if [[ -s "$SKIPPED" ]]; then
    echo
    echo "警告: 次のファイルは実体が存在するためリンクしませんでした。"
    echo "      このリポジトリの管理外にあり、変更が差分として追えません。"
    sed 's/^/      /' "$SKIPPED"
fi
