#!/usr/bin/env bash
# PR レビューゲートを、代表的な PR 作成コマンドに対する許可/拒否の表で点検する。
#
# 記録の作成は必ず claude-review-gate を通す。フックと CLI はマーカーのパスを
# それぞれ組み立てているので、式が食い違えばこの表が落ちる。そこがこのテストの要。
#
# 判定表は、その場に記録があるかどうかで検出力が変わる。記録の無い状態では
# 何を書いても deny になるので、取りこぼしを見たいケース (--head の解釈、cd の追従)
# は記録のある区間に、誤検知を見たいケースは記録の無い区間に置く。
#
# フックの実行環境である macOS の /bin/bash は 3.2。CI は Ubuntu の bash 5 なので、
# 3.2 固有の退行はここでは捕まらない。連想配列・mapfile・${var^^} を使わない。
#
#   tools/test-check-pr-review.sh
set -uo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd -P)
HOOK="$REPO/.claude/hooks/check-pr-review.sh"
GATE="$REPO/.local/bin/claude-review-gate"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# 出力は捨てる。環境依存の警告が混ざると、テスト自身の失敗と見分けが付かない。
make_repo() {  # make_repo <dir> <branch>
  mkdir -p "$1"
  {
    git -C "$1" init -q -b "$2" \
      && git -C "$1" -c user.email=t@example.invalid -c user.name=t \
           commit -q --allow-empty -m init
  } >/dev/null 2>&1 || {
    printf 'テスト用リポジトリの作成に失敗しました: %s\n' "$1" >&2
    exit 1
  }
}

make_repo "$tmp/repo-on-feat" feat/x
make_repo "$tmp/repo-on-main" main
mkdir -p "$tmp/plain"

feat="$tmp/repo-on-feat"
onmain="$tmp/repo-on-main"
plain="$tmp/plain"
wt="$tmp/wt"

git -C "$feat" worktree add -q -b wt/y "$wt" >/dev/null 2>&1 || {
  printf 'worktree の作成に失敗しました\n' >&2
  exit 1
}

pass=0
fail=0

bash_json() {  # bash_json <cwd> <cmd>
  jq -n --arg cwd "$1" --arg cmd "$2" \
    '{tool_name: "Bash", cwd: $cwd, tool_input: {command: $cmd}}'
}

mcp_json() {  # mcp_json <cwd> <tool> <head>
  jq -n --arg cwd "$1" --arg tool "$2" --arg head "$3" \
    '{tool_name: $tool, cwd: $cwd, tool_input: {head: $head, base: "main"}}'
}

check() {  # check <allow|deny> <desc> <json>
  local expect="$1" desc="$2" json="$3" out got
  out=$(printf '%s' "$json" | bash "$HOOK" 2>&1)
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
    printf 'NG   %s\n       期待 %s / 実際 %s\n' "$desc" "$expect" "$got"
    fail=$((fail + 1))
  fi
}

# パイプで呼ぶと関数がサブシェルに入り、集計が親に返らない。
# 標準入力を渡したいときは呼び出し全体にリダイレクトを付ける。
expect_ok() {  # expect_ok <desc> <cmd...>
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    pass=$((pass + 1))
  else
    printf 'NG   %s\n' "$desc"
    fail=$((fail + 1))
  fi
}

expect_fail() {  # expect_fail <desc> <cmd...>
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf 'NG   %s\n' "$desc"
    fail=$((fail + 1))
  else
    pass=$((pass + 1))
  fi
}

record() {  # record <dir> [args...]
  local dir="$1"
  shift
  printf 'レビューで見た点と、直した指摘と残した指摘を数行で\n' \
    | bash "$GATE" record --dir "$dir" "$@" >/dev/null 2>&1
}

# ============================================ 記録のない状態: 誤検知を見る

check allow "PR の閲覧" \
  "$(bash_json "$feat" 'gh pr view --web')"

check allow "使い方の表示" \
  "$(bash_json "$feat" 'gh pr create --help')"

check allow "--dry-run" \
  "$(bash_json "$feat" 'gh pr create --dry-run --base main')"

check allow "push 単体" \
  "$(bash_json "$feat" 'git push -u origin feat/x')"

check allow "ヒアドキュメント本体に現れる (実行されないデータ)" \
  "$(bash_json "$feat" 'gh issue create --body "$(cat <<'"'"'EOF'"'"'
gh pr create がフックに止められた理由を書く。
EOF
)"')"

check allow "issue の作成 (タイトルに紛れ込んだだけ)" \
  "$(bash_json "$feat" 'gh issue create --title "gh pr create をフックで止める"')"

check allow "コメント行に現れる (実行されない)" \
  "$(bash_json "$feat" '# gh pr create をやめる
git status')"

check allow "git 管理外では判定しない" \
  "$(bash_json "$plain" 'gh pr create --base main')"

check deny "記録なしの PR 作成" \
  "$(bash_json "$feat" 'gh pr create --base main --head feat/x')"

check deny "push と PR 作成を && でつないだ複合コマンド" \
  "$(bash_json "$feat" 'git push -u origin feat/x && gh pr create --base main --head feat/x')"

check deny "--repo をフラグで指定する形" \
  "$(bash_json "$feat" 'gh --repo=udus122/dotfiles pr create --base main')"

check deny "gh を絶対パスで呼ぶ形" \
  "$(bash_json "$feat" '/usr/bin/gh pr create --base main')"

check deny "本文に -h と書いただけでは素通りしない" \
  "$(bash_json "$feat" 'gh pr create --base main --body "see -h for help"')"

check deny "MCP (github)" \
  "$(mcp_json "$feat" mcp__github__create_pull_request 'feat/x')"

check deny "MCP (web)" \
  "$(mcp_json "$feat" mcp__GitHub_for_Claude_Web__create_pull_request 'feat/x')"

# ================================= 記録のある状態: 取りこぼしを見る

record "$feat"

check allow "記録あり" \
  "$(bash_json "$feat" 'gh pr create --base main --head feat/x')"

check allow "記録あり (複合コマンド)" \
  "$(bash_json "$feat" 'git push -u origin feat/x && gh pr create --base main')"

check allow "記録あり (MCP)" \
  "$(mcp_json "$feat" mcp__github__create_pull_request 'feat/x')"

check allow "記録あり (MCP、head 省略時は cwd の HEAD で判定)" \
  "$(mcp_json "$feat" mcp__github__create_pull_request '')"

git -C "$feat" -c user.email=t@example.invalid -c user.name=t \
  commit -q --allow-empty -m fix >/dev/null 2>&1
check allow "記録後に積んだコミットで再レビューを求めない" \
  "$(bash_json "$feat" 'gh pr create --base main')"

check deny "--head で別ブランチを指定する" \
  "$(bash_json "$feat" 'gh pr create --base main --head feat/y')"

check deny "--head=x の形" \
  "$(bash_json "$feat" 'gh pr create --base main --head=feat/y')"

check deny "--head の値がクォートされている形" \
  "$(bash_json "$feat" 'gh pr create --base main --head "feat/y"')"

check deny "-H の形" \
  "$(bash_json "$feat" 'gh pr create --base main -H feat/y')"

check deny "タイトルに && を含んでも --head を見失わない" \
  "$(bash_json "$feat" 'gh pr create --title "a && b" --head feat/y')"

check deny "cd 先のリポジトリで判定する" \
  "$(bash_json "$feat" "cd $onmain && gh pr create --base main")"

check deny "cd 先がクォートされている形" \
  "$(bash_json "$feat" "cd \"$onmain\" && gh pr create --base main")"

check deny "cd 先が相対パスの形" \
  "$(bash_json "$feat" 'cd ../repo-on-main && gh pr create --base main')"

check deny "サブシェルで cd する形" \
  "$(bash_json "$feat" '(cd ../repo-on-main; gh pr create --base main)')"

# ---------------------------------------------- worktree 間で共有される

record "$wt"
check allow "worktree で記録し、本体から作成する" \
  "$(bash_json "$feat" 'gh pr create --base main --head wt/y')"

record "$feat" --branch wt/z
check allow "本体で記録し、worktree から作成する" \
  "$(bash_json "$wt" 'gh pr create --base main --head wt/z')"

# ---------------------------------------------- 記録を消すと戻る

bash "$GATE" clear --dir "$feat" >/dev/null 2>&1
check deny "記録を消すと再び止まる" \
  "$(bash_json "$feat" 'gh pr create --base main')"

# feat/x の記録が無い状態で、fork 形式が owner を落として解決できるかを見る
record "$feat" --branch other/b
check allow "fork の owner:branch 形式" \
  "$(mcp_json "$feat" mcp__github__create_pull_request 'someone:other/b')"

record "$feat" --branch claude/pr/code-review
check allow "スラッシュを2つ含むブランチ名" \
  "$(bash_json "$feat" 'gh pr create --base main --head claude/pr/code-review')"

# ================================================================ CLI 単体

expect_fail "空の要約を拒否する" \
  bash "$GATE" record --dir "$onmain" < /dev/null

expect_fail "拒否された記録は作られていない" \
  bash "$GATE" check --dir "$onmain"

printf 'ok\n' > "$tmp/short.txt"
expect_fail "短すぎる要約を拒否する" \
  bash "$GATE" record --dir "$onmain" < "$tmp/short.txt"

expect_fail "--skip は理由がないと失敗する" \
  bash "$GATE" record --dir "$onmain" --skip

expect_fail "経路を含むブランチ名を拒否する" \
  bash "$GATE" record --dir "$onmain" --branch ../../escape --skip 'テスト'

expect_ok "--skip は理由があれば記録できる" \
  bash "$GATE" record --dir "$onmain" --skip 'ユーザーの指示でレビューを省略'

expect_ok "check は記録があれば 0 を返す" \
  bash "$GATE" check --dir "$onmain"

expect_ok "show は記録を読める" \
  bash "$GATE" show --dir "$onmain"

printf '\n判定: %s (成功 %d / 失敗 %d)\n' \
  "$([ "$fail" -eq 0 ] && echo 合格 || echo 不合格)" "$pass" "$fail"
exit $((fail > 0))
