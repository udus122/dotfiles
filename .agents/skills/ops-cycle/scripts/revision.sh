#!/usr/bin/env bash
# 稼働中のスキル実体が、どの版で動いているかを1行で出す。
#
# スキルとフックは作業チェックアウトへのシンボリックリンクとして稼働する。
# そこが古いまま放置されると、修正を既定ブランチへマージしても、夜間は
# 静かに旧版で動き続ける。実害が出るまで気付く手段が無いのが問題なので、
# 実行のたびに版を名乗らせて、報告から判定できるようにする。
#
# 取り込みはしない。作業チェックアウトは未コミットの変更を抱えていることが
# 多く、無条件に引き寄せると人間の作業を壊す。古いことを伝えるだけにする。
#
#   revision.sh          <ブランチ>@<短縮ハッシュ> (最新 | N コミット遅れ)
set -uo pipefail

# 自分自身の置き場から実体のリポジトリを引く。シンボリックリンク経由で
# 起動されても、git はリンク先のリポジトリを見る。
repo=$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -n "$repo" ] || exit 0

head=$(git -C "$repo" rev-parse --short HEAD 2>/dev/null) || exit 0
branch=$(git -C "$repo" symbolic-ref --short HEAD 2>/dev/null || echo "detached")

# 既定ブランチは remote の HEAD から引く。取れなければ origin/main を仮定する。
base=$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
base="${base:-origin/main}"

git -C "$repo" fetch -q origin 2>/dev/null || true
behind=$(git -C "$repo" rev-list --count "HEAD..$base" 2>/dev/null || echo "")

dirty=""
git -C "$repo" diff --quiet 2>/dev/null || dirty=" / 未コミットの変更あり"

# 競合したまま止まった rebase / merge は、そのままだと上の「未コミットの変更あり」に
# 丸まる。しかし競合マーカーの入ったファイルもリンク越しに配られるため、$HOME から
# 読む側（CLAUDE.md・フック・コマンド）は2つの版が併記された内容を読むことになる。
# HEAD が既定ブランチに追いついていても起きるので、遅れとは別に名指しする。
# 配布対象かどうかはここでは判定せず、ファイル名を出して読み手に委ねる。
unmerged=$(git -C "$repo" diff --name-only --diff-filter=U 2>/dev/null)
n=$(printf '%s' "$unmerged" | grep -c . || true)

# 競合を git add してから止めた場合は unmerged エントリが残らない。マーカーは
# ファイルに入ったままなので、途中で止まっている印そのものも見る。
gitdir=$(git -C "$repo" rev-parse --absolute-git-dir 2>/dev/null || echo "")
halted=""
if [ -n "$gitdir" ]; then
  if [ -e "$gitdir/rebase-merge" ] || [ -e "$gitdir/rebase-apply" ]; then
    halted="rebase"
  elif [ -e "$gitdir/MERGE_HEAD" ]; then
    halted="merge"
  elif [ -e "$gitdir/CHERRY_PICK_HEAD" ]; then
    halted="cherry-pick"
  fi
fi

if [ "${n:-0}" -gt 0 ]; then
  first=$(printf '%s\n' "$unmerged" | head -n 1)
  more=""
  [ "$n" -gt 1 ] && more=" ほか $((n - 1)) 件"
  dirty=" / 競合が未解決: $first$more"
elif [ -n "$halted" ]; then
  dirty=" / $halted が途中で止まっている"
fi

# チェックアウトが最新でも、$HOME へのリンクが配られていなければ稼働しない。
# 追加されたスキルやフックは、リンクが作られるまで存在しないのと同じで、
# しかも欠けたフックは exit 127 になるだけで何も止めないため、静かに失効する。
# 配る条件はリポジトリ側の link.sh が持っているので、判定もそこへ委ねる。
links=""
if [ -x "$repo/link.sh" ]; then
  n=$("$repo/link.sh" --check 2>/dev/null | grep -c . || true)
  [ "${n:-0}" -gt 0 ] && links=" / \$HOME へのリンクが $n 件未作成（link.sh で解消）"
fi

case "$behind" in
  "")  state="$base と比較できない" ;;
  0)   state="最新" ;;
  *)   state="$base より $behind コミット遅れ" ;;
esac

printf '%s@%s (%s)%s%s\n' "$branch" "$head" "$state" "$dirty" "$links"
