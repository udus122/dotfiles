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

CLAUDE_OPS_HOME="$CLAUDE_OPS_HOME" OPS_SQL="$sql" OPS_FORMAT="$format" \
uvx --quiet --from duckdb python - <<'PY'
import os, pathlib, duckdb

metrics = pathlib.Path(os.environ["CLAUDE_OPS_HOME"]) / "metrics"
views = {
    "instructions": "instructions.jsonl",
    "knowledge_refs": "knowledge-refs.jsonl",
    "skills": "skills.jsonl",
    "issues": "issues.jsonl",
}

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
        # ログがまだ無くてもクエリが落ちないよう、空のビューを置く
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
