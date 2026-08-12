#!/usr/bin/env bash
# spool.sh put の generator 補完を、代表的な草案の表で点検する。
#
# 週次は `type: capture` かつ `generator: ops-daily` を消化の対象にする。
# 欠けたまま着地した草案は手書きの知見と見なされ、昇格も削除もされずに残り続ける。
# 壊れても出力は正常に見えるので、退行に気付く手段がここしかない。
#
# 逆向きの退行も同じだけ危ない。すでにある generator を上書きすると、
# worklog-report の日報のような別の生成物が週次の書き換え対象に入る。
#
#   tools/test-spool-put.sh
set -uo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd -P)
SPOOL_SH="$REPO/.agents/skills/ops-cycle/scripts/spool.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# 非公開層が無いとスクリプトは no-op で抜ける。テスト専用の層を与える。
# 対象ワークスペースの実体はこのリポジトリに書かない。
mkdir -p "$tmp/ops"
printf '{ "knowledge_repo": "owner-mine/knowledge" }\n' > "$tmp/ops/config.json"

pass=0
fail=0
n=0

# frontmatter の中の generator だけを取り出す。
# 実装と同じ手を使うと両方が同時に壊れたとき気付けないので、独立に書く。
generator_of() {  # generator_of <file>
  awk '
    NR == 1 { if ($0 != "---") exit; next }
    /^---[[:space:]]*$/ { exit }
    /^generator:/ { sub(/^generator:[[:space:]]*/, ""); print; exit }
  ' "$1"
}

check() {  # check <期待する generator（無いときは -）> <subdir> <説明>  本文は標準入力
  local expect="$1" subdir="$2" desc="$3" dest got
  n=$((n + 1))
  dest=$(CLAUDE_OPS_HOME="$tmp/ops" bash "$SPOOL_SH" put "case-$n" 2026-08-12 "$subdir" 2>/dev/null)
  if [ ! -f "$dest" ]; then
    printf 'ERR  %s\n       草案が置かれていません\n' "$desc"
    fail=$((fail + 1))
    return
  fi
  got=$(generator_of "$dest")
  [ -n "$got" ] || got="-"
  if [ "$got" = "$expect" ]; then
    pass=$((pass + 1))
  else
    printf 'NG   %s\n       期待 %s / 実際 %s\n' "$desc" "$expect" "$got"
    fail=$((fail + 1))
  fi
}

# ------------------------------------------------------------------ 補うもの

check ops-daily daily "generator が無ければ置き場から導いて補う" <<'EOF'
---
type: capture
title: テスト
created: 2026-08-12
---

本文
EOF

check ops-weekly weekly "週次の置き場には ops-weekly を補う" <<'EOF'
---
type: capture
created: 2026-08-12
---

本文
EOF

check ops-daily daily "本文の --- を frontmatter の終端と読み違えない" <<'EOF'
---
type: capture
created: 2026-08-12
---

本文

---

続き
EOF

check ops-daily daily "本文の generator: 行を frontmatter の指定と読み違えない" <<'EOF'
---
type: capture
created: 2026-08-12
---

generator: これは本文の記述
EOF

# ------------------------------------------------------------ 触らないもの

check worklog-report daily "すでにある generator は上書きしない" <<'EOF'
---
type: capture
generator: worklog-report
created: 2026-08-12
---

本文
EOF

check - daily "frontmatter が無い草案には足さない" <<'EOF'
# 見出しだけの草案

本文
EOF

check - daily "閉じていない frontmatter には足さない" <<'EOF'
---
type: capture
created: 2026-08-12

本文
EOF

# ------------------------------------------------ 冪等性と、既存の出力の契約

idem="$tmp/idem"
mkdir -p "$idem"
for _ in 1 2; do
  printf -- '---\ntype: capture\ncreated: 2026-08-12\n---\n\n本文\n' \
    | CLAUDE_OPS_HOME="$tmp/ops" bash "$SPOOL_SH" put idem 2026-08-12 >"$idem/out" 2>/dev/null
done
dest=$(cat "$idem/out")
count=$(grep -c '^generator:' "$dest")
if [ "$count" = "1" ]; then
  pass=$((pass + 1))
else
  printf 'NG   同じ slug で置き直しても generator は1行\n       期待 1 / 実際 %s\n' "$count"
  fail=$((fail + 1))
fi

# put の標準出力は置き場のパス1行だけ。呼び出し側がこれを読む。
# 補完の知らせが標準出力へ混ざると、そのまま呼び出し側のパスとして扱われる。
lines=$(wc -l < "$idem/out" | tr -d ' ')
if [ "$lines" = "1" ] && [ -f "$dest" ]; then
  pass=$((pass + 1))
else
  printf 'NG   put の標準出力が置き場のパス1行になっていない: %s\n' "$dest"
  fail=$((fail + 1))
fi

printf '\n%s 件中 %s 件が期待どおり' "$((pass + fail))" "$pass"
if [ "$fail" -gt 0 ]; then
  printf '（%s 件が不一致）\n' "$fail"
  exit 1
fi
printf '\n'
