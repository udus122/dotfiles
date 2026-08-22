#!/usr/bin/env bash
# 利用実績を追記形式で記録する。あとから SQL で集計できるよう JSONL に揃える。
#
# 1行は PIPE_BUF (4096B) 未満に収まる想定で、追記は O_APPEND の単一 write に
# 任せる。ロックを取らないのは、この関数がフックから呼ばれるため
# （フックはセッションの応答をブロックしうるので軽さを優先する）。
#
#   metrics.sh append <stream> <<< '{"k":"v"}'   標準入力の JSON を1行追記
#   metrics.sh path   <stream>                   JSONL のパスを出す
set -uo pipefail
. "$(dirname "$0")/ops-env.sh"

cmd="${1:?usage: metrics.sh <append|path> <stream>}"
stream="${2:?stream required}"

case "$stream" in
  instructions|knowledge-refs|skills|issues) : ;;
  *) echo "unknown stream: $stream" >&2; exit 2 ;;
esac

ops_ready || exit 0
file="$CLAUDE_OPS_HOME/metrics/$stream.jsonl"

case "$cmd" in
  path)
    printf '%s\n' "$file"
    ;;
  append)
    mkdir -p "$CLAUDE_OPS_HOME/metrics"
    # 壊れた JSON を混ぜない。1行に潰してから追記する。
    line=$(jq -c '.' 2>/dev/null) || exit 0
    [ -n "$line" ] || exit 0
    printf '%s\n' "$line" >> "$file"
    ;;
  *)
    echo "unknown subcommand: $cmd" >&2
    exit 2
    ;;
esac
