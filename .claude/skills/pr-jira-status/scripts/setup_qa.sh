#!/usr/bin/env zsh
# Create/start a Coder QA workspace for a branch, then post the CODER: link to
# the Jira ticket — the two manual steps in the QA-handoff flow.
#
# Usage: setup_qa.sh <full-branch-name> <jira-ticket> [template]
#   setup_qa.sh PT-1539-display-bill-record-no PT-1539
#
# Does the three manual QA-handoff steps: build the Coder env, comment the
# CODER: link on the ticket, and transition the ticket to Ready for QA.
#
# The transition target is `$QA_MOVE_TO` (default "Ready for QA"). Set it empty
# (QA_MOVE_TO= setup_qa.sh ...) to skip the move and only do env + comment.
# Matched by target STATUS name — on this board "Ready for QA" sits behind a
# transition confusingly *named* "Transition to", so match on the status, not
# the transition name.
#
# qa-coder derives the workspace name (<ticket>-qa-review) from the BRANCH, so
# the URL we post is built from the branch's ticket id too. When the branch id
# and the comment ticket differ, that's the mismatch the dashboard warns about —
# this script still does exactly what you'd do by hand, just faster.
#
# GATE: the caller (the skill) is responsible for confirming the ticket has the
# required approvals before running this — the script itself does not re-check.
set -e

branch="$1"; ticket="$2"; template="${3:-acme}"
if [[ -z "$branch" || -z "$ticket" ]]; then
  echo "usage: setup_qa.sh <full-branch-name> <jira-ticket> [template]" >&2
  exit 1
fi

# Ticket id qa-coder will name the workspace after (parsed from the branch).
if [[ "$branch" =~ '^([A-Z]+-[0-9]+)' ]]; then
  ws_ticket="${match[1]}"
else
  echo "Error: no ticket id in branch name: $branch" >&2
  exit 1
fi

who=$(coder whoami 2>&1)
user=$(echo "$who" | sed -n 's/.*authenticated as \([^ ]*\).*/\1/p')
base=$(echo "$who" | sed -n 's#.*running at \(https://[^/ ,]*\).*#\1#p')
url="${base:-https://coder.dev.roadrunnerwm.com}/@${user}/${ws_ticket}-qa-review"

echo "▶ Building/starting Coder env for branch: $branch"
zsh -ic "qa-coder '$branch' '$template'"

# Surface QA follow-ups the fresh env won't have: rake tasks the branch adds
# (must be run) and Flipper flags it introduces (must be created). This only
# PRINTS them — the skill confirms with the user before running any, since rake
# tasks can mutate data and flags need a human call on on/off. Never abort setup
# if the scan fails.
ws_name="${ws_ticket}-qa-review"
echo "▶ Scanning PR diff for QA follow-ups (rake tasks / feature flags)"
python3 "$(dirname "$0")/qa_followups.py" --branch "$branch" --workspace "$ws_name" || true

echo "▶ Posting CODER link to $ticket"
jira issue comment add "$ticket" "CODER: $url"

target="${QA_MOVE_TO-Ready for QA}"
if [[ -n "$target" ]]; then
  echo "▶ Moving $ticket → $target"
  "$(dirname "$0")/jira_move.sh" "$ticket" "$target"
fi

echo "✅ QA ready: $url  (commented on $ticket${target:+, moved to $target})"
