#!/usr/bin/env bash
# Claude Code statusLine command — styled after the oh-my-zsh bira theme

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five_hr=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_day=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# Colors (ANSI)
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RESET='\033[0m'
BOLD='\033[1m'

# user@host
user=$(whoami)
host=$(hostname -s)
user_host="${BOLD}${GREEN}${user}@${host}${RESET}"

# Shorten home directory to ~
home="$HOME"
short_cwd="${cwd/#$home/\~}"
current_dir="${BOLD}${BLUE}${short_cwd}${RESET}"

# Git branch (skip optional locks to avoid contention)
git_branch=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
             || GIT_OPTIONAL_LOCKS=0 git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        git_branch=" ${YELLOW}‹${branch}›${RESET}"
    fi
fi

# Context + rate limit usage (grouped together)
ctx_info=""
if [ -n "$used_pct" ]; then
    ctx_info=" ctx:$(printf '%.0f' "$used_pct")%"
    rate_parts=""
    if [ -n "$five_hr" ]; then
        rate_parts="5h:$(printf '%.0f' "$five_hr")%"
    fi
    if [ -n "$seven_day" ]; then
        if [ -n "$rate_parts" ]; then
            rate_parts="${rate_parts} 7d:$(printf '%.0f' "$seven_day")%"
        else
            rate_parts="7d:$(printf '%.0f' "$seven_day")%"
        fi
    fi
    if [ -n "$rate_parts" ]; then
        ctx_info="${ctx_info} [${rate_parts}]"
    fi
fi

# Model (short)
model_info=""
if [ -n "$model" ]; then
    model_info=" ${model}"
fi

printf "╭─ %b %b%b%b%b\n" \
    "$user_host" "$current_dir" "$git_branch" "$ctx_info" "$model_info"
