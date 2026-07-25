#!/usr/bin/env bash
# InstructionsLoaded フック — どの CLAUDE.md / ルールが実際に読み込まれたかを記録する。
#
# これはフック経由でしか取れない情報で、月次の設定棚卸し（一度も読まれていない
# ルールを削除候補に出す）の根拠になる。
#
# 記録先は非公開層。層が無ければ何もしない。
# フックはセッションの応答をブロックしうるので、処理は jq 1回で終える。

set -uo pipefail

OPS="${CLAUDE_OPS_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/claude-ops}"
[ -r "$OPS/config.json" ] || exit 0

out="$OPS/metrics/instructions.jsonl"
mkdir -p "$OPS/metrics" 2>/dev/null || exit 0

jq -c --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{
  ts: $ts,
  session_id,
  cwd,
  file_path,
  memory_type,
  load_reason,
  trigger_file_path,
  parent_file_path
}' 2>/dev/null >> "$out"

exit 0
