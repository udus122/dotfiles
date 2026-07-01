#!/bin/bash
set -euo pipefail
input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // empty')

# git push でなければ素通り
[[ "$cmd" =~ ^[[:space:]]*git[[:space:]]+push([[:space:]]|$) ]] || exit 0

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

# force push の検出 (--force / -f / --force-with-lease / 複合短縮 -fu, -uf, -fn など)
if [[ "$cmd" =~ (^|[[:space:]])(--force(-with-lease)?|-[a-zA-Z]*f[a-zA-Z]*)([[:space:]=]|$) ]]; then
  deny "force push は禁止"
fi

# refspec の + プレフィックス (例: +HEAD:main, +refs/heads/main) も force push 扱い
if [[ "$cmd" =~ (^|[[:space:]])\+[A-Za-z0-9/_.-]+ ]]; then
  deny "force push refspec (+) は禁止"
fi

# 個人ナレッジベース (~/knowledge) は main 直 push を許可 (force push 禁止は上で判定済み)
# git -C <path> push にも対応するため、-C 指定があればそのパスで判定する
push_dir=$(echo "$cmd" | sed -nE 's/^.*-C[[:space:]]+([^[:space:]]+).*$/\1/p')
push_dir="${push_dir/#\~/$HOME}"
toplevel=$(git -C "${push_dir:-.}" rev-parse --show-toplevel 2>/dev/null || echo "")
if [[ "$toplevel" == "$HOME/knowledge" ]]; then
  exit 0
fi

# 明示的に main/master を引数で指定しているケース
# git push origin main / git push origin HEAD:main / git push origin refs/heads/main など
if [[ "$cmd" =~ (^|[[:space:]:/])(main|master)([[:space:]:]|$) ]]; then
  deny "main/master への push は禁止"
fi

# 暗黙の main/master push: git push / git push origin / git push -u origin のように
# branch 引数を省略しているケース。現在ブランチを見て判定する。
rest=$(echo "$cmd" | sed -E 's/^[[:space:]]*git[[:space:]]+push[[:space:]]*//')
non_flag_args=$(echo "$rest" | tr ' ' '\n' | grep -Ev '^(-|$)' || true)
arg_count=$(echo -n "$non_flag_args" | grep -c '^' || true)
if [ "$arg_count" -le 1 ]; then
  branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
  if [[ "$branch" == "main" || "$branch" == "master" ]]; then
    deny "現在ブランチが $branch のため暗黙の main/master push を禁止"
  fi
fi

exit 0
