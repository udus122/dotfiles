#!/usr/bin/env bash
# git-wt-clean の走査対象を、代表的な worktree の組み合わせで点検する。
#
# detached HEAD の worktree はブランチ名を持たないため、列挙を `branch` 行だけに
# 頼ると一覧にすら現れない。消しても失うもののない複製が無期限に積み上がり、
# gitignore を尊重しない検索が本体と複製の両方に当たるようになる。
# 出力は「対象なし」と見分けが付かないので、退行に気付く手段がここしかない。
#
# 未取り込みの worktree も同じ理由で一覧に出す。ただし削除の対象には決して
# しない。この2つを分けて検査するため、削除を指示する行だけを抜き出して
# そちらに現れないことを見る。
#
#   tools/test-git-wt-clean.sh
set -uo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd -P)
WT_CLEAN="$REPO/.local/bin/git-wt-clean"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

git init -q --bare "$tmp/origin.git"
git clone -q "$tmp/origin.git" "$tmp/root"
root="$tmp/root"
git -C "$root" config user.email t@example.com
git -C "$root" config user.name test

commit() {  # commit <message>
  echo "$1" >> "$root/log.txt"
  git -C "$root" add log.txt
  git -C "$root" commit -q -m "$1"
}

echo 'ignored-stuff/' > "$root/.gitignore"
git -C "$root" add .gitignore
commit base
git -C "$root" branch -M main
git -C "$root" push -q -u origin main
git -C "$root" remote set-head origin -a >/dev/null

# main に取り込まれる側。マージしてから worktree を切る。
git -C "$root" checkout -q -b merged-clean
commit merged-clean
merged_head=$(git -C "$root" rev-parse HEAD)
git -C "$root" checkout -q -b merged-dirty
commit merged-dirty
git -C "$root" checkout -q main
git -C "$root" merge -q --no-ff -m 'merge merged-clean' merged-clean
git -C "$root" merge -q --no-ff -m 'merge merged-dirty' merged-dirty
git -C "$root" push -q origin main

# main に取り込まれない側。
git -C "$root" checkout -q -b unmerged main
commit unmerged
unmerged_head=$(git -C "$root" rev-parse HEAD)
git -C "$root" checkout -q main

git -C "$root" worktree add -q "$tmp/wt-merged-clean" merged-clean
git -C "$root" worktree add -q "$tmp/wt-merged-dirty" merged-dirty
git -C "$root" worktree add -q "$tmp/wt-unmerged" unmerged
git -C "$root" worktree add -q --detach "$tmp/wt-detached-merged" "$merged_head"
git -C "$root" worktree add -q --detach "$tmp/wt-detached-unmerged" "$unmerged_head"
echo dirt > "$tmp/wt-merged-dirty/untracked.txt"
mkdir "$tmp/wt-merged-clean/ignored-stuff"
echo build-artifact > "$tmp/wt-merged-clean/ignored-stuff/out.bin"

out=$(bash "$WT_CLEAN" --dry-run "$root" 2>&1)

pass=0
fail=0

check() {  # check present|absent <部分文字列> <説明>
  local mode="$1" needle="$2" desc="$3"
  if grep -qF -- "$needle" <<<"$out"; then
    [ "$mode" = present ] && { pass=$((pass + 1)); return; }
  else
    [ "$mode" = absent ] && { pass=$((pass + 1)); return; }
  fi
  printf 'NG   %s\n       %s であるべき: %s\n' "$desc" "$mode" "$needle"
  fail=$((fail + 1))
}

check present "would remove: merged-clean" "マージ済みのブランチは削除対象になる"
check present "(無視されたファイル 1件も消える)" \
  "無視されたファイルを抱えていることを出力に添える"
check absent  "SKIP (未コミット変更 1件): merged-clean" \
  "無視されたファイルは未コミット変更として数えない"
check present "would remove: (detached ${merged_head:0:7})" \
  "main の祖先を指す detached HEAD も削除対象になる"
check present "SKIP (未コミット変更 1件): merged-dirty" \
  "未コミット変更があるものはスキップして一覧に出す"
check present "KEEP (未取り込み): unmerged" "未取り込みのブランチは一覧に出す"
check present "KEEP (未取り込み): (detached ${unmerged_head:0:7})" \
  "main の祖先でない detached HEAD も一覧に出す"
check present "dry-run: 2件が削除対象 / 1件はスキップ / 2件は未取り込み" "件数が合う"

# 一覧に出すことと、削除の対象にすることは別。削除を指示する行だけを抜き出して、
# 未取り込みのものがそちらに現れないことを見る。
removing=$(grep -E '^(would remove|removed)' <<<"$out")
for needle in "$tmp/wt-unmerged" "$tmp/wt-detached-unmerged"; do
  if grep -qF -- "$needle" <<<"$removing"; then
    printf 'NG   未取り込みの worktree は削除の対象にしない\n       %s\n' "$needle"
    fail=$((fail + 1))
  else
    pass=$((pass + 1))
  fi
done

# `### <root>` の見出しは出るので、worktree ごとの行だけを見る。
acted=$(grep -E '^(would remove|removed|SKIP|KEEP|FAILED)' <<<"$out")
if grep -qF -- "$root" <<<"$acted"; then
  printf 'NG   本体のチェックアウト自体は対象にしない\n'
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

printf '\n%d/%d ok\n' "$pass" "$((pass + fail))"
[ "$fail" -eq 0 ] || { printf '\n--- 実際の出力 ---\n%s\n' "$out"; exit 1; }
