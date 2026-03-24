#!/usr/bin/env bash

# Claude Code statusline script
# Line 1: 5-hour and 7-day rate limit usage (when available)
# Line 2: git branch · model (effort) · context%

export LC_ALL=C
input=$(cat)

# ANSI colors (no backgrounds)
reset='\033[0m'
dim='\033[2m'
cyan='\033[36m'
blue='\033[34m'
orange='\033[38;5;208m'
yellow='\033[33m'
green='\033[32m'
red='\033[31m'

sep="${dim} · ${reset}"

# Extract a string value from JSON without jq
# Usage: json_str "key" "$json"
json_str() {
    printf '%s' "$2" | sed -n "s/.*\"${1}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1
}

# Extract a numeric value from JSON without jq
# Usage: json_num "key" "$json"
json_num() {
    printf '%s' "$2" | sed -n "s/.*\"${1}\"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\(\.[0-9]*\)\?\).*/\1/p" | head -1
}

# Return ANSI color variable for a percentage value
pct_color() {
    local pct_int
    pct_int=$(printf "%.0f" "$1")
    if [ "$pct_int" -ge 80 ]; then printf '%s' "$red"
    elif [ "$pct_int" -ge 50 ]; then printf '%s' "$yellow"
    else printf '%s' "$green"; fi
}

# Format a Unix timestamp as time only: "4:30pm"
fmt_time() {
    date -d "@$1" +"%I:%M%p" 2>/dev/null | sed 's/^0//;s/AM/am/;s/PM/pm/'
}

# Format a Unix timestamp as day + time: "Sat 4:30pm"
fmt_day_time() {
    date -d "@$1" +"%a %I:%M%p" 2>/dev/null | sed 's/ 0/ /;s/AM/am/;s/PM/pm/'
}

# ============================================================
# --- Line 1: Rate limit usage ---
# ============================================================
line1_parts=()

five_hr_pct=$(printf '%s' "$input" | sed -n 's/.*"five_hour"[[:space:]]*:[[:space:]]*{[^}]*"used_percentage"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\(\.[0-9]*\)\?\).*/\1/p' | head -1)
five_hr_reset=$(printf '%s' "$input" | sed -n 's/.*"five_hour"[[:space:]]*:[[:space:]]*{[^}]*"resets_at"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -1)

seven_day_pct=$(printf '%s' "$input" | sed -n 's/.*"seven_day"[[:space:]]*:[[:space:]]*{[^}]*"used_percentage"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\(\.[0-9]*\)\?\).*/\1/p' | head -1)
seven_day_reset=$(printf '%s' "$input" | sed -n 's/.*"seven_day"[[:space:]]*:[[:space:]]*{[^}]*"resets_at"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -1)

if [ -n "$five_hr_pct" ]; then
    pct_int=$(printf "%.0f" "$five_hr_pct")
    color=$(pct_color "$five_hr_pct")
    reset_str=""
    if [ -n "$five_hr_reset" ]; then
        reset_str=" $(printf "${dim}resets %s${reset}" "$(fmt_time "$five_hr_reset")")"
    fi
    line1_parts+=("$(printf "5h: ${color}%s%%${reset}%s" "$pct_int" "$reset_str")")
fi

if [ -n "$seven_day_pct" ]; then
    pct_int=$(printf "%.0f" "$seven_day_pct")
    color=$(pct_color "$seven_day_pct")
    reset_str=""
    if [ -n "$seven_day_reset" ]; then
        reset_str=" $(printf "${dim}resets %s${reset}" "$(fmt_day_time "$seven_day_reset")")"
    fi
    line1_parts+=("$(printf "7d: ${color}%s%%${reset}%s" "$pct_int" "$reset_str")")
fi

line1=""
for i in "${!line1_parts[@]}"; do
    if [ $i -gt 0 ]; then
        line1+=$(printf "$sep")
    fi
    line1+="${line1_parts[$i]}"
done

# ============================================================
# --- Line 2: Git branch · model (effort) · context% ---
# ============================================================
line2_parts=()

# --- Segment 1: Git branch ---
git_dir=$(json_str "current_dir" "$input")
[ -z "$git_dir" ] && git_dir=$(json_str "cwd" "$input")
[ -z "$git_dir" ] && git_dir="${PWD}"

branch=$(git -C "$git_dir" symbolic-ref --short HEAD 2>/dev/null)
if [ -n "$branch" ]; then
    staged=""
    unstaged=""
    if ! git -C "$git_dir" diff --no-lock-file --cached --quiet 2>/dev/null; then
        staged="+"
    fi
    if ! git -C "$git_dir" diff --no-lock-file --quiet 2>/dev/null; then
        unstaged="*"
    fi

    dirty=""
    if [ -n "$staged" ] && [ -n "$unstaged" ]; then
        dirty="${yellow}+${reset}${orange}*${reset}"
    elif [ -n "$staged" ]; then
        dirty="${yellow}+${reset}"
    elif [ -n "$unstaged" ]; then
        dirty="${orange}*${reset}"
    fi

    line2_parts+=("$(printf "${cyan} %s${reset}%s" "$branch" "$dirty")")
fi

# --- Segment 2: Model + effort ---
model_name=$(json_str "display_name" "$input")
if [ -n "$model_name" ]; then
    effort=""
    settings_file="${HOME}/.claude/settings.json"
    if [ -f "$settings_file" ]; then
        effort_val=$(json_str "effortLevel" "$(cat "$settings_file")")
        if [ -n "$effort_val" ]; then
            effort=" $(printf "${dim}(%s)${reset}" "$effort_val")"
        fi
    fi
    line2_parts+=("$(printf "${blue}%s${reset}%s" "$model_name" "$effort")")
fi

# --- Segment 3: Context usage % ---
# Match the context_window's used_percentage, which is always followed by remaining_percentage
used_pct=$(printf '%s' "$input" | sed -n 's/.*"used_percentage"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\(\.[0-9]*\)\?\)[[:space:]]*,[[:space:]]*"remaining_percentage".*/\1/p' | head -1)
if [ -n "$used_pct" ]; then
    pct_int=$(printf "%.0f" "$used_pct")
    color=$(pct_color "$used_pct")
    line2_parts+=("$(printf "${color}%s%%${reset}" "$pct_int")")
fi

# --- Join with separator ---
line2=""
for i in "${!line2_parts[@]}"; do
    if [ $i -gt 0 ]; then
        line2+=$(printf "$sep")
    fi
    line2+="${line2_parts[$i]}"
done

# ============================================================
# --- Output ---
# ============================================================
if [ -n "$line1" ]; then
    printf "%b\n%b" "$line1" "$line2"
else
    printf "%b" "$line2"
fi
