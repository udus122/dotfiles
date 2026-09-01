#!/usr/bin/env bash
# decisions.sh list が、判断待ちの一覧に何を入れて何を落とすかを点検する。
#
# ラベルが正で、本文の節は付け忘れの受け皿。受け皿の入口を「## 判断待ち」だけに
# すると、棚卸しの報告のように判断待ちの件数を述べただけの Issue が毎晩並ぶ。
# 確認方法が無いので再検証しても判定できず、open のまま件数が減らない。
#
# 逆向きの退行も同じだけ危ない。受け皿を狭めすぎて、ラベルを付け忘れた本物の
# 判断待ちを落とすと、その項目は再検証に一度も掛からないまま残る。
# 落としたものが標準エラーに出ることまで見る。
#
#   tools/test-decisions-list.sh
set -uo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd -P)
DECISIONS_SH="$REPO/.agents/skills/ops-cycle/scripts/decisions.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# 非公開層が無いとスクリプトは no-op で抜ける。テスト専用の層を与える。
# 対象ワークスペースの実体はこのリポジトリに書かない。
mkdir -p "$tmp/ops/state"
printf '{ "knowledge_repo": "owner-mine/knowledge", "issue_owners_allow": ["owner-mine"] }\n' \
  > "$tmp/ops/config.json"

# 起票先を knowledge_repo の 1 件だけにするため、リポジトリを持たない
# ワークスペースを渡す。repos.sh はここから何も導出しない。
mkdir -p "$tmp/ws"

# gh の代役。--label で何を訊かれたかだけを見て、決め打ちの JSON を返す。
# 実物を呼ぶと結果が手元のアカウントに依存し、テストが再現しなくなる。
mkdir -p "$tmp/bin"
cat > "$tmp/bin/gh" <<'STUB'
#!/usr/bin/env bash
for arg in "$@"; do
  case "$arg" in
    needs-decision) cat "$GH_STUB_DIR/labeled.json"; exit 0 ;;
    from-nightly)   cat "$GH_STUB_DIR/bodied.json";  exit 0 ;;
  esac
done
echo '[]'
STUB
chmod +x "$tmp/bin/gh"

cat > "$tmp/labeled.json" <<'JSON'
[
  { "number": 10, "title": "ラベルの付いた本物",
    "url": "https://example.invalid/10", "updatedAt": "2026-09-01T00:00:00Z" }
]
JSON

# 本文は改行を含むので jq で組む。ヒアドキュメントに JSON の生文字列を
# 書くと、\n の書き方を間違えても JSON としては通ってしまう。
jq -n '[
  { number: 10, title: "ラベルの付いた本物",
    url: "https://example.invalid/10", updatedAt: "2026-09-01T00:00:00Z",
    body: "## 判断待ち\n\n- 判断してほしいこと: X\n\n## 解決の確認方法\n\nY を見る\n" },
  { number: 20, title: "ラベルを付け忘れた本物",
    url: "https://example.invalid/20", updatedAt: "2026-09-01T00:00:00Z",
    body: "## 判断待ち\n\n- 判断してほしいこと: X\n\n## 解決の確認方法\n\nY を見る\n" },
  { number: 30, title: "棚卸しの報告。件数を述べただけで確認方法が無い",
    url: "https://example.invalid/30", updatedAt: "2026-09-01T00:00:00Z",
    body: "## 判断待ち\n\n再検証したが、6 件とも前提が成立したままだった。\n" },
  { number: 40, title: "節をどちらも持たないただの Issue",
    url: "https://example.invalid/40", updatedAt: "2026-09-01T00:00:00Z",
    body: "## 何が起きたか\n\n本文だけ。\n" }
]' > "$tmp/bodied.json"

out=$(PATH="$tmp/bin:$PATH" GH_STUB_DIR="$tmp" CLAUDE_OPS_HOME="$tmp/ops" \
        bash "$DECISIONS_SH" list "$tmp/ws" 2>"$tmp/err")
status=$?

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

listed() {  # listed <番号>  一覧に居れば 0
  printf '%s' "$out" | jq -e --argjson n "$1" -s 'any(.[]; .number == $n)' >/dev/null
}

check "呼び出しが成功する" "$([ "$status" -eq 0 ] && echo 0 || echo 1)"

# ---------------------------------------------------------------- 入れるもの

listed 10; check "ラベルの付いた判断待ちは一覧に入る" $?
listed 20; check "ラベルは無いが2節そろった判断待ちは受け皿が拾う" $?

# ---------------------------------------------------------------- 落とすもの

listed 30; check "確認方法の無い報告は一覧に入らない" "$([ $? -ne 0 ] && echo 0 || echo 1)"
listed 40; check "節を持たない Issue は一覧に入らない" "$([ $? -ne 0 ] && echo 0 || echo 1)"

# ------------------------------------------------------- 落としたことを告げる

grep -q '#30' "$tmp/err"
check "落とした Issue の番号を標準エラーに出す" $?

grep -q '#10' "$tmp/err"
check "ラベルで拾えているものを警告に混ぜない" "$([ $? -ne 0 ] && echo 0 || echo 1)"

# ------------------------------------------------------------------ 重複排除

n10=$(printf '%s' "$out" | jq -s '[.[] | select(.number == 10)] | length')
check "ラベルと本文の両方で当たっても 1 件に畳む" "$([ "$n10" = "1" ] && echo 0 || echo 1)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
