#!/usr/bin/env bash
# ワークスペースの実体から、起票先になりうるリポジトリを導出する。
#
# リポジトリの一覧を設定として持たない。ワークスペース直下のエントリを
# 解決して git リポジトリかどうかを見るだけなので、リポジトリを追加しても
# 設定の更新は要らない。
#
# 出力は TSV: entry <TAB> realpath <TAB> owner/repo <TAB> public|private|unknown <TAB> issues|no-issues
#
#   repos.sh <workspace>            すべて
#   repos.sh <workspace> --issuable 起票先として使えるものだけ
set -uo pipefail
. "$(dirname "$0")/ops-env.sh"
ops_ready || exit 0
ops_dirs

workspace="${1:?usage: repos.sh <workspace> [--issuable]}"
issuable_only="${2-}"
cache="$CLAUDE_OPS_HOME/state/repos.json"
ttl=86400
now=$(date +%s)

[ -r "$cache" ] || printf '{}\n' > "$cache"

# git remote の URL から owner/repo を取り出す
slug_from_url() {
  printf '%s' "$1" \
    | sed -e 's|\.git$||' \
          -e 's|^git@[^:]*:||' \
          -e 's|^ssh://[^/]*/||' \
          -e 's|^https\{0,1\}://[^/]*/||'
}

# owner/repo のメタ情報を取る。24 時間キャッシュする。
# 出力: nameWithOwner <TAB> public|private|unknown <TAB> issues|no-issues
repo_meta() {
  local slug="$1" cached age meta
  cached=$(jq -c --arg k "$slug" '.[$k] // empty' "$cache" 2>/dev/null)
  if [ -n "$cached" ]; then
    age=$(( now - $(printf '%s' "$cached" | jq -r '.ts // 0') ))
    if [ "$age" -lt "$ttl" ]; then
      printf '%s' "$cached" | jq -r '[.nameWithOwner, .visibility, .issues] | @tsv'
      return 0
    fi
  fi

  meta=$(gh repo view "$slug" --json nameWithOwner,isPrivate,hasIssuesEnabled 2>/dev/null)
  if [ -z "$meta" ]; then
    # remote が解決しない（アーカイブ済み・リネーム済み・権限なし）
    meta=$(jq -nc --arg s "$slug" \
      '{nameWithOwner: $s, visibility: "unknown", issues: "no-issues"}')
  else
    meta=$(printf '%s' "$meta" | jq -c '{
      nameWithOwner,
      visibility: (if .isPrivate then "private" else "public" end),
      issues: (if .hasIssuesEnabled then "issues" else "no-issues" end)
    }')
  fi

  meta=$(printf '%s' "$meta" | jq -c --argjson ts "$now" '. + {ts: $ts}')
  jq --arg k "$slug" --argjson v "$meta" '.[$k] = $v' "$cache" > "$cache.tmp" \
    && mv "$cache.tmp" "$cache"
  printf '%s' "$meta" | jq -r '[.nameWithOwner, .visibility, .issues] | @tsv'
}

# 起票してよい所有者か。一覧は非公開層が持つ（自分の名前空間の一覧は公開しない）。
# 一覧が空のときは誰にも起票しない側に倒す。他人のリポジトリに書き込む事故を防ぐため。
owners_allow=$(ops_cfg_list '.issue_owners_allow')
owner_allowed() {
  [ -n "$owners_allow" ] || return 1
  printf '%s\n' "$owners_allow" | grep -qxF "$1"
}

emit() {
  local entry="$1" real="$2" url slug meta canonical
  url=$(git -C "$real" remote get-url origin 2>/dev/null) || return 0
  [ -n "$url" ] || return 0
  slug=$(slug_from_url "$url")
  meta=$(repo_meta "$slug")
  if [ "$issuable_only" = "--issuable" ]; then
    case "$meta" in *"	no-issues") return 0 ;; esac
    case "$meta" in *"	unknown	"*) return 0 ;; esac
    # リネームや transfer で所有者が変わることがあるので、正規化後の所有者で見る
    canonical=${meta%%	*}
    owner_allowed "${canonical%%/*}" || return 0
  fi
  printf '%s\t%s\t%s\n' "$entry" "$real" "$meta"
}

# ワークスペース自体がリポジトリの場合（knowledge / dotfiles）
if [ "$(git -C "$workspace" rev-parse --show-toplevel 2>/dev/null)" = "$(cd "$workspace" && pwd -P)" ]; then
  emit "." "$(cd "$workspace" && pwd -P)"
fi

# 直下のエントリ（symlink を含む）を解決する
find "$workspace" -maxdepth 1 -mindepth 1 \( -type d -o -type l \) 2>/dev/null \
| while IFS= read -r entry; do
    name=$(basename "$entry")
    case "$name" in .*) continue ;; esac
    real=$(cd "$entry" 2>/dev/null && pwd -P) || continue
    # そのディレクトリ自身がリポジトリの root であるものだけを対象にする
    [ "$(git -C "$real" rev-parse --show-toplevel 2>/dev/null)" = "$real" ] || continue
    emit "$name" "$real"
  done
