#!/bin/bash
# レビュー用サブエージェントが終わったら、その結果をレビュー記録として残す。
#
# 記録を手で作れると、レビューを実行しないまま PR 作成を通せる。レビューエージェントの
# 終了を記録の条件にすることで、その経路を塞ぐ。記録の形式と置き場所は
# claude-review-gate に任せる。
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
[ -n "$cwd" ] || exit 0

# 先に記録があれば上書きしない。2体を続けて回したとき、後の1体で
# 前の指摘が消えないようにする。
if "$gate" check --dir "$cwd" >/dev/null 2>&1; then
  exit 0
fi

message=$(printf '%s' "$input" | jq -r '.last_assistant_message // empty')
[ -n "$message" ] || exit 0

# 記録が肥大化しないよう頭だけ残す。バイトではなく行で切る（マルチバイトの分断を避ける）
{
  printf '%s のレビュー結果\n\n' "$agent"
  printf '%s\n' "$message" | head -n 80
} | "$gate" record --dir "$cwd" >/dev/null 2>&1 || exit 0

exit 0
