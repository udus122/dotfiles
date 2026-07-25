#!/usr/bin/env bash
# PostToolUse フック — 知識ベースのどの概念が参照されたかを記録する。
#
# 参照されない概念は失効している可能性が高い。月次がその判断に使う。
#
# 対象のルートは非公開層から読む。このスクリプト自体にはパスを書かない
# （このファイルは公開リポジトリに入るため）。層が無ければ何もしない。
# フックはセッションの応答をブロックしうるので、処理は jq 1回で終える。

set -uo pipefail

OPS="${CLAUDE_OPS_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/claude-ops}"
config="$OPS/config.json"
[ -r "$config" ] || exit 0

out="$OPS/metrics/knowledge-refs.jsonl"
mkdir -p "$OPS/metrics" 2>/dev/null || exit 0

jq -c \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg home "$HOME" \
  --slurpfile config "$config" '
  ($config[0].knowledge_root // "") as $raw
  | (if   $raw == "~"            then $home
     elif ($raw | startswith("~/")) then $home + "/" + $raw[2:]
     else $raw end) as $root
  | select($root != "")
  | (.tool_input.file_path // .tool_input.path // "") as $path
  | select($path | startswith($root))
  | {
      ts: $ts,
      session_id,
      cwd,
      tool: .tool_name,
      path: ($path | ltrimstr($root) | ltrimstr("/"))
    }
' 2>/dev/null >> "$out"

exit 0
