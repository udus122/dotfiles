#!/usr/bin/env bash
# push ガードのフックを、代表的なコマンドに対する許可/拒否の表で点検する。
#
# このフックは誤検知すると正当な操作を止め、見落とすと安全弁として機能しない。
# どちらも実際に起きたことがあるので、両方向を表に残す。
#
#   tools/test-check-git-push.sh
set -uo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd -P)
HOOK="$REPO/.claude/hooks/check-git-push.sh"

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
make_repo "$tmp/repo-on-main" main
make_repo "$tmp/repo-on-feat" feat-x
make_repo "$tmp/repo-on-stg" stg

# gh の代役。フックは force push の宛先ブランチの PR を gh pr view で引くが、
# テスト用リポジトリには GitHub のリモートが無く、本物の gh は必ず失敗する。
# 宛先ブランチの名前で応答を決める。
#   feat/reviewed  人のレビューが付いた PR がある
#   feat/gh-error  gh が失敗する (認証切れ・通信断など)
#   それ以外       PR が無い
mkdir -p "$tmp/bin"
cat > "$tmp/bin/gh" <<'EOF'
#!/usr/bin/env bash
[ "$1 $2" = "pr view" ] || { echo "unexpected gh call: $*" >&2; exit 2; }
case "$3" in
  feat/reviewed) echo "reviewer-a" ;;
  feat/gh-error) echo "error connecting to api.github.com" >&2; exit 1 ;;
  *) echo "no pull requests found for branch \"$3\"" >&2; exit 1 ;;
esac
EOF
chmod +x "$tmp/bin/gh"
export PATH="$tmp/bin:$PATH"

pass=0
fail=0

check() {  # check <allow|deny> <cwd> <desc> <cmd>
  local expect="$1" cwd="$2" desc="$3" cmd="$4" out got
  out=$(printf '%s' "$cmd" | jq -Rs '{tool_input: {command: .}}' \
        | (cd "$cwd" && bash "$HOOK") 2>&1)
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

feat="$tmp/repo-on-feat"
onmain="$tmp/repo-on-main"
onstg="$tmp/repo-on-stg"

# ---------------------------------------------------------------- 通すもの

check allow "$feat" "feature ブランチへの push" \
  'git push -u origin feat/x'

check allow "$feat" "push と PR 作成を && でつないだ複合コマンド" \
  'git push -u origin feat/x && gh pr create --base main --head feat/x'

check allow "$feat" "push を含まない複合コマンド" \
  'gh pr create --base main && gh pr view --web'

check allow "$feat" "別の単位に -f が現れる複合コマンド" \
  'grep -f patterns.txt notes.md && git push origin feat/x'

check allow "$feat" "ヒアドキュメント本体に禁止語が現れる (実行されないデータ)" \
  'gh issue create --body "$(cat <<'"'"'EOF'"'"'
git push origin main が拒否された理由を書く。force push も同様。
EOF
)"'

check allow "$feat" "refspec 形式の feature ブランチ" \
  'git push origin HEAD:refs/heads/feat/x'

check allow "$feat" "開発ブランチへの --force" \
  'git push --force origin feat/x'

check allow "$feat" "開発ブランチへの -f" \
  'git push -f origin feat/x'

check allow "$feat" "開発ブランチへの --force-with-lease" \
  'git push --force-with-lease origin feat/x'

check allow "$feat" "開発ブランチへの複合短縮フラグ (-fu)" \
  'git push -fu origin feat/x'

check allow "$feat" "開発ブランチへの + プレフィックス refspec" \
  'git push origin +feat/x'

check allow "$feat" "現在ブランチが開発ブランチでの引数省略 force push" \
  'git push -f'

check allow "$onmain" "現在ブランチが main でも宛先が開発ブランチなら force push は通す" \
  'git push --force origin HEAD:feat/x'

check allow "$feat" "main を含む名前の開発ブランチ (main そのものではない)" \
  'git push --force origin feat/main-cleanup'

# ---------------------------------------------------------------- 止めるもの

check deny "$feat" "main への --force" \
  'git push --force origin main'

check deny "$feat" "main への -f" \
  'git push -f origin main'

check deny "$feat" "main への --force-with-lease" \
  'git push --force-with-lease origin main'

check deny "$feat" "main への複合短縮フラグ (-fu)" \
  'git push -fu origin HEAD:main'

check deny "$feat" "main への + プレフィックス refspec" \
  'git push origin +refs/heads/main'

check deny "$feat" "stg への force push" \
  'git push --force origin stg'

check deny "$feat" "production への force push" \
  'git push --force-with-lease origin production'

check deny "$feat" "develop への force push" \
  'git push -f origin develop'

check deny "$feat" "release/* への force push" \
  'git push --force origin release/1.0'

check deny "$feat" "人のレビューが付いた PR のブランチへの force push" \
  'git push --force origin feat/reviewed'

check allow "$feat" "人のレビューが付いた PR のブランチでも普通の push は通す" \
  'git push origin feat/reviewed'

check deny "$feat" "PR のレビュー状況を gh で確認できないときの force push" \
  'git push --force origin feat/gh-error'

check deny "$onstg" "現在ブランチが共有ブランチでの引数省略 force push" \
  'git push --force'

check deny "$feat" "main を引数で明示" \
  'git push origin main'

check deny "$feat" "master を引数で明示" \
  'git push origin master'

check deny "$feat" "HEAD:main" \
  'git push origin HEAD:main'

check deny "$onmain" "現在ブランチが main での引数省略 push" \
  'git push'

check deny "$onmain" "現在ブランチが main での git push -u origin" \
  'git push -u origin'

check deny "$feat" "後ろの単位に現れる push も検査する" \
  'echo ok && git push origin master'

check deny "$feat" "cd 先のブランチで判定する" \
  "cd $onmain && git push"

check deny "$feat" "git -C 先のブランチで判定する" \
  "git -C $onmain push"

check deny "$feat" "シェルに食わせるヒアドキュメント本体は落とさない" \
  "bash <<'EOF'
git push --force origin main
EOF"

printf '\n判定: %s (成功 %d / 失敗 %d)\n' \
  "$([ "$fail" -eq 0 ] && echo 合格 || echo 不合格)" "$pass" "$fail"
exit $((fail > 0))
