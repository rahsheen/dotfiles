#!/usr/bin/env bash
# Coder stops a workspace at its deadline even while an agent is mid-task.
#   status  print a status-line segment with the time left
#   hook    on a prompt or tool call, extend the deadline when it is close
#           (CODER_AUTO_EXTEND=0 warns instead)
# An idle agent fires no hooks, so autostop still reclaims an idle box.
# A no-op outside a Coder workspace.

ws="${CODER_WORKSPACE_NAME:-}"
[ -n "$ws" ] || exit 0
command -v coder > /dev/null 2>&1 && command -v jq > /dev/null 2>&1 || exit 0

state="${XDG_CACHE_HOME:-$HOME/.cache}/coder-deadline"
mkdir -p "$state"
warn_min="${CODER_DEADLINE_WARN_MIN:-60}"
extend_by="${CODER_EXTEND_BY:-2h}"
now=$(date +%s)

mtime() { stat -c %Y "$1" 2> /dev/null || stat -f %m "$1"; }
age() { [ -f "$1" ] && echo $((now - $(mtime "$1"))) || echo 999999; }

# The status line renders often and the hook runs on every tool call, so the
# API is asked at most once a minute. Empty means no autostop is scheduled.
deadline() {
  if [ "$(age "$state/deadline")" -ge 60 ]; then
    coder schedule show "$ws" -o json 2>/dev/null \
      | jq -r '.[0].stops_next // empty | sub("\\.[0-9]+"; "") | fromdateiso8601' \
      > "$state/deadline" 2>/dev/null
  fi
  cat "$state/deadline"
}

d=$(deadline)
[ -n "$d" ] || exit 0
left=$(((d - now) / 60))

case "${1:-}" in
  status)
    if [ "$left" -lt 30 ]; then color='\033[0;31m'
    elif [ "$left" -lt "$warn_min" ]; then color='\033[0;33m'
    else color='\033[2m'; fi
    printf " %b⏱ %dh%02dm\033[0m" "$color" $((left / 60)) $((left % 60))
    ;;
  hook)
    cat > /dev/null
    [ "$left" -lt "$warn_min" ] || exit 0
    if [ "${CODER_AUTO_EXTEND:-1}" != 0 ] \
        && coder schedule extend "$ws" "$extend_by" > /dev/null 2>&1; then
      rm -f "$state/deadline"
      msg="Coder: $ws had ${left}m left; extended to $extend_by from now."
    else
      # Warn at most every 10 minutes, or every tool call repeats it.
      [ "$(age "$state/warned")" -ge 600 ] || exit 0
      touch "$state/warned"
      msg="Coder: $ws stops in ${left}m. Extend with: coder schedule extend $ws $extend_by"
    fi
    jq -nc --arg m "$msg" '{systemMessage: $m}'
    ;;
esac
