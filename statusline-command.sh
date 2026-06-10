#!/bin/sh
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
dir=$(basename "$cwd")
model=$(echo "$input" | jq -r '.model.display_name // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
added=$(echo "$input" | jq -r '.cost.total_lines_added // empty')
removed=$(echo "$input" | jq -r '.cost.total_lines_removed // empty')

user=$(whoami)

# Git info
branch=""
if [ -n "$cwd" ]; then
  branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
  if [ -n "$branch" ]; then
    dirty=$(git -C "$cwd" status --porcelain 2>/dev/null)
    if [ -n "$dirty" ]; then
      branch="${branch}*"
    fi
  fi
fi

# Build parts
git_part=""
if [ -n "$branch" ]; then
  git_part="  \033[33m${branch}\033[0m"
fi

model_part=""
if [ -n "$model" ]; then
  model_part="  \033[31m[${model}]\033[0m"
fi

lines_part=""
if [ -n "$added" ] && [ -n "$removed" ]; then
  lines_part="  \033[32m+${added}\033[0m/\033[31m-${removed}\033[0m"
fi

cost_part=""
if [ -n "$cost" ]; then
  cost_fmt=$(printf '%.2f' "$cost")
  cost_part="  \033[33m\$${cost_fmt}\033[0m"
fi

ctx_part=""
if [ -n "$used" ]; then
  ctx_part="  \033[2mctx:${used}%\033[0m"
fi

printf "\033[32m%s\033[0m %s%b%b%b%b%b" \
  "$user" \
  "$dir" \
  "$git_part" \
  "$model_part" \
  "$lines_part" \
  "$cost_part" \
  "$ctx_part"
