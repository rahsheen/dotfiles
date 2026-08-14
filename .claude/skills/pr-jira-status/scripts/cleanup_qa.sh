#!/usr/bin/env bash
# Find qa-review Coder workspaces whose Jira ticket is RESOLVED, so they can be
# cleaned up. "Resolved" = Jira's resolution field is set (canonical signal —
# more reliable than matching status-name strings, and it catches Production
# Deployed / Staging Deployed / Won't Do / etc.).
#
# Default (no args): SCAN — print candidates, change nothing.
# --delete <ws>...:  permanently remove the named workspaces (coder delete -y).
# --stop   <ws>...:  power them down instead (coder stop -y), keeping the workspace.
#
# The caller (the skill) is responsible for confirming with the user before
# invoking --delete/--stop. Scanning is always safe.
set -euo pipefail

action="scan"
case "${1:-}" in
  --delete) action="delete"; shift ;;
  --stop)   action="stop";   shift ;;
esac

if [[ "$action" != "scan" ]]; then
  [[ $# -gt 0 ]] || { echo "usage: cleanup_qa.sh --$action <workspace>..." >&2; exit 1; }
  for ws in "$@"; do
    ws="${ws##*/}"   # tolerate owner/ prefix
    echo "▶ ${action}: $ws"
    coder "$action" "$ws" -y
  done
  echo "✅ ${action} complete (${#} workspace(s))"
  exit 0
fi

# --- scan ---
list=$(coder list 2>/dev/null || true)
tickets=$(echo "$list" | grep -o '[A-Z][A-Z0-9]*-[0-9]*-qa-review' | sed 's/-qa-review//' | sort -u)
[[ -n "$tickets" ]] || { echo "No qa-review workspaces found."; exit 0; }

q=$(echo "$tickets" | paste -sd, -)
# Ask Jira which of these are resolved. Empty result = none resolved.
resolved=$(jira issue list -q "key in ($q) AND resolution IS NOT EMPTY" \
             --plain --columns key,status --no-headers 2>/dev/null || true)

if [[ -z "$resolved" ]]; then
  echo "No resolved-ticket workspaces to clean up (scanned $(echo "$tickets" | wc -l | tr -d ' ') workspaces)."
  exit 0
fi

echo "Cleanup candidates (ticket resolved):"
printf '%-10s %-22s %-9s %s\n' TICKET STATUS CODER WORKSPACE
while IFS=$'\t' read -r key status _; do
  [[ -n "$key" ]] || continue
  ws="${key}-qa-review"
  state=$(echo "$list" | awk -v w="$ws" '$0 ~ w {print $3; exit}')
  printf '%-10s %-22s %-9s %s\n' "$key" "$status" "${state:-?}" "$ws"
done <<< "$resolved"
