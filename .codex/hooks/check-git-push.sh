#!/bin/bash
# push ガードのルールは .claude/hooks/check-git-push.sh に置き、ここからはそれを呼ぶ。
# 入出力の形式は Claude Code のフックと同じ。
set -euo pipefail
exec "$HOME/.claude/hooks/check-git-push.sh"
