#!/usr/bin/env bash
# requirements-japanese の回帰テスト。natural-japanese を更新したあとと、meaning_lint.py を変えたあとに実行する。
#
#   1. natural-japanese の参照先(SKILL.md・lint.py・diagnose.md・doctypes/)がある
#   2. natural-japanese の lint の回帰テスト(dev/check-fixtures.sh)が通る
#   3. スライドの5例文すべてに meaning_lint の指摘が出る
#   4. natural-japanese の自然な文書(fixtures/natural.md)で meaning_lint の指摘が0件
#   5. 要件定義書サンプルの要件本文で critical が0件、装飾を入れた要件本文では critical が出る

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NJ_DIR="${NATURAL_JAPANESE_DIR:-${HOME}/.claude/skills/natural-japanese}"
LINT="${SKILL_DIR}/scripts/meaning_lint.py"
FIXTURES="${SKILL_DIR}/scripts/fixtures"
failures=0

pass() { echo "ok   $1"; }
fail() { echo "FAIL $1"; failures=$((failures + 1)); }

meaning_json() { uv run -q "${LINT}" --json "$1"; }

# 1
for path in SKILL.md scripts/lint.py references/diagnose.md references/doctypes; do
  if [[ -e "${NJ_DIR}/${path}" ]]; then pass "natural-japanese/${path} がある"; else fail "natural-japanese/${path} がない"; fi
done

# 2
NJ_REPO="$(cd "${NJ_DIR}" && git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -n "${NJ_REPO}" && -x "${NJ_REPO}/dev/check-fixtures.sh" ]]; then
  if "${NJ_REPO}/dev/check-fixtures.sh" >/dev/null 2>&1; then pass "natural-japanese の check-fixtures.sh"; else fail "natural-japanese の check-fixtures.sh"; fi
else
  fail "natural-japanese の clone が見つからない(dev/check-fixtures.sh を実行できない)"
fi

# 3
uncovered="$(meaning_json "${FIXTURES}/slide-examples.md" | python3 -I -c '
import json, sys
lines = {f["line"] for f in json.load(sys.stdin)["findings"]}
print(",".join(str(n) for n in (7, 9, 11, 13, 15) if n not in lines))
')"
if [[ -z "${uncovered}" ]]; then pass "スライドの5例文すべてに指摘が出る"; else fail "指摘の出ない例文がある(L${uncovered})"; fi

# 4
count="$(meaning_json "${NJ_DIR}/scripts/fixtures/natural.md" | python3 -I -c 'import json,sys; print(len(json.load(sys.stdin)["findings"]))')"
if [[ "${count}" == "0" ]]; then pass "natural.md で誤検出0件"; else fail "natural.md で ${count} 件検出"; fi

# 5
count="$(meaning_json "${FIXTURES}/requirements-sample.md" | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["stats"]["requirement_critical"])')"
if [[ "${count}" == "0" ]]; then pass "要件定義書サンプルの要件本文で critical 0件"; else fail "要件定義書サンプルの要件本文で critical ${count} 件"; fi

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
printf '%s\n' "- FR-99 判断に迷う明細は、残さない側に倒すこと。" > "${tmp}/decorated.md"
count="$(meaning_json "${tmp}/decorated.md" | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["stats"]["requirement_critical"])')"
if [[ "${count}" != "0" ]]; then pass "装飾を入れた要件本文で critical が出る"; else fail "装飾を入れた要件本文で critical が出ない"; fi

if [[ "${failures}" -gt 0 ]]; then
  echo "${failures} 件失敗"
  exit 1
fi
echo "すべて成功"
