#!/bin/sh
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
git_branch=""
if git_branch_raw=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null); then
  git_branch=" $git_branch_raw"
fi

time_str=$(date +%H:%M)

ctx_str=""
if [ -n "$used" ]; then
  ctx_str=" ctx:$(printf '%.0f' "$used")%"
fi

printf "\033[32m%s\033[0m\033[36m%s\033[0m \033[90m%s%s%s\033[0m" \
  "$cwd" "$git_branch" "$time_str" "$ctx_str" " $model"
