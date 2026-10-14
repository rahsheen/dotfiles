---
name: pr-jira-status
description: >-
  Show where the user's open pull requests and their linked Jira tickets stand
  on the path to merge. Use this whenever the user asks about their PRs, review
  status, what's mergeable, what's blocked, what needs reviews, "where do my
  tickets stand", "what's ready for QA", "what can I merge", "PR dashboard",
  "status of my work", or any check-in on the state of their in-flight
  engineering work. Correlates each open GitHub PR with its Jira ticket, applies
  the team's review rules, and renders a grouped, action-oriented dashboard.
  Trigger even when the user doesn't say the words "PR" or "Jira" but is clearly
  asking what they need to do next to move their work forward. Also handles
  "where do I stand on all open tickets", "everything on my plate", or any ask
  spanning work that has no PR yet — those are covered by default.
---

# PR / Jira mergeability status

A pointer at the `rr` console (`~/roadrunner/rr-tui`, on PATH as `rr`). Fetching
and correlating GitHub + Jira + Coder is deterministic logic and lives there in
code. Run `rr` — do not compose `gh` and `jira` calls by hand, and do not
re-derive the team's rules in prose.

## Run it

```bash
rr status              # the grouped dashboard, already rendered
rr status --actionable # only the groups the user can act on
rr status --prs-only   # narrow to PR-backed rows
rr changes             # what moved since the last check
rr status --json       # one JSON object per row — the stable contract
```

**Note the inversion vs. the old bundled script:** `rr status` already folds in
open assigned tickets that have no PR. There is no `--all`; `--prs-only` is how
you narrow.

Prefer plain `rr status` when the user wants the dashboard — it is already
grouped, sorted, wrapped and rendered, and rebuilding it from JSON only invites
drift. Reach for `--json` when you need to reason over fields: filtering,
answering "what exactly is blocking PT-1234", or joining against something `rr`
doesn't know about.

## The contract

One JSON object per row. A row is a unit of work — a ticket with its PRs,
workspace and herdr machine as optional facets.

| field | |
|---|---|
| `key` `title` `status` | the ticket (or a synthetic key for an orphan PR / workspace) |
| `state` `group` `action` | what `rr` concluded and the single next step, already in English |
| `flags` | the exceptions worth reading — surface these, they are why a row needs a human |
| `prs[]` | `repo` `number` `url` `branch` `draft` `labels` `approvals` `changes_requested` `review_decision` `merge_state` |
| `workspace` | `name` `status` `last_used_at` `dormant_at` `outdated` `url` |
| `machine` | the herdr machine, incl. `enabled` |
| `reclaim` | `{reason, detail, safe}` when the workspace could go, else null |
| `ticket_ref` | set when the row is linked to a ticket by branch name only — no Jira gate was applied |

`state` and `action` are the answer. If you need to know *why* a row says what
it says, read `src/rr/correlate.py` — the rules (approval counts, the Jira stage
gate before GitHub's `CLEAN`, code-owner ordering, parking) live there and
nowhere else. Restating them here is how the two drifted apart the first time.

## What is still yours

`rr` deliberately stops where judgment starts. Yours:

- reading ticket prose, and saying whether the work matches what was asked
- deciding whether a feature flag should be **on** in a QA env
- resolving a flag constant `rr followups` reports as `UNRESOLVED`
- the judgment calls in `rr reclaim` — anything rated `safe: false`

## Mutations belong to the user

Name the command and let them run it. Writes to Jira, provisioning, and
`coder delete` are user-driven on purpose — the agent's auto-mode classifier
hard-denies the last one, and a tool the user drives has no classifier in the way.

```bash
rr qa <ticket>              # env + CODER: comment + transition, gated on approvals
rr dev <ticket>             # provision a dev workspace, attach herdr, start an agent
rr followups <ticket>       # rake tasks / feature flags a fresh env won't have
rr reclaim                  # list reclaimable workspaces
rr reclaim --delete <ws>    # destroys the box; validated against live Jira state
rr run <ticket> '<cmd>'     # run a command in the ticket's workspace (no single quotes inside)
```

Nothing under `rr followups` is ever run automatically: rake tasks mutate data
and flags need a human call.

## If `rr` is missing

```bash
cd ~/roadrunner/rr-tui && uv venv && uv pip install -e .
```

Requires `gh`, `jira` and `coder` authenticated; `herdr` optional.
