#!/usr/bin/env bash
# 走査対象の root を目印の有無で走査し、ワークスペースの絶対パスを1行ずつ出す。
#
# 一覧を設定として持たない。ワークスペースを追加するには、
# その直下に .claude-ops/workspace.json を置くだけでよい。
#
#   workspaces.sh              すべてのワークスペース
#   workspaces.sh <layer>      その層を有効にしているワークスペースだけ
set -uo pipefail
. "$(dirname "$0")/ops-env.sh"
ops_ready || exit 0

layer="${1-}"

while IFS= read -r root; do
  [ -n "$root" ] || continue
  expanded=$(ops_expand "$root")
  [ -d "$expanded" ] || continue
  find "$expanded" -maxdepth "$(ops_cfg '.scan_depth' 2)" \
    -type d -name .claude-ops -print 2>/dev/null
done < <(ops_cfg_list '.scan_roots') \
| while IFS= read -r marker; do
    [ -r "$marker/workspace.json" ] || continue
    workspace=$(dirname "$marker")
    if [ -n "$layer" ]; then
      jq -e --arg l "$layer" '(.layers // []) | index($l)' \
        "$marker/workspace.json" >/dev/null 2>&1 || continue
    fi
    printf '%s\n' "$workspace"
  done \
| sort -u
