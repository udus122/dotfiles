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
# 遅れと同じ理由で、進み（未 push のコミット）も出す。既定ブランチに無いコミットの
# 上で走っているなら、稼働しているのはレビューもマージも経ていない版であり、
# 報告の「最新」が指しているものが実際とずれる。
#
#   revision.sh          <ブランチ>@<短縮ハッシュ> (最新 | N コミット遅れ | 未 push N 件)
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
counts=$(git -C "$repo" rev-list --left-right --count "HEAD...$base" 2>/dev/null || echo "")
ahead=$(printf '%s' "$counts" | cut -f1)
behind=$(printf '%s' "$counts" | cut -f2)

dirty=""
git -C "$repo" diff --quiet 2>/dev/null || dirty=" / 未コミットの変更あり"

# チェックアウトが最新でも、$HOME へのリンクが配られていなければ稼働しない。
# 追加されたスキルやフックは、リンクが作られるまで存在しないのと同じで、
# しかも欠けたフックは exit 127 になるだけで何も止めないため、静かに失効する。
# 配る条件はリポジトリ側の link.sh が持っているので、判定もそこへ委ねる。
links=""
if [ -x "$repo/link.sh" ]; then
  n=$("$repo/link.sh" --check 2>/dev/null | grep -c . || true)
  [ "${n:-0}" -gt 0 ] && links=" / \$HOME へのリンクが $n 件未作成（link.sh で解消）"
fi

if [ -z "$behind" ] || [ -z "$ahead" ]; then
  state="$base と比較できない"
elif [ "$behind" -gt 0 ] && [ "$ahead" -gt 0 ]; then
  state="$base と分岐 — $behind コミット遅れ / 未 push が $ahead 件"
elif [ "$behind" -gt 0 ]; then
  state="$base より $behind コミット遅れ"
elif [ "$ahead" -gt 0 ]; then
  state="$base に未 push のコミットが $ahead 件"
else
  state="最新"
fi

printf '%s@%s (%s)%s%s\n' "$branch" "$head" "$state" "$dirty" "$links"
