#!/bin/bash
# 共有ブランチの履歴を書き換える force push と、既定ブランチへの直 push を止める。
# 開発ブランチへの force push は作業履歴を整えるための手段なので通す。
#
# 判定はコマンド文字列全体ではなく、実際に実行される単位に対して行う。
# 全体を見ると、禁止対象の語が「実行される部分」以外に現れただけで拒否され、
# 正当な操作がブロックされる。例:
#
#   git push -u origin feat/x && gh pr create --base main
#     -> main は PR のベース指定であって push の引数ではない
#   gh issue create --body "$(cat <<'EOF' ... EOF)"
#     -> ヒアドキュメント本体はシェルが実行しないデータ
#
# そこで前処理でヒアドキュメント本体を落とし、複合コマンドを実行単位に割り、
# git push を実行する単位だけを、その引数に限って検査する。
set -euo pipefail
input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // empty')
[ -n "$cmd" ] || exit 0

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
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
# git push はこれらを引数に取らないので、割りすぎて push を見落とすことはない。
split_segments() {
  sed -E 's/(&&|\|\||;|\|)/\
/g'
}

# 共有ブランチ。ここを書き換えると、書き換え前のコミットが誰かの手元やリモートに
# 残り続け、取り消せない。宛先を判定できなかったとき (空文字) も保護扱いにする。
is_protected() {  # is_protected <branch>
  case "$1" in
    ""|main|master|trunk) return 0 ;;
    develop|development|dev) return 0 ;;
    staging|stage|stg|qa|uat) return 0 ;;
    production|prod|prd) return 0 ;;
    release|releases|release/*|releases/*) return 0 ;;
  esac
  return 1
}

# push の宛先ブランチを列挙する。
# フラグを除いた最初の語は remote、それ以降が refspec。refspec がなければ現在ブランチ。
# +HEAD:refs/heads/x のような形は x に正規化する。
push_targets() {  # push_targets <args> <dir>
  local args="$1" dir="${2:-.}" cur token dest remote_seen=0 found=0
  cur=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || echo "")
  while IFS= read -r token; do
    [ -n "$token" ] || continue
    case "$token" in -*) continue ;; esac
    if [ "$remote_seen" = 0 ]; then
      remote_seen=1
      continue
    fi
    found=1
    dest="${token#+}"
    dest="${dest##*:}"
    dest="${dest#refs/heads/}"
    if [ "$dest" = "HEAD" ]; then dest="$cur"; fi
    printf '%s\n' "$dest"
  done <<< "$(printf '%s' "$args" | tr ' \t' '\n')"
  if [ "$found" = 0 ]; then printf '%s\n' "$cur"; fi
}

segments=$(printf '%s\n' "$cmd" | strip_heredocs | split_segments)

# cd したディレクトリを覚える (cd x && git push)。git -C があればそちらを優先する。
cd_dir=""

while IFS= read -r seg; do
  if [[ "$seg" =~ ^[[:space:]]*cd[[:space:]]+([^[:space:]]+) ]]; then
    cd_dir="${BASH_REMATCH[1]}"
    continue
  fi

  # この単位が git push を実行しないなら見ない
  [[ "$seg" =~ (^|[[:space:]])git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?push([[:space:]]|$) ]] || continue

  # push の引数だけを取り出す。以降の判定はこれに対して行う。
  args=$(printf '%s' "$seg" \
    | sed -E 's/.*git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?push//')

  # push が実行されるディレクトリ
  push_dir=$(printf '%s' "$seg" | sed -nE 's/.*git[[:space:]]+-C[[:space:]]+([^[:space:]]+).*/\1/p')
  [ -n "$push_dir" ] || push_dir="$cd_dir"
  push_dir="${push_dir/#\~/$HOME}"

  targets=$(push_targets "$args" "${push_dir:-.}")

  # force push の検出。
  # フラグ (--force / -f / --force-with-lease / 複合短縮 -fu, -uf, -fn など) と、
  # refspec の + プレフィックス (例: +HEAD:main, +refs/heads/main) の両方。
  force=0
  if [[ "$args" =~ (^|[[:space:]])(--force(-with-lease)?|-[a-zA-Z]*f[a-zA-Z]*)([[:space:]=]|$) ]]; then
    force=1
  fi
  if [[ "$args" =~ (^|[[:space:]])\+[A-Za-z0-9/_.-]+ ]]; then
    force=1
  fi

  if [ "$force" = 1 ]; then
    while IFS= read -r dest; do
      if is_protected "$dest"; then
        deny "共有ブランチ (${dest:-宛先不明}) への force push は禁止"
      fi
    done <<< "$targets"
  fi

  # 個人リポジトリ (~/knowledge, ~/dotfiles) は main 直 push を許可
  # (force push は上で判定済み)
  toplevel=$(git -C "${push_dir:-.}" rev-parse --show-toplevel 2>/dev/null || echo "")
  case "$toplevel" in
    "$HOME/knowledge"|"$HOME/dotfiles") continue ;;
  esac

  # main/master への直 push。引数で明示した場合 (git push origin main,
  # git push origin HEAD:main など) と、引数を省略して現在ブランチが main/master の
  # 場合の両方が targets に出る。
  while IFS= read -r dest; do
    if [[ "$dest" == "main" || "$dest" == "master" ]]; then
      deny "main/master への push は禁止"
    fi
  done <<< "$targets"
done <<< "$segments"

exit 0
