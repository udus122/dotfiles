#!/usr/bin/env bash
# 知識ベースへ渡す草案の受け渡し口。
#
# 夜間は複数のワークスペースのルーティンがほぼ同時に走りうる（スリープ復帰時は
# まとめて発火する）。そこで知識ベースのリポジトリに触れるのは1つのルーティンだけに
# 限り、他は全員ここに置くだけにする。単一 writer なので競合しない。
#
#   spool.sh put <slug> [date]     標準入力の内容を草案として置く（同名は上書き = 冪等）
#   spool.sh list                  未回収の草案を一覧する
#   spool.sh drain <dest_root>     草案を dest_root/journals/daily/<date>/ へ移し、移した先を出す
set -uo pipefail
. "$(dirname "$0")/ops-env.sh"
ops_ready || exit 0
ops_dirs

SPOOL="$CLAUDE_OPS_HOME/spool/knowledge"
LOCK="$CLAUDE_OPS_HOME/locks/spool-knowledge"

cmd="${1:?usage: spool.sh <put|list|drain> ...}"
shift

acquire_lock() {
  local waited=0
  # 10 分以上前のロックは、落ちた実行の置き土産とみなして捨てる
  if [ -d "$LOCK" ] && [ -z "$(find "$LOCK" -maxdepth 0 -mmin -10 2>/dev/null)" ]; then
    rmdir "$LOCK" 2>/dev/null || true
  fi
  while ! mkdir "$LOCK" 2>/dev/null; do
    waited=$((waited + 1))
    [ "$waited" -gt 60 ] && { echo "spool のロックを取得できませんでした" >&2; exit 1; }
    sleep 1
  done
  trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT
}

case "$cmd" in
  put)
    slug="${1:?slug required}"
    date_part="${2:-$(date +%F)}"
    # ファイル名として危ない文字だけを落とす。
    # 固有名詞に日本語を使うことがあるので、非 ASCII はそのまま残す。
    slug=$(printf '%s' "$slug" \
      | sed -e 's#[/\\:]#-#g' -e 's/[[:space:]]\{1,\}/-/g' \
            -e 's/-\{2,\}/-/g' -e 's/^-*//' -e 's/-*$//')
    [ -n "$slug" ] || { echo "slug が空です" >&2; exit 2; }
    dest="$SPOOL/$date_part--$slug.md"
    cat > "$dest"
    printf '%s\n' "$dest"
    ;;

  list)
    find "$SPOOL" -maxdepth 1 -name '*.md' -type f 2>/dev/null | sort
    ;;

  drain)
    dest_root="${1:?dest root required}"
    acquire_lock
    find "$SPOOL" -maxdepth 1 -name '*.md' -type f 2>/dev/null | sort | while IFS= read -r draft; do
      base=$(basename "$draft" .md)
      date_part="${base%%--*}"
      slug="${base#*--}"
      case "$date_part" in
        [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) : ;;
        *) date_part=$(date +%F); slug="$base" ;;
      esac
      target_dir="$dest_root/journals/daily/$date_part"
      mkdir -p "$target_dir"
      mv "$draft" "$target_dir/$slug.md"
      printf '%s\n' "$target_dir/$slug.md"
    done
    ;;

  *)
    echo "unknown subcommand: $cmd" >&2
    exit 2
    ;;
esac
