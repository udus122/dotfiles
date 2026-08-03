#!/usr/bin/env bash
# gh pr close ガードのフックを、代表的なコマンドに対する許可/拒否の表で点検する。
#
# 許可オーナーの一覧は非公開層が持つ。一覧を読めないときに素通りしてしまうと、
# 他人のリポジトリの PR を閉じられる状態になる。読めない側の分岐まで表に残す。
#
# 一覧はテスト専用の非公開層を作って与える。実在の所有者名はこのリポジトリに書かない。
#
#   tools/test-check-gh-pr-close.sh
set -uo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd -P)
HOOK="$REPO/.claude/hooks/check-gh-pr-close.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# テスト用の非公開層。実在の所有者名とは無関係な値を入れる。
mkdir -p "$tmp/ops"
cat > "$tmp/ops/config.json" <<'EOF'
{ "issue_owners_allow": ["owner-mine", "org-mine"] }
EOF
mkdir -p "$tmp/ops-empty"
printf '{ "issue_owners_allow": [] }\n' > "$tmp/ops-empty/config.json"

# origin の owner から判定する経路のための作業リポジトリ
make_repo() {  # make_repo <dir> <origin url>
  mkdir -p "$1"
  {
    git -C "$1" init -q -b main && git -C "$1" remote add origin "$2"
  } >/dev/null 2>&1 || {
    printf 'テスト用リポジトリの作成に失敗しました: %s\n' "$1" >&2
    exit 1
  }
}
make_repo "$tmp/repo-mine"  'git@github.com:owner-mine/some-repo.git'
make_repo "$tmp/repo-other" 'https://github.com/someone-else/some-repo.git'

pass=0
fail=0

check() {  # check <allow|deny> <ops_home> <cwd> <desc> <cmd>
  local expect="$1" ops="$2" cwd="$3" desc="$4" cmd="$5" out got
  out=$(printf '%s' "$cmd" | jq -Rs --arg cwd "$cwd" '{tool_input: {command: .}, cwd: $cwd}' \
        | (cd "$cwd" && CLAUDE_OPS_HOME="$ops" bash "$HOOK") 2>&1)
  if [ $? -ne 0 ]; then
    printf 'ERR  %s\n       フックが異常終了: %s\n' "$desc" "$out"
    fail=$((fail + 1))
    return
  fi
  if [ -z "$out" ]; then
    got="allow"
  else
    got=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "allow"' 2>/dev/null) \
      || got="parse-error"
  fi
  if [ "$got" = "$expect" ]; then
    pass=$((pass + 1))
  else
    printf 'NG   %s\n       期待 %s / 実際 %s\n       cmd: %s\n' \
      "$desc" "$expect" "$got" "$cmd"
    fail=$((fail + 1))
  fi
}

ops="$tmp/ops"
mine="$tmp/repo-mine"
other="$tmp/repo-other"

# ---------------------------------------------------------------- 通すもの

check allow "$ops" "$mine" "gh pr close を含まないコマンドは素通り" \
  'gh pr create --base main'

check allow "$ops" "$other" "close という語だけでは捕捉しない" \
  'gh issue close 1'

check allow "$ops" "$other" "-R で自分の所有者を明示" \
  'gh pr close 1 -R owner-mine/some-repo'

check allow "$ops" "$other" "--repo で自分の組織を明示" \
  'gh pr close 1 --repo org-mine/some-repo'

check allow "$ops" "$mine" "省略時は実行ディレクトリの origin から判定" \
  'gh pr close 1'

check allow "$ops" "$other" "cd 先の origin から判定" \
  "cd $mine && gh pr close 1"

check allow "$ops" "$other" "ヒアドキュメント本体に対象の語が現れる (実行されないデータ)" \
  'git commit -m "$(cat <<'"'"'EOF'"'"'
fix(hooks): gh pr close ガードの誤検知を直す
EOF
)"'

check allow "$ops" "$other" "別の単位の -R は close の宛先ではない" \
  'gh pr list -R someone-else/some-repo && gh pr close 1 -R owner-mine/some-repo'

check allow "$ops" "$other" "close の直前の cd 先で判定する" \
  "cd $other && gh pr view 1 && cd $mine && gh pr close 1"

# ---------------------------------------------------------------- 止めるもの

check deny "$ops" "$mine" "-R で他人の所有者を明示" \
  'gh pr close 1 -R someone-else/some-repo'

check deny "$ops" "$other" "省略時に他人の origin" \
  'gh pr close 1'

check deny "$ops" "$mine" "cd 先が他人の origin" \
  "cd $other && gh pr close 1"

check deny "$ops" "$tmp" "オーナーを判定できない (git リポジトリの外)" \
  'gh pr close 1'

check deny "$ops" "$mine" "所有者名の前方一致では通さない" \
  'gh pr close 1 -R owner-mine-evil/some-repo'

check deny "$ops" "$mine" "シェルに食わせるヒアドキュメント本体は落とさない" \
  "bash <<'EOF'
gh pr close 1 -R someone-else/some-repo
EOF"

# 非公開層が無い環境では、素通りではなく拒否側に倒れること
check deny "$tmp/ops-missing" "$mine" "非公開層が無い" \
  'gh pr close 1'

check deny "$tmp/ops-empty" "$mine" "許可オーナーの一覧が空" \
  'gh pr close 1'

printf '\n判定: %s (成功 %d / 失敗 %d)\n' \
  "$([ "$fail" -eq 0 ] && echo 合格 || echo 不合格)" "$pass" "$fail"
exit $((fail > 0))
