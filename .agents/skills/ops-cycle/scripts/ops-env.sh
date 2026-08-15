#!/usr/bin/env bash
# 非公開設定層を解決する。他のスクリプトから source して使う。
#
# この層が存在しない環境（このリポジトリ単体を clone した直後など）でも
# エラーにならず、各ヘルパが no-op を返すことを保証する。
# 対象ワークスペースやリポジトリの実体はすべてこの層にあり、公開側には無い。

[ -n "${OPS_ENV_SOURCED:-}" ] && return 0
OPS_ENV_SOURCED=1

CLAUDE_OPS_HOME="${CLAUDE_OPS_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/claude-ops}"
OPS_CONFIG="$CLAUDE_OPS_HOME/config.json"

# 非公開層が使えるか
ops_ready() { [ -r "$OPS_CONFIG" ]; }

# 先頭の ~ を展開する
ops_expand() {
  case "$1" in
    "~")   printf '%s' "$HOME" ;;
    "~/"*) printf '%s/%s' "$HOME" "${1#\~/}" ;;
    *)     printf '%s' "$1" ;;
  esac
}

# ops_cfg <jq フィルタ> [既定値]
ops_cfg() {
  local value=""
  if ops_ready; then
    value=$(jq -r "$1 // empty" "$OPS_CONFIG" 2>/dev/null)
  fi
  printf '%s' "${value:-${2-}}"
}

# ops_cfg_list <jq フィルタ> — 配列を1行ずつ出す
ops_cfg_list() {
  ops_ready || return 0
  jq -r "$1 // [] | .[]" "$OPS_CONFIG" 2>/dev/null
}

# 成果物の置き場を用意する（非公開層が無ければ何もしない）
ops_dirs() {
  ops_ready || return 0
  mkdir -p \
    "$CLAUDE_OPS_HOME/metrics" \
    "$CLAUDE_OPS_HOME/spool/knowledge" \
    "$CLAUDE_OPS_HOME/state" \
    "$CLAUDE_OPS_HOME/locks" \
    "$CLAUDE_OPS_HOME/backup"
}

# 未セットアップのときに人間向けの案内を出して終了する
ops_require() {
  ops_ready && return 0
  cat >&2 <<'MSG'
非公開設定層が見つかりません。ルーティンは何もせずに終了します。

  必要なもの: $XDG_DATA_HOME/claude-ops/config.json
              各ワークスペース直下の .claude-ops/workspace.json

このリポジトリは「どうやるか」だけを持ち、「何に対してやるか」は持ちません。
MSG
  exit 0
}
