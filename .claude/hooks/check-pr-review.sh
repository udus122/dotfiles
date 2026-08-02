#!/bin/bash
# PR 作成前のレビューを担保する。
#
# レビュー記録のないブランチからの PR 作成を止める。記録はブランチ単位で、
# claude-review-gate が <git-common-dir>/claude-review/refs/heads/<branch>.json に置く。
# パスの組み立て方は claude-review-gate と揃える必要があり、
# tools/test-check-pr-review.sh が両者の一致を固定している。
#
# PR は Bash の gh pr create だけでなく MCP の create_pull_request からも作られるので、
# tool_name で入口を分ける。
#
# Bash の判定はコマンド文字列全体ではなく、実際に実行される単位に対して行う。
# PR 本文はヒアドキュメントで渡すため、本文に書いた gh pr create を拾ってしまう。
# 前処理の 2 関数は check-git-push.sh から複製している。
set -euo pipefail
input=$(cat)

tool=$(printf '%s' "$input" | jq -r '.tool_name // empty')
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')

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

# ヒアドキュメント本体を落とす。本体はシェルが解釈しないデータなので、
# そこに現れた語で判定すると誤検知になる。ただし本体をシェル自身に食わせている
# 場合 (bash <<'EOF') は中身が実行されるため残す。
# 引用符は awk の正規表現内で扱いにくいので 8 進表記で書く (\047=' \042=")。
strip_heredocs() {
  awk '
    {
      if (skip) {
        line = $0
        sub(/^[[:space:]]+/, "", line)
        if (line == term) skip = 0
        next
      }
      if (match($0, /<<-?[[:space:]]*[\047\042]?[A-Za-z_][A-Za-z0-9_]*[\047\042]?/)) {
        tok = substr($0, RSTART, RLENGTH)
        sub(/^<<-?[[:space:]]*/, "", tok)
        gsub(/[\047\042]/, "", tok)
        if ($0 !~ /(^|[|&;[:space:](])(bash|sh|zsh|ksh|dash)([[:space:]]|$)/) {
          term = tok
          skip = 1
        }
      }
      print
    }
  '
}

# 複合コマンドを実行単位に割る。&& || ; | と改行が区切り。
split_segments() {
  sed -E 's/(&&|\|\||;|\|)/\
/g'
}

work_dir="$cwd"
branch=""

case "$tool" in
  Bash)
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
    [ -n "$cmd" ] || exit 0
    # PR 作成でない Bash では git を一切呼ばずに抜ける
    [[ "$cmd" =~ pr[[:space:]]+create ]] || exit 0

    segments=$(printf '%s\n' "$cmd" | strip_heredocs | split_segments)
    cd_dir=""
    target=""
    while IFS= read -r seg; do
      if [[ "$seg" =~ ^[[:space:]]*cd[[:space:]]+([^[:space:]]+) ]]; then
        cd_dir="${BASH_REMATCH[1]}"
        continue
      fi
      # gh [-R owner/repo] pr create の形だけを見る。任意のフラグを許す緩い形にすると
      # gh issue create --title "gh pr create を止める" のようなコマンドを誤検知する。
      if [[ ! "$seg" =~ (^|[[:space:]])gh([[:space:]]+(-R|--repo)[[:space:]]+[^[:space:]]+)?[[:space:]]+pr[[:space:]]+create([[:space:]]|$) ]]; then
        continue
      fi
      # 表示するだけのものは PR を作らない
      if [[ "$seg" =~ (^|[[:space:]])(--help|-h|--dry-run)([[:space:]]|$) ]]; then
        continue
      fi
      target="$seg"
      break
    done <<< "$segments"

    [ -n "$target" ] || exit 0
    if [ -n "$cd_dir" ]; then
      work_dir="${cd_dir/#\~/$HOME}"
    fi
    branch=$(printf '%s' "$target" \
      | sed -nE 's/.*(--head|-H)[[:space:]]+([^[:space:]]+).*/\2/p')
    ;;
  *)
    branch=$(printf '%s' "$input" | jq -r '.tool_input.head // empty')
    ;;
esac

# fork の owner:branch 形式
branch="${branch##*:}"
# 経路の混入を弾く
[[ "$branch" =~ ^[A-Za-z0-9._/-]+$ ]] || branch=""
case "$branch" in
  *..*) branch="" ;;
esac

# git で解決できないなら検証しようがないので素通りする。
# PR 作成が理由もなく止まる方が高くつく。
common=$(git -C "${work_dir:-.}" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) \
  || common=$(git -C "${work_dir:-.}" rev-parse --git-common-dir 2>/dev/null) \
  || exit 0
case "$common" in
  /*) ;;
  *) common="$(cd "${work_dir:-.}" && pwd -P)/$common" ;;
esac

if [ -z "$branch" ]; then
  branch=$(git -C "${work_dir:-.}" symbolic-ref --short HEAD 2>/dev/null || echo "")
fi
if [ -z "$branch" ]; then
  short=$(git -C "${work_dir:-.}" rev-parse --short HEAD 2>/dev/null || echo "")
  [ -n "$short" ] || exit 0
  branch="detached/$short"
fi

if [ -f "$common/claude-review/refs/heads/$branch.json" ]; then
  exit 0
fi

reason=$(cat <<EOF
このブランチ ($branch) には PR 作成前のレビュー記録がありません。

次の順で進めてください。

  1. サブエージェントを1つ起動し、その中でレビューさせる。メインの会話ではレビューしない
     渡すもの: リポジトリのパス、ブランチ名、比較元 (origin/main など)、変更の意図
     指示: code-review スキルを実行し、修正はせず指摘だけを重大度順に返す
     スキルが使えない場合は git diff <base>...HEAD を対象に、
     バグ・退行・設計の逸脱・テストの穴を見る

  2. 返ってきた指摘を直す。直さないものは理由を1行で残す。修正はコミットまで済ませる

  3. レビュー結果を記録する

       claude-review-gate record <<'REVIEW'
       何を見て、何を直し、何を残したかを数行で
       REVIEW

  4. もう一度 PR を作成する

記録はブランチ単位です。指摘を直したコミットで再レビューは要りません。
ユーザーがレビュー不要と明示した場合に限り、理由を添えて記録できます。

  claude-review-gate record --skip "ユーザーの指示: ..."
EOF
)

if ! command -v claude-review-gate >/dev/null 2>&1; then
  reason="$reason

claude-review-gate が見つからない場合は dotfiles で make link を実行してください。"
fi

deny "$reason"
