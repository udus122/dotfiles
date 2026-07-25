#!/usr/bin/env bash
# セッション記録を、読める大きさに絞って取り出す。
#
# 一次入力は ~/.claude/history.jsonl（1行 = ユーザ発話1件、project 付き）。
# 生のトランスクリプトは1本が数 MB あるため全読みはせず、
# history で当たりを付けたセッションだけ部分抽出する。
#
#   sessions.sh prompts <workspace> [since_epoch_ms]   ユーザ発話 (JSONL)
#   sessions.sh ids     <workspace> [since_epoch_ms]   セッション ID
#   sessions.sh replies <session_id> [max_chars]       そのセッションの応答テキスト
#   sessions.sh since   <state_key> [default_days]     前回実行時刻(ms)を state から読む
#   sessions.sh mark    <state_key> <epoch_ms>         今回の実行時刻を state に書く
set -uo pipefail
. "$(dirname "$0")/ops-env.sh"
ops_ready || exit 0
ops_dirs

HISTORY="$HOME/.claude/history.jsonl"
PROJECTS="$HOME/.claude/projects"

cmd="${1:?usage: sessions.sh <prompts|ids|replies|since|mark> ...}"
shift

case "$cmd" in
  prompts|ids)
    workspace=$(cd "${1:?workspace required}" && pwd -P)
    since="${2:-0}"
    [ -r "$HISTORY" ] || exit 0
    out=$(jq -c --arg ws "$workspace" --argjson since "$since" '
      select(.project != null)
      | select(.project == $ws or (.project | startswith($ws + "/")))
      | select((.timestamp // 0) >= $since)
      | {ts: .timestamp, sessionId: (.sessionId // null), prompt: .display}
    ' "$HISTORY" 2>/dev/null)
    if [ "$cmd" = "ids" ]; then
      printf '%s\n' "$out" | jq -r 'select(.sessionId != null) | .sessionId' | sort -u
    else
      printf '%s\n' "$out"
    fi
    ;;

  replies)
    session="${1:?session id required}"
    max="${2:-4000}"
    file=$(find "$PROJECTS" -name "$session.jsonl" -type f 2>/dev/null | head -1)
    [ -n "$file" ] || exit 0
    # ツール結果は落とし、人間が書いた発話とアシスタントの地の文だけを残す
    jq -r '
      if .type == "user" and (.message.content | type) == "string"
        then "USER: " + .message.content
      elif .type == "user" and (.message.content | type) == "array"
        then ([.message.content[] | select(.type == "text") | .text] | join("\n"))
             | select(length > 0) | "USER: " + .
      elif .type == "assistant"
        then ([.message.content[]? | select(.type == "text") | .text] | join("\n"))
             | select(length > 0) | "ASSISTANT: " + .
      else empty end
    ' "$file" 2>/dev/null | cut -c1-"$max"
    ;;

  since)
    key="${1:?state key required}"
    default_days="${2:-1}"
    state="$CLAUDE_OPS_HOME/state/$key.json"
    value=""
    [ -r "$state" ] && value=$(jq -r '.last_run_ms // empty' "$state" 2>/dev/null)
    if [ -n "$value" ]; then
      printf '%s' "$value"
    else
      # 初回は既定日数ぶんさかのぼる
      printf '%s' "$(( ($(date +%s) - default_days * 86400) * 1000 ))"
    fi
    ;;

  mark)
    key="${1:?state key required}"
    at="${2:?epoch ms required}"
    state="$CLAUDE_OPS_HOME/state/$key.json"
    [ -r "$state" ] || printf '{}\n' > "$state"
    jq --argjson ms "$at" '.last_run_ms = $ms' "$state" > "$state.tmp" \
      && mv "$state.tmp" "$state"
    ;;

  *)
    echo "unknown subcommand: $cmd" >&2
    exit 2
    ;;
esac
