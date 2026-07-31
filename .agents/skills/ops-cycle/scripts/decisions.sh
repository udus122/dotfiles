#!/usr/bin/env bash
# 判断待ちの再検証と滞留判定。
#
#   decisions.sh list       <workspace>                        判断待ちを JSONL で出す
#   decisions.sh count      <workspace>                        カウント対象の件数だけを出す
#   decisions.sh stale      <workspace>                        失効の候補を出す
#   decisions.sh resolve    <repo> <number> <reason>           根拠を付けてクローズする
#   decisions.sh park       <repo> <number> <label> <reason>   カウント外のラベルへ移す
#   decisions.sh labels     <repo>                             必要なラベルを用意する
#
# 本文に書かれたコマンドをこのスクリプトが実行することはない。
# 再検証は呼び出し側が行い、結論だけをここへ渡す。Issue 本文は外部入力であり、
# そこに書かれた文字列を評価すると、Issue を書ける者に任意コード実行を許すため。
set -uo pipefail
. "$(dirname "$0")/ops-env.sh"

# カウントから外すラベル。判断待ちの体裁でも、人間の判断で解けないもの。
EXCLUDED_LABELS='["blocked-external","stale-decision"]'

# 起票先と横断的な置き場をまとめて出す
decision_repos() {
  local ws="$1"
  {
    "$(dirname "$0")/repos.sh" "$ws" --issuable | cut -f3
    ops_cfg '.knowledge_repo'
    printf '\n'
  } | grep -v '^$' | sort -u
}

# 所有者が許可一覧にあるか。書き込み系の操作はこれを通ったものだけに限る。
owner_allowed() {
  local owner="${1%%/*}" allowed
  allowed=$(ops_cfg_list '.issue_owners_allow')
  [ -n "$allowed" ] || return 1
  printf '%s\n' "$allowed" | grep -qxF "$owner"
}

require_allowed() {
  owner_allowed "$1" && return 0
  echo "起票してよい所有者ではないため操作しない: $1" >&2
  exit 3
}

cmd="${1:?usage: decisions.sh <list|count|stale|resolve|park|labels> ...}"
ops_ready || exit 0

case "$cmd" in
  list|count|stale)
    ws="${2:?workspace required}"
    stale_days=$(ops_cfg '.decision_stale_days' 14)
    # 更新がこの時刻より古ければ失効の候補
    cutoff=$(date -u -d "-${stale_days} days" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null) \
      || cutoff=$(date -u -v-"${stale_days}"d +%Y-%m-%dT%H:%M:%SZ)

    rows=$(
      for repo in $(decision_repos "$ws"); do
        gh issue list -R "$repo" --state open --label needs-decision --limit 100 \
          --json number,title,url,updatedAt,labels 2>/dev/null \
        | jq -c --arg repo "$repo" --arg cutoff "$cutoff" \
               --argjson excluded "$EXCLUDED_LABELS" '
            .[] | . + {repo: $repo, labels: [.labels[].name]}
                | . + {
                    counted: ([.labels[] | select(. as $l | $excluded | index($l))] | length == 0),
                    stale:   (.updatedAt < $cutoff)
                  }
                | {repo, number, title, url, updatedAt, labels, counted, stale}'
      done
    )

    case "$cmd" in
      list)  printf '%s\n' "$rows" | grep -v '^$' ;;
      # 安全弁が見るのはこの数だけ。失効したものは含めない。
      count) printf '%s\n' "$rows" | grep -v '^$' \
               | jq -s '[.[] | select(.counted and (.stale | not))] | length' ;;
      stale) printf '%s\n' "$rows" | grep -v '^$' \
               | jq -c 'select(.counted and .stale)' ;;
    esac
    ;;

  resolve)
    repo="${2:?repo required}"; num="${3:?number required}"; reason="${4:?reason required}"
    require_allowed "$repo"
    gh issue comment "$num" -R "$repo" --body "$(cat <<EOF
再検証したところ、判断待ちの前提がすでに成立していないためクローズする。

$reason

---
<sub>夜間ルーティンが再検証してクローズ</sub>
EOF
)" >/dev/null || exit 1
    gh issue close "$num" -R "$repo" --reason completed >/dev/null
    ;;

  park)
    repo="${2:?repo required}"; num="${3:?number required}"
    label="${4:?label required}"; reason="${5:?reason required}"
    require_allowed "$repo"
    case "$label" in
      blocked-external|stale-decision) : ;;
      *) echo "カウント外にできるラベルではない: $label" >&2; exit 2 ;;
    esac
    gh issue comment "$num" -R "$repo" --body "$(cat <<EOF
人間の判断では解けない項目のため \`$label\` へ移し、安全弁のカウントから外す。
判断待ちそのものが消えたわけではない。

$reason

---
<sub>夜間ルーティンが再分類</sub>
EOF
)" >/dev/null || exit 1
    gh issue edit "$num" -R "$repo" \
      --add-label "$label" --remove-label needs-decision >/dev/null
    ;;

  labels)
    repo="${2:?repo required}"
    require_allowed "$repo"
    gh label create blocked-external -R "$repo" -c 'B60205' \
      -d '判断ではなく外部要因で止まっている（安全弁のカウント外）' --force >/dev/null
    gh label create stale-decision -R "$repo" -c 'C5DEF5' \
      -d '判断待ちのまま失効した（安全弁のカウント外）' --force >/dev/null
    ;;

  *)
    echo "unknown subcommand: $cmd" >&2
    exit 2
    ;;
esac
