#!/usr/bin/env bash
# tools/ のテストが、どれか1つのワークフローから呼ばれていることを点検する。
#
# 追加しただけで配線を忘れたテストは、手元で通してもう用が済んだように見え、
# 以後 CI では一度も走らない。壊れても赤くならないので、退行を検知する目的で
# 書いたはずのテストが、退行を隠す側に回る。実際に2件（判断待ちの一覧と
# worktree の走査対象）が配線されないまま積み上がっていた。
#
#   tools/test-ci-coverage.sh
set -uo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd -P)
WORKFLOWS="$REPO/.github/workflows"

# 見るのは run: の行だけ。ワークフロー冒頭の日本語コメントにテストのパスを
# 書く様式があるため、ファイル全体を対象にすると、コメントに名前が残っている
# だけで配線済みと数える。それでは検出器のほうが先に嘘をつく。
missing=""
for path in "$REPO"/tools/test-*.sh; do
  name=$(basename "$path")
  grep -rh 'run:' "$WORKFLOWS" | grep -qF "tools/$name" || missing="$missing $name"
done

if [ -n "$missing" ]; then
  echo "どのワークフローからも呼ばれていないテスト:$missing" >&2
  echo ".github/workflows/ のいずれかに追加するか、不要なら削除する" >&2
  exit 1
fi

n=$(ls "$REPO"/tools/test-*.sh | wc -l | tr -d ' ')
echo "$n tests wired"
