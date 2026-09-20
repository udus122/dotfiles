#!/usr/bin/env bash
# 計測ログ (JSONL) を SQL で集計する。
#
# 使えるビュー: instructions / knowledge_refs / skills / issues
# issues は repo 列を持つので、複数リポジトリにまたがる Issue も横断できる。
#
#   query.sh "SELECT repo, count(*) FROM issues GROUP BY 1 ORDER BY 2 DESC"
#   query.sh --format csv "SELECT * FROM instructions LIMIT 5"
set -uo pipefail
. "$(dirname "$0")/ops-env.sh"
ops_ready || exit 0

format="table"
if [ "${1-}" = "--format" ]; then format="${2:?}"; shift 2; fi
sql="${1:?usage: query.sh [--format csv|json|table] <SQL>}"

# ビュー名とログの対応。bash の警告と Python のビュー生成が同じ表を読む。
# 2か所に分けて書くと、片方だけに増えたビューが黙って空のまま集計に入る。
OPS_VIEWS='instructions:instructions.jsonl
knowledge_refs:knowledge-refs.jsonl
skills:skills.jsonl
issues:issues.jsonl'

# ログが無い、または空のビューを名指しする。
#
# 空のビューを置くこと自体は続ける（クエリが落ちると集計そのものが止まるため）。
# 黙って置くのをやめる。記録が途切れていることと、その条件に当てはまる行が
# 本当に無いことは、集計の出力からは区別が付かない。実際に 2026-08 の月次は
# skills.jsonl が配られていない状態で 0 件を受け取り、「使われていないスキル」を
# 実績から出せないまま棚卸しを1か月ぶん進めている。
missing=""
while IFS=: read -r view filename; do
  [ -n "$view" ] || continue
  path="$CLAUDE_OPS_HOME/metrics/$filename"
  if [ ! -s "$path" ]; then
    if [ -e "$path" ]; then
      missing="$missing
  $view — $path が空"
    else
      missing="$missing
  $view — $path が無い"
    fi
  fi
done <<VIEWS
$OPS_VIEWS
VIEWS

if [ -n "$missing" ]; then
  printf '計測ログが無いため、空のビューで代用したものがあります:%s\n' "$missing" >&2
  printf 'これらのビューが返す 0 件は、記録が無いことであって、該当が無いことではありません。\n' >&2
fi

CLAUDE_OPS_HOME="$CLAUDE_OPS_HOME" OPS_SQL="$sql" OPS_FORMAT="$format" OPS_VIEWS="$OPS_VIEWS" \
uvx --quiet --from duckdb python - <<'PY'
import os, pathlib, duckdb

metrics = pathlib.Path(os.environ["CLAUDE_OPS_HOME"]) / "metrics"
views = dict(
    line.split(":", 1)
    for line in os.environ["OPS_VIEWS"].splitlines()
    if line.strip()
)

con = duckdb.connect()
for view, filename in views.items():
    path = metrics / filename
    if path.exists() and path.stat().st_size > 0:
        # CREATE VIEW はプリペアドパラメータを受け付けないのでリテラルに埋める
        literal = str(path).replace("'", "''")
        con.execute(
            f"CREATE VIEW {view} AS "
            f"SELECT * FROM read_json_auto('{literal}', union_by_name=true)"
        )
    else:
        # ログがまだ無くてもクエリが落ちないよう、空のビューを置く。
        # 代用したことは呼び出し側が標準エラーに出している。
        con.execute(f"CREATE VIEW {view} AS SELECT NULL AS ts WHERE false")

result = con.sql(os.environ["OPS_SQL"])
fmt = os.environ["OPS_FORMAT"]
if fmt == "csv":
    print(",".join(result.columns))
    for row in result.fetchall():
        print(",".join("" if v is None else str(v) for v in row))
elif fmt == "json":
    import json
    for row in result.fetchall():
        print(json.dumps(dict(zip(result.columns, row)), default=str, ensure_ascii=False))
else:
    result.show()
PY
