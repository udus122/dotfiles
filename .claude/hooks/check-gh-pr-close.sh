#!/bin/bash
# 自分がオーナーの組織以外での gh pr close を止める。
#
# 判定はコマンド文字列全体ではなく、実際に実行される単位に対して行う。
# 全体を見ると、対象の語が「実行される部分」以外に現れただけで拒否され、
# 正当な操作がブロックされる。例:
#
#   git commit -m "$(cat <<'EOF' ... gh pr close ... EOF)"
#     -> ヒアドキュメント本体はシェルが実行しないデータ
#   gh pr list -R other/repo && gh pr close 1 -R mine/repo
#     -> other は list の宛先であって close の宛先ではない
#
# そこで前処理でヒアドキュメント本体を落とし、複合コマンドを実行単位に割り、
# gh pr close を実行する単位だけを検査する。
#
# 前処理は check-git-push.sh と同じものを持つ。フックは ~/.claude/hooks/ 経由の
# シンボリックリンクとして起動されるため、リポジトリ内の相対パスで共有ヘルパを
# 引くと解決に失敗しうる。壊れたフックは重複より害が大きいので、自己完結にする。
set -euo pipefail
input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // empty')
[ -n "$cmd" ] || exit 0

# 自分がオーナーの組織。一覧は非公開層が持つ（このリポジトリは公開されているため）。
# 読めないときや空のときは、全部拒否する側に倒す。
ops_config="${CLAUDE_OPS_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/claude-ops}/config.json"
allowed_owners=$(jq -r '.issue_owners_allow // [] | .[]' "$ops_config" 2>/dev/null || true)

decide() {
  jq -n --arg d "$1" --arg reason "$2" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: $d,
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# ヒアドキュメント本体を落とす。
# 本体はシェルが解釈しないデータなので、そこに現れた語で判定すると誤検知になる。
# ただし本体をシェル自身に食わせている場合 (bash <<'EOF') は中身が実行されるため残す。
# 引用符は awk の正規表現内で扱いにくいので 8 進表記で書く (\047=' \042=")。
strip_heredocs() {
  awk '
    {
      if (skip) {
        line = $0
        sub(/^[[:space:]]+/, "", line)
        if (line == term) skip = 0
        next
      }
      if (match($0, /<<-?[[:space:]]*[\047\042]?[A-Za-z_][A-Za-z0-9_]*[\047\042]?/)) {
        tok = substr($0, RSTART, RLENGTH)
        sub(/^<<-?[[:space:]]*/, "", tok)
        gsub(/[\047\042]/, "", tok)
        if ($0 !~ /(^|[|&;[:space:](])(bash|sh|zsh|ksh|dash)([[:space:]]|$)/) {
          term = tok
          skip = 1
        }
      }
      print
    }
  '
}

# 複合コマンドを実行単位に割る。&& || ; | と改行が区切り。
# gh pr close はこれらを引数に取らないので、割りすぎて close を見落とすことはない。
split_segments() {
  sed -E 's/(&&|\|\||;|\|)/\
/g'
}

segments=$(printf '%s\n' "$cmd" | strip_heredocs | split_segments)

# cd したディレクトリを覚える (cd x && gh pr close 1)
cd_dir=""
cwd=$(echo "$input" | jq -r '.cwd // empty')

while IFS= read -r seg; do
  if [[ "$seg" =~ ^[[:space:]]*cd[[:space:]]+([^[:space:]]+) ]]; then
    cd_dir="${BASH_REMATCH[1]}"
    continue
  fi

  # この単位が gh pr close を実行しないなら見ない
  [[ "$seg" =~ (^|[[:space:]])gh[[:space:]]+pr[[:space:]]+close([[:space:]]|$) ]] || continue

  # 1) --repo / -R owner/repo の明示指定を優先する
  owner=$(printf '%s' "$seg" \
    | sed -nE 's/^.*[[:space:]](-R|--repo)[[:space:]]+([^[:space:]\/]+)\/[^[:space:]]+.*$/\2/p')

  # 2) 省略時は実行ディレクトリの origin から判定する
  if [ -z "$owner" ]; then
    work_dir="${cd_dir:-$cwd}"
    work_dir="${work_dir/#\~/$HOME}"
    url=$(git -C "${work_dir:-.}" remote get-url origin 2>/dev/null || echo "")
    owner=$(echo "$url" | sed -nE 's#^(https?://[^/]+/|git@[^:]+:|ssh://git@[^/]+/)([^/]+)/.*$#\2#p')
  fi

  [ -n "$owner" ] || decide deny "gh pr close: リポジトリのオーナーを判定できないため拒否"

  [ -n "$allowed_owners" ] \
    || decide deny "gh pr close: 許可オーナーの一覧を読めないため拒否 (owner: $owner)"

  printf '%s\n' "$allowed_owners" | grep -qxF "$owner" \
    || decide deny "gh pr close は自分がオーナーの組織以外では禁止 (owner: $owner)"

  allowed_owner="$owner"
done <<< "$segments"

# close を実行する単位が1つも無ければ素通り
[ -n "${allowed_owner:-}" ] || exit 0

decide allow "$allowed_owner は自分がオーナーの組織のため gh pr close を許可"
