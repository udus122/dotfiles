#!/usr/bin/env bash
# PostToolUse フック — 知識ベースのどの概念が参照されたかを記録する。
#
# 参照されない概念は失効している可能性が高い。月次がその判断に使う。
#
# 対象のルートは非公開層から読む。このスクリプト自体にはパスを書かない
# （このファイルは公開リポジトリに入るため）。層が無ければ何もしない。
# フックはセッションの応答をブロックしうるので、処理は jq 1回で終える。
#
# ファイルを読むツールは `tool_input` にパスを持つが、Bash は `command` しか
# 持たない。`cat` や `head` で読んだぶんが丸ごと落ちると、記録が止まっていても
# 「参照が無い」と同じ見え方になる。Bash はコマンド文字列から `.md` を指す語を
# 拾って補う。拾う対象を `.md` に絞るのは、`sed 's/a/b/'` のようなスラッシュを
# 含む語をパスと誤認しないため。

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
  | . as $e
  | (if $e.tool_name == "Bash" then
       ($e.tool_input.command // "")
       | [ scan("[~$A-Za-z0-9_./*?-]+\\.md") ]
     else
       [ $e.tool_input.file_path // $e.tool_input.path // "" ]
     end)
  | map(select(. != ""))
  | map(
      if   startswith("~/")     then $home + "/" + .[2:]
      elif startswith("$HOME/") then $home + "/" + .[6:]
      elif startswith("/")      then .
      else ($e.cwd // "") + "/" + .
      end
    )
  | map(select(startswith($root + "/")) | ltrimstr($root + "/"))
  | map(select(. != ""))
  | unique
  | .[]
  | {
      ts: $ts,
      session_id: $e.session_id,
      cwd: $e.cwd,
      tool: $e.tool_name,
      path: .
    }
' 2>/dev/null >> "$out"

exit 0
