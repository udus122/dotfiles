#!/usr/bin/env bash
# PreToolUse フック — どのスキルが実際に起動されたかを記録する。
#
# 実在するスキルのうち一度も使われていないものを、月次の設定棚卸しが
# 削除候補に出すための根拠になる。InstructionsLoaded が記録するのは
# CLAUDE.md 系の memory ファイルだけで、スキルはそこに現れない。
#
# 記録先は非公開層。層が無ければ何もしない。
# フックはセッションの応答をブロックしうるので、処理は jq 1回で終える。

set -uo pipefail

OPS="${CLAUDE_OPS_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/claude-ops}"
[ -r "$OPS/config.json" ] || exit 0

out="$OPS/metrics/skills.jsonl"
mkdir -p "$OPS/metrics" 2>/dev/null || exit 0

# 引数は記録しない。棚卸しに要るのはどのスキルが使われたかだけで、
# 引数には作業内容がそのまま入る。
jq -c --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
  (.tool_input.skill // "") as $skill
  | select($skill != "")
  | {
      ts: $ts,
      session_id,
      cwd,
      skill: $skill
    }
' 2>/dev/null >> "$out"

exit 0
