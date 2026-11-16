#!/bin/bash
# レビュー用サブエージェントが終わったら、その結果をレビュー記録として残す。
#
# レビューを実行すれば記録が残るので、記録のために別のコマンドを打つ必要がない。
# claude-review-gate で手打ちする経路は塞がない (--skip と、別セッションで
# /code-review を打つ場合に要る)。記録の形式と置き場所は claude-review-gate に任せる。
#
# フックの失敗でサブエージェントを止めない。記録できない状況では黙って抜ける。
set -uo pipefail
input=$(cat)

agent=$(printf '%s' "$input" | jq -r '.agent_type // empty')
# matcher の正規表現はアンカーされないので、ここで完全一致を見る
case "$agent" in
  code-reviewer|security-reviewer) ;;
  *) exit 0 ;;
esac

gate=$(command -v claude-review-gate 2>/dev/null || echo "")
if [ -z "$gate" ] && [ -x "$HOME/.local/bin/claude-review-gate" ]; then
  gate="$HOME/.local/bin/claude-review-gate"
fi
[ -n "$gate" ] || exit 0

cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
transcript=$(printf '%s' "$input" | jq -r '.agent_transcript_path // empty')
[ -f "$transcript" ] || transcript=""

# レビュー対象の git 作業ツリーを決める。フック入力の cwd はメインセッションの
# 作業ディレクトリで、レビュー対象とは限らない (~/ws から worktree を渡す使い方)。
# 呼び出し側はプロンプトにリポジトリのパスを書くので、そこに出てくるパスの
# トップレベルが1つに決まるならそれを使い、決まらなければ cwd に戻す。
toplevel_of() {  # toplevel_of <path>  存在する祖先から git のトップレベルを引く
  local p="$1"
  case "$p" in "~"*) p="$HOME${p#\~}" ;; esac
  while [ -n "$p" ] && [ "$p" != "/" ] && [ ! -d "$p" ]; do
    p=$(dirname "$p")
  done
  [ -d "$p" ] && [ "$p" != "/" ] || return 1
  git -C "$p" rev-parse --show-toplevel 2>/dev/null
}

target=""
if [ -n "$transcript" ]; then
  # 起動時のプロンプト (最初のユーザーメッセージ) だけを見る。ツールの結果に出る
  # パスまで拾うと、レビュー中に覗いた別リポジトリで対象が決まらなくなる。
  prompt=$(jq -rs '[.[] | select(.type == "user") | .message.content
      | if type == "string" then . else (map(select(.type == "text") | .text) | join("\n")) end
      | select(. != "")] | first // empty' "$transcript" 2>/dev/null)
  # 日本語の括弧や句読点でパスが終わるよう、ASCII の文字だけを拾う
  tops=$(printf '%s\n' "$prompt" \
    | LC_ALL=C grep -oE '(~|/)[A-Za-z0-9._~@+/-]*/[A-Za-z0-9._~@+/-]*' \
    | sed -E 's/[.]+$//' | sort -u \
    | while IFS= read -r p; do toplevel_of "$p" || true; done | sort -u)
  if [ -n "$tops" ] && [ "$(printf '%s\n' "$tops" | wc -l | tr -d ' ')" -eq 1 ]; then
    target="$tops"
  fi
fi
[ -n "$target" ] || target="$cwd"
[ -n "$target" ] || exit 0

# 先に記録があれば上書きしない。2体を続けて回したとき、後の1体で
# 前の指摘が消えないようにする。
if "$gate" check --dir "$target" >/dev/null 2>&1; then
  exit 0
fi

# 報告は last_assistant_message に載らないことがある (SubagentHandback ツールで
# 返す場合)。そのときは transcript から最後の報告を取る。
message=$(printf '%s' "$input" | jq -r '.last_assistant_message // empty')
if [ -z "$message" ] && [ -n "$transcript" ]; then
  message=$(jq -rs '[.[] | select(.type == "assistant") | .message.content[]?
      | if .type == "tool_use" and .name == "SubagentHandback" then .input.message
        elif .type == "text" then .text else empty end
      | select(. != null and . != "")] | last // empty' "$transcript" 2>/dev/null)
fi
[ -n "$message" ] || exit 0

# 記録が肥大化しないよう頭だけ残す。バイトではなく行で切る（マルチバイトの分断を避ける）
{
  printf '%s のレビュー結果\n\n' "$agent"
  printf '%s\n' "$message" | head -n 80
} | "$gate" record --dir "$target" >/dev/null 2>&1 || exit 0

exit 0
