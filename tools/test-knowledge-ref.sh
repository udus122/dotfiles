#!/usr/bin/env bash
# 参照計測のフックを、代表的なツール呼び出しの表で点検する。
#
# このフックが拾い損ねても出力は「参照が無かった」と同じ形になり、月次は
# それを実データとして失効判定に使う。壊れたことに気付く手段がここしかない。
#
# 逆向きの退行も同じだけ危ない。パスでない語をパスと読むと、実在しない概念が
# 参照済みとして積まれ、失効候補から漏れる。
#
#   tools/test-knowledge-ref.sh
set -uo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd -P)
HOOK="$REPO/.claude/hooks/ops-log-knowledge-ref.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# 知識ベースの実体はこのリポジトリに書かない。テスト専用の根を与える。
ROOT="$tmp/kb"
mkdir -p "$ROOT" "$tmp/ops"
printf '{ "knowledge_root": "%s" }\n' "$ROOT" > "$tmp/ops/config.json"

pass=0
fail=0

# フックが書いた行から path 列だけを取り出す。実装と同じ手を使うと
# 両方が同時に壊れたとき気付けないので、独立に書く。
run() {  # run <イベント JSON> → 記録された path を改行区切りで返す
  mkdir -p "$tmp/ops/metrics"
  : > "$tmp/ops/metrics/knowledge-refs.jsonl"
  printf '%s' "$1" | CLAUDE_OPS_HOME="$tmp/ops" HOME="${FAKE_HOME:-$HOME}" bash "$HOOK"
  sed -n 's/.*"path":"\([^"]*\)".*/\1/p' "$tmp/ops/metrics/knowledge-refs.jsonl"
}

check() {  # check <期待する path を改行区切り（無いときは空）> <説明> <イベント JSON>
  local expect="$1" desc="$2" event="$3" got
  got=$(run "$event")
  if [ "$got" = "$expect" ]; then
    pass=$((pass + 1))
  else
    printf 'NG   %s\n       期待 [%s] / 実際 [%s]\n' "$desc" "$expect" "$got"
    fail=$((fail + 1))
  fi
}

bash_event() {  # bash_event <cwd> <command>
  jq -nc --arg cwd "$1" --arg cmd "$2" \
    '{session_id:"s", cwd:$cwd, tool_name:"Bash", tool_input:{command:$cmd}}'
}

read_event() {  # read_event <file_path>
  jq -nc --arg p "$1" \
    '{session_id:"s", cwd:"/anywhere", tool_name:"Read", tool_input:{file_path:$p}}'
}

# -------------------------------------------------- パスを持つツール（従来の経路）

check "notes/a.md" "Read は file_path をそのまま記録する" \
  "$(read_event "$ROOT/notes/a.md")"

check "" "知識ベースの外の Read は記録しない" \
  "$(read_event "/etc/hosts")"

# -------------------------------------------------- Bash（今回拾えるようにした経路）

check "journals/daily/2026-08-25/x.md" "cwd が知識ベースなら相対パスを解決する" \
  "$(bash_event "$ROOT" "head -12 journals/daily/2026-08-25/x.md")"

check "notes/a.md" "絶対パスを拾う" \
  "$(bash_event "/elsewhere" "cat $ROOT/notes/a.md")"

# ~ の展開は $HOME が絡むので、根を $HOME 配下に置ける差し替えの下で確かめる。
FAKE_HOME="$tmp" \
  check "notes/a.md" '~ を展開して拾う' \
    "$(bash_event "/elsewhere" "cat ~/kb/notes/a.md")"

FAKE_HOME="$tmp" \
  check "notes/a.md" '$HOME を展開して拾う' \
    "$(bash_event "/elsewhere" "cat \$HOME/kb/notes/a.md")"

check "journals/daily/2026-08-25/*.md" "グロブもそのまま記録する" \
  "$(bash_event "$ROOT" "head -12 journals/daily/2026-08-25/*.md")"

check "notes/a.md" "同じコマンドに複数回現れても1行にする" \
  "$(bash_event "$ROOT" "diff notes/a.md notes/a.md")"

check "notes/a.md
notes/b.md" "1コマンドの複数のパスをそれぞれ記録する" \
  "$(bash_event "$ROOT" "cat notes/b.md notes/a.md")"

# -------------------------------------------------- 拾ってはいけないもの

check "" "知識ベースの外の Bash は記録しない" \
  "$(bash_event "/elsewhere" "cat notes/a.md")"

check "" "スラッシュを含むだけの語をパスと読まない" \
  "$(bash_event "$ROOT" "sed -i '' 's/before/after/' README.rst")"

check "" ".md 以外は拾わない" \
  "$(bash_event "$ROOT" "cat config.json")"

check "" "知識ベースの根そのものは概念ではないので記録しない" \
  "$(bash_event "/elsewhere" "ls $ROOT")"

check "" "パスを持たない Grep を cwd への参照と読み替えない" \
  "$(jq -nc --arg cwd "$ROOT/notes" \
      '{session_id:"s", cwd:$cwd, tool_name:"Grep", tool_input:{pattern:"foo"}}')"

check "" "根の名前を接頭辞に持つ別のディレクトリを取り込まない" \
  "$(read_event "$ROOT-archive/notes/a.md")"

# -------------------------------------------------- 非公開層が無いとき

: > "$tmp/ops/metrics/knowledge-refs.jsonl"
rm -f "$tmp/ops/config.json"
printf '%s' "$(read_event "$ROOT/notes/a.md")" | CLAUDE_OPS_HOME="$tmp/ops" bash "$HOOK"
if [ -s "$tmp/ops/metrics/knowledge-refs.jsonl" ]; then
  printf 'NG   非公開層が無ければ何も書かない\n'
  fail=$((fail + 1))
else
  pass=$((pass + 1))
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
