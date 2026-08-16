#!/usr/bin/env bash
# link.sh の配布集合を、代表的な置き場とファイルの表で点検する。
#
# link.sh はこのリポジトリの内容を $HOME に配る唯一の経路で、スキル・フック・
# エージェント定義はすべてここを通って稼働する側に届く。選別が壊れても
# link.sh 自身は正常に終わるため、配られ過ぎ・配られなさに気付く手段がここしかない。
#
# 除外のうち一部は欠陥ではなく仕様として選ばれている。`.git` の前方一致に
# ディレクトリ境界を付けない（結果として `.gitignore` を配らない）のは
# PR #43 で「今のままで正しい」と判断されたもので、リポジトリ側には
# その判断が残っていない。ここで固定して、次に読む者が指摘を繰り返さないようにする。
#
#   tools/test-link-selection.sh
set -uo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd -P)
LINK_SH="$REPO/link.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0

# git は $HOME だけでなく XDG_CONFIG_HOME からも無視設定を読む。手元の環境には
# `*.local*` のような広いパターンを置いた個人のグローバル ignore があり、
# $HOME を差し替えただけでは効いたままになる。そのままだと同じ入力でも
# 手元と CI で配布集合が変わり、テストが環境を測ってしまう。
# 設定源をすべて一時ディレクトリへ向けて、判定を再現可能にする。
isolated() {  # isolated <home> <command...>
  local home=$1
  shift
  HOME="$home" XDG_CONFIG_HOME="$home/.config" \
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
    "$@"
}

# fixture を作るときの git も同じ条件で動かす。init のテンプレートが
# グローバル設定で差し替わっていると、`.git/info/exclude` が混ざる。
ISO="$tmp/iso"
mkdir -p "$ISO/.config"

# 配布対象の複製を作る。実際のリポジトリの内容には依存させない。
# 依存させると、ファイルが増えるたびに期待値が動いて、選別の退行と
# 単なる追加を区別できなくなる。
build_fixture() {  # build_fixture <dir>
  local d=$1
  mkdir -p "$d"
  cp "$LINK_SH" "$d/link.sh"

  # 配られるもの
  printf 'export EDITOR=vim\n'  > "$d/.zshrc"
  mkdir -p "$d/.config/nvim"
  printf 'vim.o.number = true\n' > "$d/.config/nvim/init.lua"
  mkdir -p "$d/.local/bin"
  printf '#!/bin/sh\n'          > "$d/.local/bin/mytool"

  # 実際に配られている中身の代表を1つずつ置く。一般の選別だけを試すと、
  # 特定の木だけを外す規則（例: `*/skills/*` を飛ばす）が素通りし、
  # このテストが守るはずのスキルとフックが黙って配られなくなる。
  mkdir -p "$d/.claude/skills/example"
  printf -- '---\nname: example\n---\n' > "$d/.claude/skills/example/SKILL.md"
  mkdir -p "$d/.agents/hooks"
  printf '#!/bin/sh\n'          > "$d/.agents/hooks/guard.sh"

  # karabiner はディレクトリごと1本で配るので、配下は個別に配られない
  mkdir -p "$d/.config/karabiner"
  printf '{}\n'                 > "$d/.config/karabiner/karabiner.json"

  # 配られないもの
  printf '# readme\n'           > "$d/README.md"
  mkdir -p "$d/tools"
  printf '#!/bin/sh\n'          > "$d/tools/helper.sh"
  mkdir -p "$d/.github/workflows"
  printf 'name: ci\n'           > "$d/.github/workflows/ci.yml"
  printf '.env.local\n'         > "$d/.gitignore"
  printf '[submodule "x"]\n'    > "$d/.gitmodules"
  printf ''                     > "$d/.DS_Store"
  printf 'SECRET=1\n'           > "$d/.env.local"

  # git が無視しているものを配らない経路は、実際の git リポジトリでしか働かない
  isolated "$ISO" git -C "$d" init -q 2>/dev/null
}

# --check は $HOME にまだ無いものを列挙する。$HOME を空にすれば
# 列挙されるものが配布集合そのものになる。リンクは作らないので副作用は無い。
distribution_of() {  # distribution_of <fixture dir>
  local d=$1 home
  home=$(mktemp -d "$tmp/home.XXXXXX")
  isolated "$home" bash "$d/link.sh" --check 2>/dev/null \
    | sed "s|^${home}/||" | sort
}

check_set() {  # check_set <説明> <fixture dir>   期待する集合は標準入力
  local desc=$1 d=$2 want got
  want=$(sort)
  got=$(distribution_of "$d")
  if [ "$got" = "$want" ]; then
    pass=$((pass + 1))
  else
    printf 'NG   %s\n' "$desc"
    printf '%s\n' "--- 期待"; printf '%s\n' "$want"
    printf '%s\n' "--- 実際"; printf '%s\n' "$got"
    fail=$((fail + 1))
  fi
}

# ------------------------------------------------------------ 配布集合の不変性

# `.config/karabiner` はディレクトリごと1本として、走査とは別に必ず配られる。
plain="$tmp/plain/wt"
build_fixture "$plain"
check_set "配布集合が期待どおりの集合になる" "$plain" <<'EOF'
.agents/hooks/guard.sh
.claude/skills/example/SKILL.md
.config/karabiner
.config/nvim/init.lua
.local/bin/mytool
.zshrc
EOF

# ------------------------------------------------------- 置き場が判定に影響しない

# find の -path はパス全体に当たるため、置き場自体にドット成分があると
# リポジトリ内の全ファイルがドットファイルとして一致しうる（PR #44 の欠陥）。
hidden="$tmp/.hidden/wt"
build_fixture "$hidden"
check_set "ドット成分を含む置き場でも配布集合が変わらない" "$hidden" <<'EOF'
.agents/hooks/guard.sh
.claude/skills/example/SKILL.md
.config/karabiner
.config/nvim/init.lua
.local/bin/mytool
.zshrc
EOF

a=$(distribution_of "$plain")
b=$(distribution_of "$hidden")
if [ "$a" = "$b" ]; then
  pass=$((pass + 1))
else
  printf 'NG   置き場の違いで配布集合が一致しない\n'
  diff <(printf '%s\n' "$a") <(printf '%s\n' "$b")
  fail=$((fail + 1))
fi

# ------------------------------------------------------- 個別の除外を名指しで固定

# 集合の比較だけだと、何が理由で外れたのかが読めない。
# 退行したときに原因へ直行できるよう、除外は1件ずつ名前で確かめる。
excluded() {  # excluded <説明> <relpath>
  local desc=$1 path=$2
  if printf '%s\n' "$a" | grep -qxF "$path"; then
    printf 'NG   %s（%s が配布対象に入っている）\n' "$desc" "$path"
    fail=$((fail + 1))
  else
    pass=$((pass + 1))
  fi
}

excluded "リポジトリ自身のメタデータは配らない"          ".gitignore"
excluded "サブモジュール定義は配らない"                  ".gitmodules"
# `.github` は link.sh に専用の行があるが、いまは手前の `.git` の前方一致が
# 先に外すため、その行を消してもここは通る。固定できるのは「配られない」という
# 結果だけで、どの行が効いているかではない。`.git` に境界を付ける変更が
# 入ったときに初めて専用の行が効き始める。
excluded "GitHub の設定は配らない"                       ".github/workflows/ci.yml"
excluded "macOS の副産物は配らない"                      ".DS_Store"
excluded "git が無視しているものは配らない"              ".env.local"
excluded "karabiner の配下は個別に配らない"              ".config/karabiner/karabiner.json"
excluded "ドットを含まないものは配らない"                "README.md"
excluded "ドットを含まないディレクトリの中身は配らない"  "tools/helper.sh"

# ------------------------------------------------------------ worktree の .git

# worktree では .git がディレクトリではなくファイルとして現れる。
# 前方一致はこれも外す。境界を付けるとここが配布対象に入る。
wt="$tmp/worktree/wt"
mkdir -p "$wt"
cp "$LINK_SH" "$wt/link.sh"
printf 'export EDITOR=vim\n' > "$wt/.zshrc"
printf 'gitdir: /elsewhere/.git/worktrees/wt\n' > "$wt/.git"
check_set "worktree の .git（ファイル）を配らない" "$wt" <<'EOF'
.config/karabiner
.zshrc
EOF

printf '\n%s 件中 %s 件が期待どおり' "$((pass + fail))" "$pass"
if [ "$fail" -gt 0 ]; then
  printf '（%s 件が不一致）\n' "$fail"
  exit 1
fi
printf '\n'
