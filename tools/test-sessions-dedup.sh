#!/usr/bin/env bash
# sessions.sh prompts の重複除去を、組み立てたトランスクリプトの表で点検する。
#
# セッションを再開すると、ハーネスは親の履歴を新しいセッションのファイルへ
# そのまま引き継ぐ。同じ発話が sessionId 違いで何本も現れるため、除去しないと
# 件数が実際の数倍に膨らむ。件数は週次の「繰り返し現れた指示パターン」と
# 月次の判断の根拠になるので、膨らんだまま通ると誤った結論を出す。
#
# 逆向きの退行も同じだけ危ない。畳みすぎると、人間が意図して繰り返した発話
# （「続けてください」など）が1件に潰れ、頻度が過小に出る。
#
#   tools/test-sessions-dedup.sh
set -uo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd -P)
SESSIONS_SH="$REPO/.agents/skills/ops-cycle/scripts/sessions.sh"

command -v jq >/dev/null 2>&1 || { echo "jq がありません"; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# 非公開層が無いとスクリプトは no-op で抜ける。テスト専用の層を与える。
mkdir -p "$tmp/ops"
printf '{ "knowledge_repo": "owner-mine/knowledge" }\n' > "$tmp/ops/config.json"

mkdir -p "$tmp/ws"
# スクリプトは pwd -P で対象を解決する。macOS の /var は /private/var への
# シンボリックリンクなので、素の $tmp を cwd に書くと突き合わせに落ちる。
WS=$(cd "$tmp/ws" && pwd -P)
PROJECTS="$tmp/home/.claude/projects/proj"
mkdir -p "$PROJECTS"

pass=0
fail=0

# 1行分のユーザ発話を組み立てる。uuid が引き継ぎ後も変わらない値。
row() {  # row <uuid> <sessionId> <timestamp> <本文>
  jq -n -c --arg u "$1" --arg s "$2" --arg t "$3" --arg p "$4" --arg cwd "$WS" '
    {type:"user", uuid:$u, sessionId:$s, timestamp:$t, cwd:$cwd,
     message:{content:$p}}'
}

run() {  # run  → prompts の出力
  HOME="$tmp/home" CLAUDE_OPS_HOME="$tmp/ops" bash "$SESSIONS_SH" prompts "$WS" 0 2>/dev/null
}

check() {  # check <説明> <期待> <実際>
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1))
  else
    printf 'NG   %s\n       期待 %s / 実際 %s\n' "$1" "$2" "$3"
    fail=$((fail + 1))
  fi
}

# 元のセッション。3 件の発話のうち 2 件は本文が同じで時刻が違う
# （人間が意図して繰り返したもの）。
{
  row u1 sess-aaa 2026-08-20T01:00:00.000Z "最初の指示です。長さの下限に届くように少しだけ長く書きます。"
  row u2 sess-aaa 2026-08-20T01:05:00.000Z "続けてください"
  row u3 sess-aaa 2026-08-20T01:09:00.000Z "続けてください"
} > "$PROJECTS/sess-aaa.jsonl"

# 再開したセッション。uuid はそのままで sessionId だけが変わる。
# さらに、再開後に打たれた新しい発話が1件。
{
  row u1 sess-bbb 2026-08-20T01:00:00.000Z "最初の指示です。長さの下限に届くように少しだけ長く書きます。"
  row u2 sess-bbb 2026-08-20T01:05:00.000Z "続けてください"
  row u3 sess-bbb 2026-08-20T01:09:00.000Z "続けてください"
  row u4 sess-bbb 2026-08-20T01:20:00.000Z "再開したあとの新しい指示です。"
} > "$PROJECTS/sess-bbb.jsonl"

# もう一段の再開。同じ履歴をさらに引き継ぐ。
{
  row u1 sess-ccc 2026-08-20T01:00:00.000Z "最初の指示です。長さの下限に届くように少しだけ長く書きます。"
  row u4 sess-ccc 2026-08-20T01:20:00.000Z "再開したあとの新しい指示です。"
} > "$PROJECTS/sess-ccc.jsonl"

out=$(run)

check "引き継がれた発話は uuid で畳まれる（生 9 行 → 4 件）" \
  4 "$(printf '%s\n' "$out" | grep -c .)"

check "本文が同じでも別の発話なら残る（「続けてください」2 件）" \
  2 "$(printf '%s\n' "$out" | jq -r 'select(.prompt == "続けてください") | .prompt' | grep -c .)"

check "出力は ts の昇順" \
  "$(printf '%s\n' "$out" | jq -r .ts | sort -n | tr '\n' ' ')" \
  "$(printf '%s\n' "$out" | jq -r .ts | tr '\n' ' ')"

check "uuid は出力に漏らさない" \
  "prompt sessionId ts" \
  "$(printf '%s\n' "$out" | head -1 | jq -r 'keys | join(" ")')"

# 残す1件を決定的にする。ファイルの読み取り順は find 任せなので、
# 畳んだ結果が実行ごとに変わると、下流の replies が別のセッションを引く。
check "同じ入力なら出力も同じ" "$(run | md5sum 2>/dev/null || run | md5)" "$(run | md5sum 2>/dev/null || run | md5)"

# 重複の無い入力を痩せさせないこと。
rm -f "$PROJECTS/sess-bbb.jsonl" "$PROJECTS/sess-ccc.jsonl"
check "引き継ぎが無ければ件数は変わらない" 3 "$(run | grep -c .)"

# uuid の無い行は畳まない。全部を同じキーに落とすと、数えるためのスクリプトが
# 黙って1件に潰す。いまのトランスクリプトは必ず uuid を持つが、欠けたときに
# 件数が消える壊れ方は出力を見ても気付けない。
rm -f "$PROJECTS/sess-aaa.jsonl"
for i in 1 2 3; do
  jq -n -c --arg s "no-uuid" --arg t "2026-08-20T02:0${i}:00.000Z" \
        --arg p "uuid の無い発話 ${i} 件目。長さの下限に届くように少しだけ長く書きます。" \
        --arg cwd "$WS" '
    {type:"user", sessionId:$s, timestamp:$t, cwd:$cwd, message:{content:$p}}'
done > "$PROJECTS/no-uuid.jsonl"
check "uuid が無くても件数は保たれる" 3 "$(run | grep -c .)"

printf '\n%s 件中 %s 件が期待どおり' "$((pass + fail))" "$pass"
if [ "$fail" -gt 0 ]; then
  printf '（%s 件が不一致）\n' "$fail"
  exit 1
fi
printf '\n'
