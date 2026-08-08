#!/usr/bin/env bash
# セッション記録を、読める大きさに絞って取り出す。
#
# 一次入力は ~/.claude/projects/ のトランスクリプト。1本が数 MB あるため
# 全読みはせず、mtime で期間外のファイルを落としてから jq で発話行だけを抜く。
#
# 以前は ~/.claude/history.jsonl を一次入力にしていたが、更新が止まっても
# 「その期間に発話が無かった」と区別が付かず、日次が無言で空回りした。
# トランスクリプトは cwd と timestamp を持つので、同じ絞り込みが単独で成立する。
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

PROJECTS="$HOME/.claude/projects"

cmd="${1:?usage: sessions.sh <prompts|ids|replies|since|mark> ...}"
shift

case "$cmd" in
  prompts|ids)
    workspace=$(cd "${1:?workspace required}" && pwd -P)
    since="${2:-0}"
    [ -d "$PROJECTS" ] || exit 0

    # 期間外のファイルは読まない。since より後の発話を含むなら mtime も
    # since より後になる。余裕を1時間取って取りこぼしを防ぐ。
    if [ "$since" -gt 0 ]; then
      mins=$(( ( $(date +%s) * 1000 - since ) / 60000 + 60 ))
      [ "$mins" -lt 1 ] && mins=1
      files=$(find "$PROJECTS" -name '*.jsonl' -type f -mmin "-$mins" 2>/dev/null)
    else
      files=$(find "$PROJECTS" -name '*.jsonl' -type f 2>/dev/null)
    fi
    [ -n "$files" ] || exit 0

    # 人間が打った発話だけを残す。ツール結果、サブエージェント (isSidechain)、
    # 差し込みの system-reminder / スラッシュコマンドの展開は落とす。
    #
    # トランスクリプトでは、ハーネスが流し込む文字列も user 行として現れる。
    # スケジュールタスクの本文もここに入るため、落とさないと夜間ルーティンが
    # 自分自身の指示書を「その日のユーザ発話」として読み込む。本文は札の中に
    # そのまま含まれ、再投入されるときも札の一部と一致するので、札に現れる
    # 発話だけを落とす。スケジュール実行のセッションに人間が途中から割り込んだ
    # 発話は札に無いため残る。
    #
    # 短い発話は札に偶然含まれうるので、長さで下限を設けて取りこぼしを防ぐ。
    # 下限より短い本文を持つスケジュールタスクを作ると、その再投入は
    # 発話として通り抜ける。現行のタスク定義はいずれもこれより長い。
    #
    # この節の中で case を使わないこと。bash 3.2 は $( ) の中の `;;` を外側の
    # case 節の終わりと読むため、この節が cmd に関係なく実行されてしまう。
    out=$(printf '%s\n' "$files" | while IFS= read -r f; do
      [ -n "$f" ] || continue
      # 先頭の発話。スケジュールタスクの札で始まっていれば無人実行の目印になる。
      # JSON 文字列のまま取り出す。改行が \n に畳まれるので head -1 で1件に絞れ、
      # シェルを通しても本文が壊れない。
      tag=$(jq -c '
        select(.type == "user")
        | select(.isSidechain != true)
        | (.message.content
           | if type == "string" then . else ([.[]? | select(.type == "text") | .text] | join("")) end)
        | select(length > 0)
      ' "$f" 2>/dev/null | head -1)
      [ -n "$tag" ] || tag='""'
      jq -c --arg ws "$workspace" --argjson since "$since" --argjson tag "$tag" '
        select(.type == "user")
        | select(.isMeta != true and .isSidechain != true)
        | select((.userType // "external") == "external")
        | select(.cwd != null and (.cwd == $ws or (.cwd | startswith($ws + "/"))))
        | . as $e
        | ((.timestamp // "")
           | if . == "" then 0
             else (sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601 * 1000) end) as $ts
        | select($ts >= $since)
        | (if ($e.message.content | type) == "string" then [$e.message.content]
           else [$e.message.content[]? | select(.type == "text") | .text] end)
        | map(select(type == "string"))
        | map(select(test("<system-reminder>|<command-name>|tool_use_id") | not))
        | map(select(test("^(<scheduled-task|<task-notification>|<local-command|\\[Request interrupted|Caveat:)") | not))
        | join("\n")
        | select(length > 0)
        | . as $p
        | select(
            (($tag | startswith("<scheduled-task"))
             and (($p | length) >= 40)
             and ($tag | contains($p | gsub("^\\s+|\\s+$"; ""))))
            | not
          )
        | {ts: $ts, sessionId: $e.sessionId, prompt: .}
      ' "$f" 2>/dev/null
    done)
    [ -n "$out" ] || exit 0

    if [ "$cmd" = "ids" ]; then
      printf '%s\n' "$out" | jq -r 'select(.sessionId != null) | .sessionId' | sort -u
    else
      printf '%s\n' "$out" | jq -s -c 'sort_by(.ts) | .[]'
    fi
    ;;

  replies)
    session="${1:?session id required}"
    max="${2:-4000}"
    file=$(find "$PROJECTS" -name "$session.jsonl" -type f 2>/dev/null | head -1)
    [ -n "$file" ] || exit 0
    # ツール結果は落とし、人間が書いた発話とアシスタントの地の文だけを残す。
    # ids はスケジュール実行のセッションも返すため、ここで札を落とさないと
    # 出力の先頭が丸ごと自分の指示書になり、max の予算をそれで使い切る。
    jq -r '
      if .type == "user" and (.message.content | type) == "string"
        then .message.content
             | select(test("^(<scheduled-task|<task-notification>|<local-command)") | not)
             | "USER: " + .
      elif .type == "user" and (.message.content | type) == "array"
        then ([.message.content[] | select(.type == "text") | .text] | join("\n"))
             | select(length > 0)
             | select(test("^(<scheduled-task|<task-notification>|<local-command)") | not)
             | "USER: " + .
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
