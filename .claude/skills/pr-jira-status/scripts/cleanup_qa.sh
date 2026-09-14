#!/usr/bin/env bash
# Find qa-review Coder workspaces whose Jira ticket is RESOLVED, so they can be
# cleaned up. "Resolved" = Jira's resolution field is set (canonical signal —
# more reliable than matching status-name strings, and it catches Production
# Deployed / Staging Deployed / Won't Do / etc.).
#
# Default (no args): SCAN — print candidates, change nothing.
# --delete <ws>...:  permanently remove the named workspaces (coder delete -y).
#                    REFUSES any workspace not in the live resolved-ticket set,
#                    so the blast radius is bounded by Jira state rather than by
#                    whatever the caller passes. Validation runs over every
#                    argument BEFORE the first deletion — all or nothing.
# --stop   <ws>...:  power them down (coder stop -y). Rarely useful: Coder
#                    autostop (see STOPS AFTER in `coder list`) already does this.
#
# The caller (the skill) is still responsible for confirming with the user
# before invoking --delete. Scanning is always safe.
set -euo pipefail

# Emit one "<ticket>\t<status>\t<coder-state>\t<workspace>" line per qa-review
# workspace whose ticket is resolved. No output = nothing eligible.
resolved_workspaces() {
  local list tickets q resolved key status state
  list=$(coder list 2>/dev/null || true)
  tickets=$(echo "$list" | grep -o '[A-Z][A-Z0-9]*-[0-9]*-qa-review' | sed 's/-qa-review//' | sort -u)
  [[ -n "$tickets" ]] || return 0
  q=$(echo "$tickets" | paste -sd, -)
  resolved=$(jira issue list -q "key in ($q) AND resolution IS NOT EMPTY" \
               --plain --columns key,status --no-headers 2>/dev/null || true)
  [[ -n "$resolved" ]] || return 0
  while IFS=$'\t' read -r key status _; do
    [[ -n "$key" ]] || continue
    state=$(echo "$list" | awk -v w="${key}-qa-review" '$0 ~ w {print $3; exit}')
    printf '%s\t%s\t%s\t%s\n' "$key" "$status" "${state:-?}" "${key}-qa-review"
  done <<< "$resolved"
}

action="scan"
case "${1:-}" in
  --delete) action="delete"; shift ;;
  --stop)   action="stop";   shift ;;
esac

if [[ "$action" == "delete" ]]; then
  [[ $# -gt 0 ]] || { echo "usage: cleanup_qa.sh --delete <workspace>..." >&2; exit 1; }

  eligible=$(resolved_workspaces | cut -f4)
  if [[ -z "$eligible" ]]; then
    echo "refusing: no qa-review workspace currently has a resolved ticket — nothing is eligible." >&2
    exit 1
  fi

  # Validate every argument first, so a bad name can't leave a partial deletion.
  for ws in "$@"; do
    ws="${ws##*/}"
    grep -qxF "$ws" <<< "$eligible" || {
      echo "refusing: $ws — not in the resolved-ticket set." >&2
      echo "eligible right now:" >&2
      sed 's/^/  /' <<< "$eligible" >&2
      exit 1
    }
  done

  for ws in "$@"; do
    ws="${ws##*/}"
    echo "▶ delete: $ws"
    coder delete "$ws" -y

    # Deleting the workspace orphans two local artifacts. The herdr machine
    # profile is the one that bites: the sidebar keeps retrying a host that no
    # longer exists. Only --delete does this; a stopped workspace still exists,
    # so its profile stays valid.
    if command -v herdr > /dev/null 2>&1; then
      mid=$(herdr machine list --json 2>/dev/null \
              | python3 -c 'import json,sys
t = sys.argv[1].lower()
print(next((m["id"] for m in json.load(sys.stdin) if m["target"].lower() == t), ""))' "coder.$ws" 2>/dev/null || true)
      if [[ -n "${mid:-}" ]]; then
        herdr machine remove "$mid" > /dev/null 2>&1 \
          && echo "  removed herdr machine ($mid)" \
          || echo "  warning: could not remove herdr machine $mid" >&2
      fi
    fi

    # Harmless on its own, since dev-coder purges before it reconnects.
    ssh-keygen -R "coder.$ws" -f "$HOME/.ssh/known_hosts_coder" > /dev/null 2>&1 \
      && echo "  purged host key for coder.$ws"
  done
  echo "✅ delete complete ($# workspace(s))"
  exit 0
fi

if [[ "$action" == "stop" ]]; then
  [[ $# -gt 0 ]] || { echo "usage: cleanup_qa.sh --stop <workspace>..." >&2; exit 1; }
  for ws in "$@"; do
    ws="${ws##*/}"
    echo "▶ stop: $ws"
    coder stop "$ws" -y
  done
  echo "✅ stop complete ($# workspace(s))"
  exit 0
fi

# --- scan ---
rows=$(resolved_workspaces)
if [[ -z "$rows" ]]; then
  echo "No resolved-ticket workspaces to clean up."
  exit 0
fi

echo "Cleanup candidates (ticket resolved):"
printf '%-10s %-22s %-9s %s\n' TICKET STATUS CODER WORKSPACE
while IFS=$'\t' read -r key status state ws; do
  printf '%-10s %-22s %-9s %s\n' "$key" "$status" "$state" "$ws"
done <<< "$rows"
