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
# 未取り込みのうち、どのリモートにも無いコミットを抱えるものは、消すと
# 復元できない。控えのあるものと同じ行に見えないことを、push 済みの
# 未取り込みブランチと push していない未取り込みブランチの両方で見る。
#
# 未コミット変更も同じ理由で行に添える。コミットより先に唯一の複製になるため、
# push 済みで未 push が 0 件の未取り込み worktree でも添わることを見る。
# ここが抜けると、控えがあるものと同じ行に見えて、消したときだけ失われる。
# 未 push と併せ持つ worktree でも、片方がもう片方を隠さないことを見る。
#
# リポジトリ配下に切られた worktree は、置き場のルールから外れているうえ
# gitignore を尊重しない検索を汚す。消せないものにも印が付くことを、
# 未取り込みの worktree をリポジトリ配下に切って確かめる。
#
#   tools/test-git-wt-clean.sh
set -uo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd -P)
WT_CLEAN="$REPO/.local/bin/git-wt-clean"

# 物理パスに直しておく。macOS の mktemp は /var/... を返すが、git が出すのは
# 実体の /private/var/... なので、直さないと検査側のパスと出力側のパスが食い違う。
# 前方一致は素通りしてしまうため、行の位置まで見る検査が黙って当たらなくなる。
tmp=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$tmp"' EXIT

# 既定ブランチ名を環境に委ねない。init.defaultBranch が未設定だと bare 側の HEAD が
# refs/heads/master を指し、remote set-head が「Cannot determine remote HEAD」で失敗する。
# 検査は落ちないが、origin/HEAD を読む経路ではなく既定値へのフォールバックを
# 通るようになるため、確かめたいものが確かめられなくなる。
git init -q --bare "$tmp/origin.git"
git -C "$tmp/origin.git" symbolic-ref HEAD refs/heads/main
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

# main に取り込まれない側。push 済みのものは、worktree を消しても
# remote から取り戻せる。
git -C "$root" checkout -q -b unmerged main
commit unmerged
unmerged_head=$(git -C "$root" rev-parse HEAD)
git -C "$root" push -q -u origin unmerged
git -C "$root" checkout -q main

# 未取り込み・push 済みだが、未コミット変更を抱える側。コミットは remote から
# 取り戻せるが、その変更だけは手元にしか無い。
git -C "$root" checkout -q -b unmerged-dirty main
commit unmerged-dirty
git -C "$root" push -q -u origin unmerged-dirty
git -C "$root" checkout -q main

# 未取り込みかつ push もしていない側。ここが唯一の複製になる。
git -C "$root" checkout -q -b unpushed main
commit unpushed-1
commit unpushed-2
git -C "$root" checkout -q main

# 未 push のコミットと未コミット変更の両方を抱える側。但し書きは片方が
# もう片方を隠さず、2 つとも並ぶ。
git -C "$root" checkout -q -b unpushed-dirty main
commit unpushed-dirty
git -C "$root" checkout -q main

# リポジトリ配下に置かれる側。実際に積み上がっているのは Claude Code が
# .claude/worktrees/ に切るもので、いずれも未取り込みのまま残る。
git -C "$root" checkout -q -b inside-unmerged main
commit inside-unmerged
git -C "$root" checkout -q main

git -C "$root" worktree add -q "$tmp/wt-merged-clean" merged-clean
git -C "$root" worktree add -q "$tmp/wt-merged-dirty" merged-dirty
git -C "$root" worktree add -q "$tmp/wt-unmerged" unmerged
git -C "$root" worktree add -q --detach "$tmp/wt-detached-merged" "$merged_head"
git -C "$root" worktree add -q --detach "$tmp/wt-detached-unmerged" "$unmerged_head"
git -C "$root" worktree add -q "$tmp/wt-unmerged-dirty" unmerged-dirty
git -C "$root" worktree add -q "$tmp/wt-unpushed" unpushed
git -C "$root" worktree add -q "$tmp/wt-unpushed-dirty" unpushed-dirty
inside="$root/.claude/worktrees/inside"
git -C "$root" worktree add -q "$inside" inside-unmerged
echo dirt > "$tmp/wt-merged-dirty/untracked.txt"
echo dirt > "$tmp/wt-unmerged-dirty/untracked.txt"
echo dirt > "$tmp/wt-unpushed-dirty/untracked.txt"
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
check present "KEEP (未取り込み・未 push 2件): unpushed" \
  "どのリモートにも無いコミットは件数を添える"
check absent  "KEEP (未取り込み・未 push 0件)" \
  "控えがあるものに未 push の但し書きを付けない"
check present "KEEP (未取り込み・未コミット変更 1件): unmerged-dirty" \
  "未 push が無くても未コミット変更の件数を添える"
check present "KEEP (未取り込み・未 push 1件・未コミット変更 1件): unpushed-dirty" \
  "未 push と未コミット変更は片方がもう片方を隠さない"
check absent  "SKIP (未コミット変更 1件): unmerged-dirty" \
  "未取り込みのものを未コミット変更でスキップ扱いにしない"
check present "dry-run: 2件が削除対象 / 1件はスキップ / 6件は未取り込み" "件数が合う"

# 置き場の印は、行に対して付く。消せないものにも付いていることを見る。
inside_line=$(grep -F -- "$inside" <<<"$out")
check_line() {  # check_line <行> <部分文字列> <説明>
  if [ -n "$1" ] && grep -qF -- "$2" <<<"$1"; then
    pass=$((pass + 1))
  else
    printf 'NG   %s\n       この行に %s が要る: %s\n' "$3" "$2" "${1:-（行が無い）}"
    fail=$((fail + 1))
  fi
}
check_line "$inside_line" "[リポジトリ配下]" \
  "リポジトリ配下の worktree には印を添える"
check_line "$inside_line" "KEEP (未取り込み・未 push 1件)" \
  "印を添えても未取り込みの判定は変わらない"

# 規定どおりの置き場にあるものには付けない。付くと、印が置き場を指さなくなる。
for outside in "$tmp/wt-unmerged" "$tmp/wt-merged-dirty"; do
  line=$(grep -F -- "$outside" <<<"$out")
  if grep -qF -- "[リポジトリ配下]" <<<"$line"; then
    printf 'NG   リポジトリ外の worktree に印を付けない\n       %s\n' "$line"
    fail=$((fail + 1))
  else
    pass=$((pass + 1))
  fi
done

# 一覧に出すことと、削除の対象にすることは別。削除を指示する行だけを抜き出して、
# 未取り込みのものがそちらに現れないことを見る。
removing=$(grep -E '^(would remove|removed)' <<<"$out")
for needle in "$tmp/wt-unmerged" "$tmp/wt-detached-unmerged" "$tmp/wt-unpushed"; do
  if grep -qF -- "$needle" <<<"$removing"; then
    printf 'NG   未取り込みの worktree は削除の対象にしない\n       %s\n' "$needle"
    fail=$((fail + 1))
  else
    pass=$((pass + 1))
  fi
done

# `### <root>` の見出しは出るので、worktree ごとの行だけを見る。
# 部分一致では見られない。リポジトリ配下の worktree のパスは "$root" で始まるため、
# 含むかどうかで見ると、そちらが出ているだけで本体を対象にしたと誤検知する。
# パスの区切りで分ける。"$root/" と続くならリポジトリ配下の worktree、
# そこで終わる（または但し書きが続く）なら本体そのもの。
acted=$(grep -E '^(would remove|removed|SKIP|KEEP|FAILED)' <<<"$out")
root_acted=0
while IFS= read -r line; do
  case "$line" in
    *"  $root"/*) ;;
    *"  $root"*) root_acted=1 ;;
  esac
done <<<"$acted"
if [ "$root_acted" -eq 1 ]; then
  printf 'NG   本体のチェックアウト自体は対象にしない\n'
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

printf '\n%d/%d ok\n' "$pass" "$((pass + fail))"
[ "$fail" -eq 0 ] || { printf '\n--- 実際の出力 ---\n%s\n' "$out"; exit 1; }
