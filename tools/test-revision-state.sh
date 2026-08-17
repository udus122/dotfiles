#!/usr/bin/env bash
# revision.sh が名乗る版の状態を、遅れ・進み・分岐の4通りで点検する。
#
# この行は夜間の報告に毎回載り、稼働している版が既定ブランチの版かどうかを
# 判定する唯一の材料になる。誤って「最新」と名乗っても出力は正常に見えるので、
# 退行に気付く手段がここしかない。
#
# 進み（未 push）を落とすと、既定ブランチに無いコミットの上で走っている状態が
# 「最新」に見える。レビューもマージも経ていない版で夜間が走っていることが、
# 報告からは読み取れなくなる。
#
#   tools/test-revision-state.sh
set -uo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd -P)
REVISION_SH="$REPO/.agents/skills/ops-cycle/scripts/revision.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0

git_q() { git -C "$1" "${@:2}" >/dev/null 2>&1; }

# 実体の置き場から repo を引く実装に合わせ、スクリプトを複製した先で走らせる。
# origin は同じディスク上のベアリポジトリにして、ネットワークに依存させない。
setup() {  # setup <名前>  → 作業リポジトリのパスを出す
  local name="$1" work="$tmp/$1" origin="$tmp/$1.git"
  git init -q --bare "$origin"
  git init -q -b main "$work"
  git_q "$work" config user.email t@example.com
  git_q "$work" config user.name t
  git_q "$work" remote add origin "$origin"

  mkdir -p "$work/.agents/skills/ops-cycle/scripts"
  cp "$REVISION_SH" "$work/.agents/skills/ops-cycle/scripts/revision.sh"
  : > "$work/seed"
  git_q "$work" add -A
  git_q "$work" commit -m seed
  git_q "$work" push -u origin main
  printf '%s' "$work"
}

commit_on() {  # commit_on <repo> <名前>
  : >> "$1/$2"
  git_q "$1" add -A
  git_q "$1" commit -m "$2"
}

check() {  # check <説明> <期待する部分文字列> <repo>
  local desc="$1" expect="$2" work="$3" got
  got=$(bash "$work/.agents/skills/ops-cycle/scripts/revision.sh" 2>/dev/null)
  case "$got" in
    *"$expect"*) pass=$((pass + 1)) ;;
    *)
      printf 'NG   %s\n       期待 %s を含む / 実際 %s\n' "$desc" "$expect" "$got"
      fail=$((fail + 1))
      ;;
  esac
}

# --------------------------------------------------------------- 追いついている

w=$(setup latest)
check "既定ブランチと一致していれば最新" "(最新)" "$w"

# ------------------------------------------------------------------------ 遅れ

w=$(setup behind)
# origin だけを進める。別のクローンから push して、作業側は fetch されていない状態にする。
git clone -q "$tmp/behind.git" "$tmp/behind-other"
git_q "$tmp/behind-other" config user.email t@example.com
git_q "$tmp/behind-other" config user.name t
commit_on "$tmp/behind-other" a
commit_on "$tmp/behind-other" b
git_q "$tmp/behind-other" push origin main
check "既定ブランチが先にあれば遅れを出す" "2 コミット遅れ" "$w"

# ------------------------------------------------------- 進み（未 push）

w=$(setup ahead)
commit_on "$w" local-only
check "未 push のコミットを最新と名乗らない" "未 push のコミットが 1 件" "$w"

# ------------------------------------------------------------------------ 分岐

w=$(setup diverged)
git clone -q "$tmp/diverged.git" "$tmp/diverged-other"
git_q "$tmp/diverged-other" config user.email t@example.com
git_q "$tmp/diverged-other" config user.name t
commit_on "$tmp/diverged-other" remote-side
git_q "$tmp/diverged-other" push origin main
commit_on "$w" local-side
check "両方に進みがあれば分岐として両方出す" "分岐" "$w"

# 分岐のとき、遅れと進みの件数が入れ替わっていないこと。
# --left-right の左右を取り違えても、片側だけを見るテストは通ってしまう。
got=$(bash "$tmp/diverged/.agents/skills/ops-cycle/scripts/revision.sh" 2>/dev/null)
case "$got" in
  *"1 コミット遅れ"*"未 push が 1 件"*) pass=$((pass + 1)) ;;
  *)
    printf 'NG   分岐の内訳が遅れ・進みの順で出ていない\n       実際 %s\n' "$got"
    fail=$((fail + 1))
    ;;
esac

printf '\n%s 件中 %s 件が期待どおり' "$((pass + fail))" "$pass"
if [ "$fail" -gt 0 ]; then
  printf '（%s 件が不一致）\n' "$fail"
  exit 1
fi
printf '\n'
