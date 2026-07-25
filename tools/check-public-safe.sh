#!/usr/bin/env bash
# このリポジトリを公開したままにしてよいかを機械的に点検する。
#
# 検査は2種類ある。
#
#   構造検査 — 非公開層が無くても動く。成果物や、対象の実体を含むファイルが
#              追跡対象に紛れ込んでいないかを見る。CI はこちらだけを実行する。
#
#   導出検査 — 非公開層があるときだけ動く。禁止語をワークスペースの実体から
#              実行時に組み立てて、追跡ファイルの中身を検査する。
#              禁止語の一覧をこのリポジトリに置かないのは、その一覧自体が
#              公開してはいけない情報だから。
#
#   check-public-safe.sh            両方（非公開層があれば）
#   check-public-safe.sh --structural-only
set -uo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd -P)
cd "$REPO" || exit 1

structural_only=""
[ "${1-}" = "--structural-only" ] && structural_only=1

failures=0
note()  { printf '  %s\n' "$*"; }
fail()  { printf 'NG  %s\n' "$*"; failures=$((failures + 1)); }
pass()  { printf 'OK  %s\n' "$*"; }

tracked=$(git ls-files)

# ---------------------------------------------------------------- 構造検査

# 1. 成果物・目印・スケジュールタスク定義が追跡対象に入っていないこと
leaked_paths=$(printf '%s\n' "$tracked" \
  | grep -E '(^|/)(\.claude-ops|scheduled-tasks)(/|$)|(^|/)(metrics|spool|digests)/' || true)
if [ -n "$leaked_paths" ]; then
  fail "成果物または対象の実体が追跡対象に入っています"
  printf '%s\n' "$leaked_paths" | sed 's/^/      /'
else
  pass "成果物・目印・スケジュールタスク定義は追跡されていない"
fi

# 2. 共有スキルにホーム配下の絶対パスが埋まっていないこと
#    （ユーザ名やワークスペースの位置が漏れるうえ、他のマシンで動かない）
skill_files=$(printf '%s\n' "$tracked" | grep '^\.agents/skills/ops-cycle/' || true)
if [ -n "$skill_files" ]; then
  abs=$(printf '%s\n' "$skill_files" | tr '\n' '\0' \
        | xargs -0 grep -nI '/Users/' 2>/dev/null || true)
  if [ -n "$abs" ]; then
    fail "共有スキルに絶対パスが埋まっています"
    printf '%s\n' "$abs" | sed 's/^/      /'
  else
    pass "共有スキルに絶対パスは無い"
  fi
fi

# 3. 非公開層がこのリポジトリの中に置かれていないこと
ops_home="${CLAUDE_OPS_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/claude-ops}"
case "$(cd "$ops_home" 2>/dev/null && pwd -P || printf '%s' "$ops_home")" in
  "$REPO"/*) fail "非公開層が公開リポジトリの中にあります: $ops_home" ;;
  *)         pass "非公開層は公開リポジトリの外にある" ;;
esac

# 4. スケジュールタスクの定義がこのリポジトリの管理範囲に無いこと
#    （タスク名にワークスペース名が現れるため）
if [ -e "$HOME/.claude/scheduled-tasks" ]; then
  if git check-ignore -q "$HOME/.claude/scheduled-tasks" 2>/dev/null \
     || ! printf '%s\n' "$tracked" | grep -q 'scheduled-tasks'; then
    pass "スケジュールタスク定義はこのリポジトリの外にある"
  else
    fail "スケジュールタスク定義が追跡対象に入っています"
  fi
fi

[ -n "$structural_only" ] && { printf '\n判定: %s\n' "$([ "$failures" -eq 0 ] && echo 合格 || echo "不合格 ($failures 件)")"; exit $((failures > 0)); }

# ---------------------------------------------------------------- 導出検査

. "$REPO/.agents/skills/ops-cycle/scripts/ops-env.sh"
if ! ops_ready; then
  printf '\n非公開層が無いため導出検査はスキップしました（構造検査のみ実行）。\n'
  printf '判定: %s\n' "$([ "$failures" -eq 0 ] && echo 合格 || echo "不合格 ($failures 件)")"
  exit $((failures > 0))
fi

# よくある一般語は禁止語にしない（誤検出だらけになるため）
generic="docs skills web api cli app core tools config scripts infra data shared catalog articles calendar"

allow=$(ops_cfg_list '.redaction_allow' | tr '\n' ' ')
extra=$(ops_cfg_list '.redaction_extra' | tr '\n' ' ')

tokens=""
while IFS= read -r workspace; do
  [ -n "$workspace" ] || continue
  tokens="$tokens $(basename "$workspace")"
  while IFS=$'\t' read -r _entry _real slug _vis _issues; do
    [ -n "${slug:-}" ] || continue
    tokens="$tokens ${slug%%/*} ${slug##*/}"
  done < <("$REPO/.agents/skills/ops-cycle/scripts/repos.sh" "$workspace")
done < <("$REPO/.agents/skills/ops-cycle/scripts/workspaces.sh")

denylist=$(
  printf '%s %s\n' "$tokens" "$extra" | tr ' ' '\n' \
    | sed '/^$/d' | tr '[:upper:]' '[:lower:]' | sort -u \
    | grep -vxF -f <(printf '%s %s\n' "$allow" "$generic" | tr ' ' '\n' | sed '/^$/d')
)

if [ -z "$denylist" ]; then
  pass "禁止語なし（導出結果が空）"
else
  hits=$(printf '%s\n' "$tracked" | tr '\n' '\0' \
         | xargs -0 grep -niIwF -f <(printf '%s\n' "$denylist") 2>/dev/null || true)
  # 追跡ファイルの「パス」にも仕事の名前が出ていないこと
  path_hits=$(printf '%s\n' "$tracked" | grep -iwF -f <(printf '%s\n' "$denylist") || true)
  if [ -n "$hits" ] || [ -n "$path_hits" ]; then
    fail "仕事のプロジェクト名が公開リポジトリに含まれています"
    [ -n "$path_hits" ] && { note "パス:"; printf '%s\n' "$path_hits" | sed 's/^/      /'; }
    [ -n "$hits" ] && { note "内容:"; printf '%s\n' "$hits" | sed 's/^/      /'; }
  else
    pass "仕事のプロジェクト名は含まれていない（禁止語 $(printf '%s\n' "$denylist" | wc -l | tr -d ' ') 件で検査）"
  fi
fi

printf '\n判定: %s\n' "$([ "$failures" -eq 0 ] && echo 合格 || echo "不合格 ($failures 件)")"
exit $((failures > 0))
