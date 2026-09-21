#!/usr/bin/env bash
# revision.sh が、どのリポジトリの状態を報告するかを点検する。
#
# 遅れているときは既定ブランチ側の版を作業ツリーの外へ取り出して走らせる。取り出し先
# はリポジトリではないので、引数を受け取れないと稼働側の状態を報告できず、稼働側の
# 古い版で代わりに走らせることになる。その夜に入っていない検出は報告に出ない。
#
# 逆向きの退行も同じだけ危ない。渡したパスがリポジトリでなかったときに黙って 0 で
# 抜けると、非公開層が無い環境の no-op と見分けが付かず、報告からは状態が正常だと
# 読める。ここでは終了ステータスと標準エラーまで見る。
#
#   tools/test-revision.sh
set -uo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd -P)
REVISION_SH="$REPO/.agents/skills/ops-cycle/scripts/revision.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

git() { command git -c user.name=t -c user.email=t@example.invalid \
                    -c init.defaultBranch=main -c commit.gpgsign=false "$@"; }

# 上流と作業チェックアウトを作る。origin/main を持たせるため bare を経由する。
git init -q --bare "$tmp/remote.git"
git init -q "$tmp/work"
cd "$tmp/work"
git remote add origin "$tmp/remote.git"
printf 'base\n' > shared.txt
git add shared.txt
git commit -qm base
git push -q origin main

# 取り出し先を模す。リポジトリの外にスクリプトだけが置かれた状態。
mkdir -p "$tmp/extracted"
cp "$REVISION_SH" "$tmp/extracted/revision.sh"
EX="$tmp/extracted/revision.sh"

pass=0
fail=0

check() {  # check <説明> <条件の真偽 0/1>
  if [ "$2" -eq 0 ]; then
    pass=$((pass + 1))
  else
    printf 'NG   %s\n' "$1"
    fail=$((fail + 1))
  fi
}

# ------------------------------------------------- 取り出し先から稼働側を見る

out=$(bash "$EX" "$tmp/work" 2>"$tmp/err")
check "リポジトリの外に置いた版でも、渡したパスの状態を報告する" \
  "$(printf '%s' "$out" | grep -q 'main@' && echo 0 || echo 1)"

# 引数なしは毎晩通る経路。リポジトリの中に置いた版で、そこを報告することまで見る。
# 「何も出ない」だけを見ると、置き場から引く処理が丸ごと壊れても気付けない。
cp "$REVISION_SH" "$tmp/work/revision.sh"
out=$(bash "$tmp/work/revision.sh" 2>"$tmp/err")
check "引数が無ければ自分の置き場のリポジトリを報告する" \
  "$(printf '%s' "$out" | grep -q 'main@' && echo 0 || echo 1)"
rm -f "$tmp/work/revision.sh"

out=$(bash "$EX" 2>"$tmp/err")
status=$?
check "引数なしで置き場から引けないときは非ゼロで終わる" \
  "$([ "$status" -ne 0 ] && echo 0 || echo 1)"
check "そのとき引数を渡す旨を標準エラーに出す" \
  "$(grep -q 'revision.sh <repo>' "$tmp/err" && echo 0 || echo 1)"

# --------------------------------------------- 渡したパスがリポジトリでない

out=$(bash "$EX" "$tmp/notarepo" 2>"$tmp/err")
status=$?
check "リポジトリでないパスは非ゼロで終わる" "$([ "$status" -ne 0 ] && echo 0 || echo 1)"
check "そのパスを標準エラーに名指しする" \
  "$(grep -q 'notarepo' "$tmp/err" && echo 0 || echo 1)"
check "no-op と同じ見え方（標準出力が空で成功）にしない" \
  "$([ -n "$out" ] || [ "$status" -ne 0 ] && echo 0 || echo 1)"

# --------------------------------------------- 未コミットの変更の見落とし

# 引き寄せの可否を判断する材料なので、手元にしか無い作業は形を問わず出る必要がある。
# 未ステージの変更だけを見ていると、add したまま止まった変更と追跡外のファイルが
# 「最新」に紛れる。どちらも切り替えで壊れる側なので、ここで塞ぐ。

out=$(bash "$EX" "$tmp/work" 2>"$tmp/err")
check "前提: 変更が無ければ未コミットの印を出さない" \
  "$(printf '%s' "$out" | grep -q '未コミットの変更' && echo 1 || echo 0)"

printf 'staged\n' > shared.txt
git add shared.txt
out=$(bash "$EX" "$tmp/work" 2>"$tmp/err")
check "ステージ済みのまま止まった変更を見落とさない" \
  "$(printf '%s' "$out" | grep -q '未コミットの変更' && echo 0 || echo 1)"
git reset -q --hard

printf 'untracked\n' > stray.txt
out=$(bash "$EX" "$tmp/work" 2>"$tmp/err")
check "追跡されていないファイルを見落とさない" \
  "$(printf '%s' "$out" | grep -q '未コミットの変更' && echo 0 || echo 1)"
# 部分一致で見ると、件数の境界（1件で「ほか 0 件」と出る）も、パスの切り出しが
# 1桁ずれて先頭に空白が残る形も通ってしまう。1件のときの行そのものを等値で見る。
check "1件のときは行ごと一致する（余分な件数も空白も付かない）" \
  "$([ "$out" = "main@$(git rev-parse --short HEAD) (最新) / 未コミットの変更: stray.txt" ] \
     && echo 0 || echo 1)"

# 追跡外のディレクトリは、既定では中身が畳まれて1行になる。畳まれたままだと
# スキルを丸ごと置いた状態が常に「1 件」になる。
mkdir -p nested/deep
printf 'a\n' > nested/deep/one.txt
printf 'b\n' > nested/deep/two.txt
out=$(bash "$EX" "$tmp/work" 2>"$tmp/err")
check "追跡外のディレクトリの中身を畳まずに数える" \
  "$(printf '%s' "$out" | grep -q 'ほか 2 件' && echo 0 || echo 1)"
rm -rf nested

printf 'another\n' > stray2.txt
out=$(bash "$EX" "$tmp/work" 2>"$tmp/err")
check "2件以上あれば残りの件数を添える" \
  "$(printf '%s' "$out" | grep -q 'ほか 1 件' && echo 0 || echo 1)"
check "件数を添えても1行に収める" \
  "$([ "$(printf '%s\n' "$out" | grep -c .)" -eq 1 ] && echo 0 || echo 1)"
rm -f stray.txt stray2.txt

# ------------------------------ 遅れが 0 でも、競合したまま止まった rebase を名指しする

# 上流を1つ進める。作業側はそれを取り込んだうえで、同じ行に触る枝を rebase する。
printf 'upstream\n' > shared.txt
git commit -qam upstream
git push -q origin main
git switch -q -c side HEAD~1
printf 'side\n' > shared.txt
git commit -qam side
git rebase main >/dev/null 2>&1 || true

behind=$(git rev-list --count HEAD..origin/main)
check "前提: 遅れは 0（競合の検出が遅れに丸まらないことを見る）" \
  "$([ "$behind" = "0" ] && echo 0 || echo 1)"
check "前提: 未解決の衝突が作業ツリーに在る" \
  "$([ -n "$(git diff --name-only --diff-filter=U)" ] && echo 0 || echo 1)"

out=$(bash "$EX" "$tmp/work" 2>"$tmp/err")
check "競合しているファイルを名指しする" \
  "$(printf '%s' "$out" | grep -q 'shared.txt' && echo 0 || echo 1)"
check "未コミットの変更に丸めない" \
  "$(printf '%s' "$out" | grep -q '未コミットの変更' && echo 1 || echo 0)"
check "報告は1行に収める" \
  "$([ "$(printf '%s\n' "$out" | grep -c .)" -eq 1 ] && echo 0 || echo 1)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
