#!/bin/bash
set -euo pipefail
input=$(cat)
url=$(echo "$input" | jq -r '.tool_input.url // empty')
prompt=$(echo "$input" | jq -r '.tool_input.prompt // empty')

# エスケープハッチ: prompt に [allow-webfetch] を含む場合は WebFetch を素通り
# (要約で十分 / Prompt Injection 対策が欲しい / defuddle と curl が両方失敗した場合の最終退避)
if [[ "$prompt" == *"[allow-webfetch]"* ]]; then
  exit 0
fi

# defuddle が未インストールなら素通り (defuddle のないマシンを壊さない)
command -v defuddle >/dev/null 2>&1 || exit 0

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

deny "WebFetch はページ全文ではなく Haiku による要約しか返さず、長いページは無通知で切り詰められます。代わりに Bash で全文を Markdown 取得してください:

  defuddle parse \"$url\" --md

失敗時のフォールバック:
  1. ページで失敗 (SPA/ペイウォール/空応答) → curl -sL \"$url\" で生 HTML を取得 (defuddle はローカル HTML もパース可)
  2. それでも WebFetch が必要 (要約で十分 / injection 対策が欲しい) → WebFetch の prompt に [allow-webfetch] を含めて再実行するとこのフックを通過します

注意: defuddle は Prompt Injection 対策が外れ、入力トークンが増えます。"
