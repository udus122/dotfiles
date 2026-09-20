#!/usr/bin/env bash
# query.sh が、計測ログを空のビューで代用したことを名指しするかを点検する。
#
# 代用そのものは正しい（クエリが落ちると集計が止まる）。危ないのは黙って置くこと。
# 記録が途切れていて 0 件なのか、条件に当てはまる行が本当に無くて 0 件なのかは、
# 集計の出力からは区別が付かない。2026-08 の月次は skills.jsonl が配られていない
# 状態で 0 件を受け取り、「使われていないスキル」を実績から出せないまま
# 棚卸しを1か月ぶん進めている。退行するとこの取り違えがそのまま戻る。
#
# ビュー名とログの対応は bash から環境変数で Python へ渡るので、警告だけを見ても
# 足りない。対応表が Python に届いてビューの作り分けに使われたところまで見る。
# duckdb は CI に無いため、記録だけを取る差し替えを PYTHONPATH に置いて
# 実際の Python 本体を走らせる。差し替えるのは duckdb であって query.sh ではない。
#
#   tools/test-query-missing-log.sh
set -uo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd -P)
QUERY_SH="$REPO/.agents/skills/ops-cycle/scripts/query.sh"

command -v python3 >/dev/null 2>&1 || { echo "python3 が無い" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# 非公開層が無いとスクリプトは no-op で抜ける。テスト専用の層を与える。
mkdir -p "$tmp/ops/metrics" "$tmp/bin" "$tmp/fake"
printf '{ "knowledge_repo": "owner-mine/knowledge" }\n' > "$tmp/ops/config.json"

# 実行された SQL を書き出すだけの duckdb。
cat > "$tmp/fake/duckdb.py" <<'FAKE'
import os

LOG = os.environ["OPS_SQL_LOG"]


def _record(text):
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(text.replace("\n", " ") + "\n")


class _Result:
    columns = ["n"]

    def fetchall(self):
        return [(0,)]

    def show(self):
        print("stub")


class _Connection:
    def execute(self, sql):
        _record("EXECUTE " + sql)

    def sql(self, query):
        _record("SQL " + query)
        return _Result()


def connect(*args, **kwargs):
    return _Connection()
FAKE

# query.sh は `uvx --quiet --from duckdb python - <<PY` を呼ぶ。
# 引数を捨てて、本体を標準入力から python3 に渡す。
cat > "$tmp/bin/uvx" <<STUB
#!/usr/bin/env bash
exec env PYTHONPATH="$tmp/fake" python3 -
STUB
chmod +x "$tmp/bin/uvx"

pass=0
fail=0

ok()   { echo "ok: $1"; pass=$((pass + 1)); }
bad()  { echo "FAIL: $1"; fail=$((fail + 1)); }

run() {  # run <format> — 標準エラーを $err に、実行された SQL を $sqllog に残す
  : > "$tmp/sql.log"
  err=$(PATH="$tmp/bin:$PATH" CLAUDE_OPS_HOME="$tmp/ops" OPS_SQL_LOG="$tmp/sql.log" \
          "$QUERY_SH" --format "${1:-csv}" "SELECT 1" 2>&1 >/dev/null)
  rc=$?
  sqllog=$(cat "$tmp/sql.log" 2>/dev/null)
}

names() {  # names <説明> <語>...
  local desc="$1"; shift
  local missing=""
  for word in "$@"; do
    printf '%s' "$err" | grep -q -- "$word" || missing="$missing $word"
  done
  if [ -n "$missing" ]; then
    bad "$desc — 標準エラーに$missing が無い"
    printf '%s\n' "$err" | sed 's/^/    /'
  else
    ok "$desc"
  fi
}

# --- 1. ログが1つも無い ---------------------------------------------------
run csv
[ "$rc" -eq 0 ] && ok "ログが無くても終了コードは 0" \
  || bad "ログが無いと終了コードが ${rc}（集計そのものが止まる）"
names "4 つのビューをすべて名指しする" instructions knowledge_refs skills issues
names "0 件の意味が読み手に伝わる" "記録が無いこと"

# 対応表が Python に届いていること。届かなければビューが1つも作られない。
# 判定は1回だけ出す。欠けたビューを FAIL したあとに「4 つとも作られた」を
# 続けて出すと、黙って代用することを責めるテストの出力自体が食い違う。
absent=""
for view in instructions knowledge_refs skills issues; do
  printf '%s' "$sqllog" | grep -qF "CREATE VIEW $view AS SELECT NULL AS ts WHERE false" \
    || absent="$absent $view"
done
if [ -n "$absent" ]; then
  bad "空ビューが作られていない:${absent}（対応表が Python に届いていない）"
else
  ok "対応表が Python に届き、4 つとも空ビューで作られた"
fi

# --- 2. 空ファイルも代用に入る -------------------------------------------
: > "$tmp/ops/metrics/skills.jsonl"
run csv
names "空のログも代用として名指しする" "が空"

# --- 3. 中身があるビューは代用しない -------------------------------------
printf '{"ts":"2026-09-21T00:00:00Z","skill":"ops-cycle"}\n' > "$tmp/ops/metrics/skills.jsonl"
run csv
if printf '%s' "$err" | grep -qE '^  skills — '; then
  bad "中身のあるログを代用として名指しした"
else
  ok "中身のあるログは名指ししない"
fi
if printf '%s' "$sqllog" | grep -qF "CREATE VIEW skills AS SELECT * FROM read_json_auto("; then
  ok "中身のあるログは read_json_auto で読む"
else
  bad "中身のあるログが read_json_auto になっていない"
  printf '%s\n' "$sqllog" | sed 's/^/    /'
fi

# --- 4. すべてそろえば警告は出ない ---------------------------------------
for f in instructions.jsonl knowledge-refs.jsonl issues.jsonl; do
  printf '{"ts":"2026-09-21T00:00:00Z"}\n' > "$tmp/ops/metrics/$f"
done
run csv
if printf '%s' "$err" | grep -q '空のビューで代用'; then
  bad "代用が無いのに警告が出た"
else
  ok "すべてそろえば警告は出ない"
fi
[ "$rc" -eq 0 ] && ok "そろっているときの終了コードは 0" \
  || bad "そろっているのに終了コードが $rc"

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
