#!/usr/bin/env bash
# このリポジトリを公開したままにしてよいかを機械的に点検する。
#
# 検査は2種類ある。
#
#   構造検査 — 非公開層が無くても動く。成果物や、対象の実体を含むファイル、
#              手元にしか無い値の入った Claude Code の設定が
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

# 2. 非公開層がこのリポジトリの中に置かれていないこと
ops_home="${CLAUDE_OPS_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/claude-ops}"
case "$(cd "$ops_home" 2>/dev/null && pwd -P || printf '%s' "$ops_home")" in
  "$REPO"/*) fail "非公開層が公開リポジトリの中にあります: $ops_home" ;;
  *)         pass "非公開層は公開リポジトリの外にある" ;;
esac

# 3. スケジュールタスクの定義がこのリポジトリの管理範囲に無いこと
#    （タスク名にワークスペース名が現れるため）
if [ -e "$HOME/.claude/scheduled-tasks" ]; then
  if git check-ignore -q "$HOME/.claude/scheduled-tasks" 2>/dev/null \
     || ! printf '%s\n' "$tracked" | grep -q 'scheduled-tasks'; then
    pass "スケジュールタスク定義はこのリポジトリの外にある"
  else
    fail "スケジュールタスク定義が追跡対象に入っています"
  fi
fi

# 4. Claude Code の設定に、手元にしか無い値と非公開の情報が入っていないこと
#    ~/.claude/settings.json はこのリポジトリへのリンクなので、Claude Code が書き込んだ
#    値（ローカルのマーケットプレイス、auto mode の環境の説明）がそのまま差分に出る。
#    非公開リポジトリの名前をここに書かずに済むよう、マーケットプレイスは GitHub に
#    公開リポジトリとして実在するかで判定する。
settings="$REPO/.claude/settings.json"
if [ -f "$settings" ]; then
  if jq -e '.autoMode.environment' "$settings" >/dev/null 2>&1; then
    fail "settings.json に autoMode.environment があります（手元の環境の説明は公開しない）"
  else
    pass "settings.json に autoMode.environment は無い"
  fi

  abs=$(jq -r '.. | strings | select(test("^(/Users/|/home/)"))' "$settings" 2>/dev/null || true)
  if [ -n "$abs" ]; then
    fail "settings.json にローカルの絶対パスがあります"
    printf '%s\n' "$abs" | sed 's/^/      /'
  else
    pass "settings.json にローカルの絶対パスは無い"
  fi

  bad_markets=""
  while IFS=$'\t' read -r name type repo; do
    [ -n "$name" ] || continue
    case "$type" in
      github) ;;
      git)
        repo=$(printf '%s' "$repo" | sed -nE 's#^https://github\.com/([^/]+/[^/]+)$#\1#p' | sed 's/\.git$//')
        ;;
      *) repo="" ;;
    esac
    if [ -z "$repo" ]; then
      bad_markets="$bad_markets $name(GitHub の公開リポジトリではない: $type)"
      continue
    fi
    # 1回のリクエストで本文と HTTP コードを取る。空の配列は bash 3.2 の set -u で
    # 未定義扱いになるので、トークンの有無で curl の呼び方を分ける。
    if [ -n "${GITHUB_TOKEN:-}" ]; then
      resp=$(curl -s -w '\n%{http_code}' -H "Authorization: Bearer $GITHUB_TOKEN" "https://api.github.com/repos/$repo")
    else
      resp=$(curl -s -w '\n%{http_code}' "https://api.github.com/repos/$repo")
    fi
    code=$(printf '%s' "$resp" | tail -n 1)
    if [ "$code" != "200" ]; then
      bad_markets="$bad_markets $name(HTTP $code)"
      continue
    fi
    private=$(printf '%s' "$resp" | sed '$d' | jq -r '.private')
    [ "$private" = "false" ] || bad_markets="$bad_markets $name(非公開)"
  done < <(jq -r '.extraKnownMarketplaces // {} | to_entries[]
      | [.key, .value.source.source, (.value.source.repo // .value.source.url // "")] | @tsv' "$settings")
  if [ -n "$bad_markets" ]; then
    fail "settings.json のマーケットプレイスに、公開リポジトリと確かめられないものがあります:$bad_markets"
  else
    pass "settings.json のマーケットプレイスはすべて GitHub の公開リポジトリ"
  fi
fi

[ -n "$structural_only" ] && { printf '\n判定: %s\n' "$([ "$failures" -eq 0 ] && echo 合格 || echo "不合格 ($failures 件)")"; exit $((failures > 0)); }

# ---------------------------------------------------------------- 導出検査

# 禁止語の導出には ops-cycle のスクリプトを使う。スキルは udus122/skills にあり、
# link.sh が ~/.agents/skills/ に配る。
OPS_SCRIPTS="${OPS_SCRIPTS:-$HOME/.agents/skills/ops-cycle/scripts}"
if [ ! -f "$OPS_SCRIPTS/ops-env.sh" ]; then
  printf '\nops-cycle のスクリプトが無いため導出検査はスキップしました（構造検査のみ実行）: %s\n' "$OPS_SCRIPTS"
  printf '判定: %s\n' "$([ "$failures" -eq 0 ] && echo 合格 || echo "不合格 ($failures 件)")"
  exit $((failures > 0))
fi
. "$OPS_SCRIPTS/ops-env.sh"
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
  done < <("$OPS_SCRIPTS/repos.sh" "$workspace")
done < <("$OPS_SCRIPTS/workspaces.sh")

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
