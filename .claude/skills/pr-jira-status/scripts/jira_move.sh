#!/usr/bin/env bash
# Transition a Jira issue to a target STATUS by resolving the transition id from
# the API. Needed because `jira issue move` matches the transition *name*, and on
# this board "Ready for QA" hides behind a transition named "Transition to" that
# is shared by several transitions — so the name is ambiguous but the target
# status is unique. Matching on the destination status id is the reliable path.
#
# Usage: jira_move.sh <ISSUE-KEY> <TARGET-STATUS>
#   jira_move.sh PT-1539 "Ready for QA"
#
# Auth: token from $JIRA_API_TOKEN (falls back to the `jira-cli` keychain entry);
# server + login read from the jira-cli config.
set -euo pipefail

key="${1:?usage: jira_move.sh <ISSUE-KEY> <TARGET-STATUS>}"
target="${2:?usage: jira_move.sh <ISSUE-KEY> <TARGET-STATUS>}"

cfg="${JIRA_CONFIG_FILE:-$HOME/.config/.jira/.config.yml}"
server=$(sed -n 's/^server: *//p' "$cfg" | head -1)
login=$(sed -n 's/^login: *//p' "$cfg" | head -1)
token="${JIRA_API_TOKEN:-$(security find-generic-password -s jira-cli -w 2>/dev/null || true)}"

if [[ -z "$server" || -z "$login" || -z "$token" ]]; then
  echo "Error: missing Jira server/login/token (check $cfg and \$JIRA_API_TOKEN)" >&2
  exit 1
fi

tid=$(curl -sf -u "$login:$token" -H "Accept: application/json" \
        "$server/rest/api/3/issue/$key/transitions" \
      | python3 -c "import sys,json;print(next((t['id'] for t in json.load(sys.stdin)['transitions'] if t['to']['name'].lower()=='$target'.lower()),''))")

if [[ -z "$tid" ]]; then
  echo "Error: '$target' is not an available transition target for $key" >&2
  echo "Available:" >&2
  curl -sf -u "$login:$token" -H "Accept: application/json" \
    "$server/rest/api/3/issue/$key/transitions" \
    | python3 -c "import sys,json;[print('  -',t['to']['name']) for t in json.load(sys.stdin)['transitions']]" >&2
  exit 1
fi

code=$(curl -s -o /dev/null -w "%{http_code}" -u "$login:$token" -X POST \
  -H "Content-Type: application/json" --data "{\"transition\":{\"id\":\"$tid\"}}" \
  "$server/rest/api/3/issue/$key/transitions")

if [[ "$code" == "204" ]]; then
  echo "✅ $key → $target"
else
  echo "Error: transition POST returned HTTP $code" >&2
  exit 1
fi
