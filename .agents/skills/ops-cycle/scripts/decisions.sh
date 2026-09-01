#!/usr/bin/env bash
# 判断待ちの一覧と、解決済みのクローズ。
#
#   decisions.sh list    <workspace>                 open な判断待ちを JSONL で出す
#   decisions.sh resolve <repo> <number> <reason>    根拠を付けてクローズする
#
# 件数でルーティンを止めることはしないので、集計や分類のサブコマンドは持たない。
#
# 本文に書かれたコマンドをこのスクリプトが実行することはない。
# 再検証は呼び出し側が行い、結論だけをここへ渡す。Issue 本文は外部入力であり、
# そこに書かれた文字列を評価すると、Issue を書ける者に任意コード実行を許すため。
set -uo pipefail
. "$(dirname "$0")/ops-env.sh"

cmd="${1:?usage: decisions.sh <list|resolve> ...}"
ops_ready || exit 0

case "$cmd" in
  list)
    ws="${2:?workspace required}"
    repos=$({
      "$(dirname "$0")/repos.sh" "$ws" --issuable | cut -f3
      ops_cfg '.knowledge_repo'
      printf '\n'
    } | grep -v '^$' | sort -u)

    # 呼び出しの失敗を潰さない。潰すと「判断待ちが無い」と「gh が失敗した」が
    # 同じ空の出力になり、再検証を丸ごと飛ばしたまま報告には 0 件と出る。
    # ループはパイプの外で回す。パイプの中だと failed がサブシェルで消え、
    # 失敗を数えたつもりが常に空になる。
    failed=""
    malformed=""
    for repo in $repos; do
      # ラベルが正だが、それだけを入口にしない。判断待ちの節を書きながら
      # ラベルを付け忘れた Issue は、再検証に一度も掛からないまま残る。
      # 本文に節を持つものは、ラベルの有無にかかわらず拾う。
      labeled=$(gh issue list -R "$repo" --state open --label needs-decision --limit 100 \
        --json number,title,url,updatedAt) \
        || { failed="$failed $repo"; continue; }
      bodied=$(gh issue list -R "$repo" --state open --label from-nightly --limit 100 \
        --json number,title,url,updatedAt,body) \
        || { failed="$failed $repo"; continue; }

      # 受け皿は「判断待ち」と「解決の確認方法」が対になったものだけを拾う。
      # 判断待ちの記録はこの2節で1つの形と決まっている（references/deferral.md）。
      # 「判断待ち」だけを入口にすると、棚卸しの報告のように判断待ちの件数を
      # 述べただけの Issue が毎晩一覧に並ぶ。確認方法が無いので何度再検証しても
      # 判定できず、open のまま件数だけが減らない。
      shaped=$(printf '%s' "$bodied" | jq -c '
        def has($h): (.body // "") | test("(^|\n)## \($h) *(\n|$)");
        .[] | . + {deferral: has("判断待ち"), howto: has("解決の確認方法")}')

      # 落としたものは黙って捨てない。ラベルの付け忘れと確認方法の書き忘れが
      # 重なった項目は、一覧にも警告にも出ないまま open で残ることになる。
      unshaped=$(printf '%s' "$shaped" \
        | jq -r --arg repo "$repo" \
               --argjson labeled "$(printf '%s' "$labeled" | jq -c '[.[].number]')" '
          select(.deferral and (.howto | not))
          | select(.number as $n | $labeled | index($n) | not)
          | "\($repo)#\(.number)"')
      [ -z "$unshaped" ] || malformed="$malformed $unshaped"

      {
        printf '%s' "$labeled" | jq -c '.[] | {number, title, url, updatedAt}'
        printf '%s' "$shaped" | jq -c 'select(.deferral and .howto)
            | {number, title, url, updatedAt}'
      } | jq -c -s --arg repo "$repo" 'unique_by(.number)[] | {repo: $repo} + .'
    done

    if [ -n "$malformed" ]; then
      echo "判断待ちの節はあるが「## 解決の確認方法」もラベルも無いため一覧に入れない:$malformed" >&2
    fi

    if [ -n "$failed" ]; then
      echo "判断待ちの列挙に失敗:$failed" >&2
      exit 1
    fi
    ;;

  resolve)
    repo="${2:?repo required}"; num="${3:?number required}"; reason="${4:?reason required}"
    # 書き込みは許可された所有者に限る
    owner="${repo%%/*}"
    if ! ops_cfg_list '.issue_owners_allow' | grep -qxF "$owner"; then
      echo "起票してよい所有者ではないため操作しない: $repo" >&2
      exit 3
    fi
    gh issue comment "$num" -R "$repo" --body "$(cat <<EOF
再検証したところ、判断待ちの前提がすでに成立していないためクローズする。

$reason

---
<sub>夜間ルーティンが再検証してクローズ</sub>
EOF
)" >/dev/null || exit 1
    gh issue close "$num" -R "$repo" --reason completed >/dev/null
    ;;

  *)
    echo "unknown subcommand: $cmd" >&2
    exit 2
    ;;
esac
