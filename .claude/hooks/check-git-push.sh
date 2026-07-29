#!/bin/bash
# force push と既定ブランチへの直 push を止める。
#
# 判定はコマンド文字列全体ではなく、実際に実行される単位に対して行う。
# 全体を見ると、禁止対象の語が「実行される部分」以外に現れただけで拒否され、
# 正当な操作がブロックされる。例:
#
#   git push -u origin feat/x && gh pr create --base main
#     -> main は PR のベース指定であって push の引数ではない
#   gh issue create --body "$(cat <<'EOF' ... EOF)"
#     -> ヒアドキュメント本体はシェルが実行しないデータ
#
# そこで前処理でヒアドキュメント本体を落とし、複合コマンドを実行単位に割り、
# git push を実行する単位だけを、その引数に限って検査する。
set -euo pipefail
input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // empty')
[ -n "$cmd" ] || exit 0

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# ヒアドキュメント本体を落とす。
# 本体はシェルが解釈しないデータなので、そこに現れた語で判定すると誤検知になる。
# ただし本体をシェル自身に食わせている場合 (bash <<'EOF') は中身が実行されるため残す。
# 引用符は awk の正規表現内で扱いにくいので 8 進表記で書く (\047=' \042=")。
strip_heredocs() {
  awk '
    {
      if (skip) {
        line = $0
        sub(/^[[:space:]]+/, "", line)
        if (line == term) skip = 0
        next
      }
      if (match($0, /<<-?[[:space:]]*[\047\042]?[A-Za-z_][A-Za-z0-9_]*[\047\042]?/)) {
        tok = substr($0, RSTART, RLENGTH)
        sub(/^<<-?[[:space:]]*/, "", tok)
        gsub(/[\047\042]/, "", tok)
        if ($0 !~ /(^|[|&;[:space:](])(bash|sh|zsh|ksh|dash)([[:space:]]|$)/) {
          term = tok
          skip = 1
        }
      }
      print
    }
  '
}

# 複合コマンドを実行単位に割る。&& || ; | と改行が区切り。
# git push はこれらを引数に取らないので、割りすぎて push を見落とすことはない。
split_segments() {
  sed -E 's/(&&|\|\||;|\|)/\
/g'
}

segments=$(printf '%s\n' "$cmd" | strip_heredocs | split_segments)

# cd したディレクトリを覚える (cd x && git push)。git -C があればそちらを優先する。
cd_dir=""

while IFS= read -r seg; do
  if [[ "$seg" =~ ^[[:space:]]*cd[[:space:]]+([^[:space:]]+) ]]; then
    cd_dir="${BASH_REMATCH[1]}"
    continue
  fi

  # この単位が git push を実行しないなら見ない
  [[ "$seg" =~ (^|[[:space:]])git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?push([[:space:]]|$) ]] || continue

  # push の引数だけを取り出す。以降の判定はこれに対して行う。
  args=$(printf '%s' "$seg" \
    | sed -E 's/.*git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?push//')

  # force push の検出 (--force / -f / --force-with-lease / 複合短縮 -fu, -uf, -fn など)
  if [[ "$args" =~ (^|[[:space:]])(--force(-with-lease)?|-[a-zA-Z]*f[a-zA-Z]*)([[:space:]=]|$) ]]; then
    deny "force push は禁止"
  fi

  # refspec の + プレフィックス (例: +HEAD:main, +refs/heads/main) も force push 扱い
  if [[ "$args" =~ (^|[[:space:]])\+[A-Za-z0-9/_.-]+ ]]; then
    deny "force push refspec (+) は禁止"
  fi

  # push が実行されるディレクトリ
  push_dir=$(printf '%s' "$seg" | sed -nE 's/.*git[[:space:]]+-C[[:space:]]+([^[:space:]]+).*/\1/p')
  [ -n "$push_dir" ] || push_dir="$cd_dir"
  push_dir="${push_dir/#\~/$HOME}"

  # 個人リポジトリ (~/knowledge, ~/dotfiles) は main 直 push を許可
  # (force push 禁止は上で判定済み)
  toplevel=$(git -C "${push_dir:-.}" rev-parse --show-toplevel 2>/dev/null || echo "")
  case "$toplevel" in
    "$HOME/knowledge"|"$HOME/dotfiles") continue ;;
  esac

  # 明示的に main/master を引数で指定しているケース
  # git push origin main / git push origin HEAD:main / git push origin refs/heads/main など
  if [[ "$args" =~ (^|[[:space:]:/])(main|master)([[:space:]:]|$) ]]; then
    deny "main/master への push は禁止"
  fi

  # 暗黙の main/master push: git push / git push origin / git push -u origin のように
  # branch 引数を省略しているケース。現在ブランチを見て判定する。
  non_flag_args=$(printf '%s\n' "$args" | tr ' ' '\n' | grep -Ev '^(-|$)' || true)
  arg_count=$(printf '%s' "$non_flag_args" | grep -c '^' || true)
  if [ "$arg_count" -le 1 ]; then
    branch=$(git -C "${push_dir:-.}" symbolic-ref --short HEAD 2>/dev/null || echo "")
    if [[ "$branch" == "main" || "$branch" == "master" ]]; then
      deny "現在ブランチが $branch のため暗黙の main/master push を禁止"
    fi
  fi
done <<< "$segments"

exit 0
