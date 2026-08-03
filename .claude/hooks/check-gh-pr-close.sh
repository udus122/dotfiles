#!/bin/bash
set -euo pipefail
input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // empty')

# gh pr close を含まなければ素通り
# 複合コマンド (cd x && gh pr close 1) もここで捕捉する
[[ "$cmd" =~ gh[[:space:]]+pr[[:space:]]+close([[:space:]]|$) ]] || exit 0

# 自分がオーナーの組織。一覧は非公開層が持つ（このリポジトリは公開されているため）。
# 読めないときや空のときは、全部拒否する側に倒す。
ops_config="${CLAUDE_OPS_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/claude-ops}/config.json"
allowed_owners=$(jq -r '.issue_owners_allow // [] | .[]' "$ops_config" 2>/dev/null || true)

decide() {
  jq -n --arg d "$1" --arg reason "$2" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: $d,
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# 1) --repo / -R owner/repo の明示指定を優先する
owner=$(echo "$cmd" | sed -nE 's/^.*[[:space:]](-R|--repo)[[:space:]]+([^[:space:]\/]+)\/[^[:space:]]+.*$/\2/p')

# 2) 省略時は実行ディレクトリの origin から判定する
if [ -z "$owner" ]; then
  work_dir=$(echo "$cmd" | sed -nE 's/^[[:space:]]*cd[[:space:]]+([^[:space:];&|]+).*$/\1/p')
  work_dir="${work_dir/#\~/$HOME}"
  if [ -z "$work_dir" ]; then
    work_dir=$(echo "$input" | jq -r '.cwd // empty')
  fi
  url=$(git -C "${work_dir:-.}" remote get-url origin 2>/dev/null || echo "")
  owner=$(echo "$url" | sed -nE 's#^(https?://[^/]+/|git@[^:]+:|ssh://git@[^/]+/)([^/]+)/.*$#\2#p')
fi

[ -n "$owner" ] || decide deny "gh pr close: リポジトリのオーナーを判定できないため拒否"

[ -n "$allowed_owners" ] \
  || decide deny "gh pr close: 許可オーナーの一覧を読めないため拒否 (owner: $owner)"

if printf '%s\n' "$allowed_owners" | grep -qxF "$owner"; then
  decide allow "$owner は自分がオーナーの組織のため gh pr close を許可"
fi

decide deny "gh pr close は自分がオーナーの組織以外では禁止 (owner: $owner)"
