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
  spanning work that has no PR yet — run with `--all` to fold in every open
  assigned Jira ticket alongside the PR-backed ones.
---

# PR / Jira mergeability status

Give the user one clear picture of every open PR they own, the state of its Jira
ticket, and the single next action that moves it toward merge.

## The team's rules (this is the whole point)

1. **Code Review → Ready for QA** requires **2 approving reviews** on the PR.
2. Once the Jira ticket reaches a **resolved status** (`Done`, `Resolved` by
   default — configurable), the PR needs a **CODEOWNER review** before it can be
   merged.

**The path to merge is a sequence — don't skip ahead.** approvals → move to
Ready for QA → QA runs → Testing → Ready for Acceptance → ticket resolves →
**then** a code-owner review → mergeable. The CODEOWNER step is the *last* one
and only applies once the ticket is resolved. A PR whose ticket is still in QA /
Testing / Acceptance is waiting on **QA sign-off**, not on a code owner — never
suggest nudging a code owner for those; there's nothing to merge until the
ticket resolves.

**How we detect mergeability:** use GitHub's `mergeStateStatus == CLEAN` — the
authoritative signal that GitHub will actually let you merge. It already reflects
*that repo's* branch protection: required review count, the code-owner rule if
the repo has one, status checks, and up-to-date-ness. Don't parse CODEOWNERS
files, and **do not infer mergeability from `reviewDecision == APPROVED`** — that
is repo-dependent and misleading. In repos with the code-owner rule (coyote,
lyra) `reviewDecision` stays `REVIEW_REQUIRED` until a code owner signs off, but
in a repo *without* that rule (e.g. **dsl**) two normal approvals flip it to
`APPROVED` with no code-owner review at all — and the PR can still be `BLOCKED`.
`CLEAN` is the only signal that holds across repos.

**`reviewDecision` does have one legitimate use: deciding *whose* action is next.**
Once a ticket is resolved and the PR still isn't `CLEAN`, `reviewDecision` tells
you whether the review gate is the blocker (`REVIEW_REQUIRED` → `needs_codeowner`,
go nudge someone) or whether reviews are done and only a mechanical fix remains
(`APPROVED` → `needs_update`: rebase, conflict, or CI — yours to do, nobody to
chase). That is a routing decision, **not** a mergeability claim — `CLEAN` still
decides mergeability. Conflating the two sends you chasing a code owner for a PR
that just needs a branch update.

## How to run it

Run the bundled script — it fetches everything in parallel and emits one JSON
object per PR (JSON Lines):

```bash
python3 ~/.claude/skills/pr-jira-status/scripts/pr_status.py
```

Requires `gh` and `jira` CLIs, both authenticated. The script keeps only PRs in
the configured org and pulls, per PR: approval count, `reviewDecision`,
`mergeStateStatus`, the Jira key parsed from the `[PT-1234]` title tag, and that
ticket's status. It computes a `state` and a plain-English `action` for each.
Every record carries a `kind` field — `"pr"` for PR-backed rows.

### Covering all open tickets (not just PRs)

When the user asks about **all** their work — "where do I stand on all open
tickets", "everything on my plate", tickets with no PR yet — add `--all`:

```bash
python3 ~/.claude/skills/pr-jira-status/scripts/pr_status.py --all
```

This additionally emits one `{"kind": "ticket"}` record for every open
(unresolved) ticket assigned to you that has **no open PR**. "Open" = Jira's
`resolution` field is empty (the canonical signal — cleanly excludes Done /
Resolved / Won't Do / Production Deployed without hardcoding status names).
Tickets that already have a PR are covered by their `kind: "pr"` record and are
not duplicated. Ticket-only records carry: `jira_key`, `jira_status`,
`jira_summary`, `jira_type`, a `state` (see below), an `action`, and a Jira
`url` (render it as a link). Default (no `--all`) stays PR-focused and skips the
extra Jira query — use it for pure PR/mergeability check-ins.

Ticket-only `state` values (derived from Jira status/type, no PR data):
`epic` (a tracking container), `todo`, `refined`, `in_progress`,
`review_no_pr` / `qa_no_pr` / `other_no_pr` (in that Jira stage but no open PR —
usually means the PR already merged; worth calling out).

Tune behavior with env vars if the user asks (e.g. "include Production Deployed
as resolved", "only show coyote", "I need 1 review not 2"):

- `PRJ_ORG` — org to keep PRs from (default `RoadRunnerEngineering`)
- `PRJ_RESOLVED` — fallback list of resolved status names (default `Done,Resolved`). Primary signal is Jira's `resolution` field being set; this list only applies when resolution is empty.
- `PRJ_REQUIRED` — reviews needed for Ready for QA (default `2`)
- `PRJ_QA_STATES` — Jira statuses that should have a Coder QA env (default `Ready for QA`)
- `PRJ_ALL_TICKETS` — set `1`/`true`/`yes` to force the all-tickets sweep without passing `--all`

## QA / Coder environments

QA can't start until a Coder environment exists for the branch, and the team's
source of truth is a `CODER: <url>` comment on the Jira ticket. So any ticket
**in or moving to Ready for QA** should have one. When any PR qualifies (its
ticket is in `PRJ_QA_STATES`, or it has enough approvals to move — states
`ready_for_qa`/`mergeable`), the script adds a `qa` object per PR:

- `qa.state` — `ok` (env exists + linked on Jira), `not_linked` (env exists but
  no `CODER:` comment yet — just needs the comment), or `missing` (no env).
- `qa.workspace_status` — `Started` / `Stopped` / null, from `coder list`.
- `qa.url` — the deterministic workspace URL.
- `qa.setup_cmd` — the exact `qa-coder <branch>` command to build it.

Gaps also surface as `flags` (🧪 …) so they show in the dashboard automatically.

**Important — how the link is derived.** `qa-coder` names the workspace from the
**branch's** ticket id (`<ticket>-qa-review`), while the dashboard tracks the
**title** tag. Normally identical. When they differ, the script emits a ⚠️ flag
(the env will be named after the branch's id, not the ticket) — surface it so
the user can rename the branch rather than silently mis-name the env.

### "Move X to QA" — the bundled one-shot action

When the user says **"move PT-1539 to QA"**, "ready PT-1539 for QA", or "set up
QA for PT-1539", treat it as one action that does all three manual steps:
build the Coder env, comment the `CODER:` link, and transition the ticket to
Ready for QA. Follow this sequence:

1. **Check the gate.** Run the dashboard script (or reuse its output) and
   confirm the ticket's PR(s) have the required approvals (state
   `ready_for_qa` or `mergeable`). If not, **stop** and say what's missing —
   never move a ticket that isn't actually reviewed.
2. **Check the branch/title match.** If the PR carries the ⚠️ branch-vs-title
   flag, warn that the QA env will be named after the branch's id. Do NOT
   suggest renaming the branch to fix it: on these repos renaming a branch that
   is a PR's head **closes the PR** (the REST rename deletes the head rather
   than retargeting). Just proceed with the branch-named env, or have the user
   fix it at the source in a way that doesn't touch the head branch.
3. **Confirm once**, showing the plan — approvals met, env to create, comment,
   and the status move. This is a real cloud workspace (minutes) plus a Jira
   write, so it always gets one confirmation.
4. **Run the bundled script:**
   ```bash
   ~/.claude/skills/pr-jira-status/scripts/setup_qa.sh <full-branch-name> <jira-ticket>
   ```
   Get `<full-branch-name>` from the PR's `branch` field and `<jira-ticket>`
   from `jira_key`. It runs `qa-coder` (idempotent — safe if the env already
   exists), posts the `CODER:` comment, and moves the ticket to **Ready for
   QA**. Every step is idempotent/safe to re-run.
5. **Handle QA follow-ups (rake tasks & feature flags).** A fresh env only has
   the branch code — one-off rake tasks haven't run and new Flipper flags don't
   exist. `setup_qa.sh` ends by scanning the PR diff (`qa_followups.py`) and
   **printing** any it finds; it does not run them. Relay the list to the user,
   confirm, then run the emitted `coder ssh` command for each approved item. See
   "QA follow-ups" below for the rules (skip `run_none`, flags are register-only
   by default).

**Variations:**
- Only the comment is missing (`qa.state == "not_linked"`): skip the build —
  `jira issue comment add <ticket> "CODER: <qa.url>"`, then move if the user
  wanted the transition.
- User wants the env but *not* the move: run with `QA_MOVE_TO=` set empty.
- Move only (env + comment already done): run `scripts/jira_move.sh <key>
  "Ready for QA"` directly instead of the whole flow.

### QA follow-ups — rake tasks & feature flags

A freshly-built Coder workspace has only the branch checked out — the checkout
script (`~/qa-setup.sh`) does a `git reset --hard` + `git checkout` and **nothing
else** (its `bundle install` / `db:migrate` block is commented out). So three
branch side effects won't be present until someone does them by hand in the env,
and all are easy to forget:

1. **Schema migrations** the branch adds (`db/migrate/*.rb`) — the env does NOT
   auto-migrate, so the branch's new columns/tables are missing until you run
   `rake db:migrate`.
2. **Rake tasks** the branch adds (backfills, data migrations, seeds) — QA must
   run them or it's testing against stale data.
3. **Feature flags** the branch introduces — the flag doesn't exist in the env's
   DB, so the new behavior can't be exercised until it's created. (Verified:
   merely *referencing* a flag doesn't create it — Flipper logs "Could not find
   feature … Call `Flipper.add` to create it".) Flags are introduced from **both
   sides**, and the detector covers both:
   - **Backend** — `Flipper.enabled?(:key)` / `Flipper[:key]` in Ruby.
   - **Frontend** — the Flipper-backed `/api/feature_flags` endpoint, reached via
     `useFeatureFlag(feature)` (singular, lyra) or `useFeatureFlags([...])`
     (plural array, coyote webpack). The string passed **is** the Flipper key
     (the controller feeds `names[]` straight into `Flipper.enabled?`), so a
     frontend-only lyra PR still needs the flag created in **coyote's** Flipper.
   The hook arg is often a constant (`FOO_FEATURE_FLAG`); the detector resolves
   it from a `const … = '…'` in the diff, then falls back to a repo code-search
   (constants usually pre-exist on `main`). Unresolved constants and raw endpoint
   hits are surfaced for you to confirm the key by hand — they carry no run
   command.

`scripts/qa_followups.py` detects all of these from the PR diff (no local
checkout — uses `gh pr diff`):

```bash
# by PR (what you usually have from the dashboard):
python3 ~/.claude/skills/pr-jira-status/scripts/qa_followups.py \
    --repo RoadRunnerEngineering/coyote --pr 13411 --workspace PT-1412-qa-review
# or by branch (resolves the open PR(s) itself); add --json for machine output:
python3 .../qa_followups.py --branch <branch> --workspace <ws>
```

`setup_qa.sh` runs this automatically after building the env. It **only prints**
the findings — running them is a confirmed step you drive, because rake tasks
can mutate data and flags need a human decision on state.

**How to act on the output:**
- Each item comes with a ready-to-run `coder_cmd` that calls
  `scripts/run_in_coder.sh <ws> <repo> '<cmd>'`. After the user confirms, run
  those directly. **Do not hand-build `coder ssh` commands** — the executor
  exists because two things bite otherwise: the Ruby toolchain (asdf) is only on
  the PATH under an interactive shell (so it wraps everything in `zsh -ic`), and
  multiple args after `coder ssh --` get re-split by the remote shell (so the
  command must be passed as one grouped string). It refuses commands containing
  single quotes for the same reason.
- Order the rake items **as emitted**: `migration` → `after_party` → one-off
  tasks. Backfills usually depend on the new schema, so migrate first.
- **Rake tasks** are categorized: `migration` (`db:migrate`), `after_party`
  (`after_party:run`), and one-offs by the repo's `lib/tasks/` convention —
  `run_once` (run it once), `run_on_demand` (run to exercise the feature), and
  **`run_none` — do NOT run** (surface it, but never offer to execute it). One-off
  task names are parsed from the diff assuming no namespace (matches the
  convention); each item includes a `verify` hint for the rare namespaced task.
- **Feature flags** default to **register-only** — `Flipper.add(:key)`. Verified
  against the ActiveRecord adapter: this INSERTs a `flipper_features` row, so the
  flag is genuinely **created** (and shows in the Flipper UI) with **state=off**
  — created, not activated. Each item also carries an `enable_cmd`
  (`Flipper.enable(:key)`, which creates *and* turns it on) — offer it if the
  user wants the flag on immediately.
- **Flags are always created in coyote** (`PRJ_FLIPPER_REPO`), even for a
  lyra-only PR — the coyote+lyra pair shares one workspace with coyote checked
  out, and Flipper only lives in coyote. The `coder_cmd` already targets coyote
  regardless of which repo's PR surfaced the flag.
- Items with `resolved: false` (an unresolved hook constant, or a raw
  `feature_flags` endpoint hit) have **no** `coder_cmd`. Surface them, resolve
  the key by hand (or ask the user), then add the flag.
- Flag detection reads **added lines**, so it's deliberately generous — it can
  report a flag that's merely referenced or re-touched (not strictly new). For a
  fresh env that's usually right (the flag won't exist either way), but when in
  doubt show the file and let the user decide.
- **Not covered:** Optimizely-backed flags (`OptimizelyService` /
  `Extensions::FeatureFlags#feature_enabled?` / the `useDecision` hook) are a
  separate system managed in the Optimizely dashboard — there's no `Flipper.add`
  for them. If a PR uses that path, flag it for manual setup rather than emitting
  a create command.
- Repos live at `~/workspace/<repo>` in the workspace (override with
  `QA_WORKSPACE_ROOT`, read by `run_in_coder.sh`).

**Why the move uses a helper, not `jira issue move`:** on this board
`jira issue move` matches the transition *name*, and "Ready for QA" hides behind
a transition confusingly named "Transition to" that several transitions share —
so the name is ambiguous and `jira issue move <key> "Ready for QA"` fails with
"invalid transition state". `scripts/jira_move.sh` instead resolves the
transition **id** whose destination status matches (unique) and POSTs it via the
REST API. It reads server/login from the jira-cli config and the token from
`$JIRA_API_TOKEN` (or the keychain). Always transition via this helper.

## The `state` values the script emits

| state | meaning |
|---|---|
| `needs_codeowner` | Ticket is resolved, the PR isn't `CLEAN`, **and `reviewDecision` is not `APPROVED`** — the review gate is still open, so it needs the final required (code-owner) review. This is the ONLY state where a code-owner nudge is the right action. Highest urgency. |
| `needs_update` | Ticket is resolved and **`reviewDecision == APPROVED`** but the PR still isn't `CLEAN` — the review gate is already satisfied, so the blocker is mechanical and **yours to fix**: `BEHIND` → update the branch, `DIRTY` → resolve conflicts, `UNSTABLE` → fix CI. Never nudge a reviewer for these. Usually one self-serve step from mergeable. |
| `changes_requested` | A reviewer requested changes; address them. |
| `needs_review` | Fewer than the required approvals. |
| `ready_for_qa` | Enough approvals but the ticket hasn't been moved into QA yet — **your** action: advance it to Ready for QA (and stand up a QA env). Not a code-owner step. |
| `in_qa` | Ticket is already in QA / Testing / Acceptance. Approved and riding through the pipeline — awaiting **QA sign-off**, not a code owner. No action; just monitor. |
| `mergeable` | `mergeStateStatus == CLEAN` — GitHub says all required reviews & checks passed; ready to merge. (Not inferred from `reviewDecision`.) |
| `draft` | Draft PR, not up for review yet. |

Each PR may also carry `flags` — notable mismatches to call out, e.g. "Ticket
still in Code Review despite enough approvals — advance it", or a `DIRTY`
(merge conflict) / `UNSTABLE` (failing checks) merge state.

With `--all`, ticket-only records (`kind: "ticket"`) add these PR-less states:
`epic`, `todo`, `refined`, `in_progress`, `review_no_pr`, `qa_no_pr`,
`other_no_pr` — described under "Covering all open tickets" above.

## How to present it

Render a **grouped markdown dashboard**, ordered so the user sees what needs
action first. Lead with a one-line summary ("5 need attention, 8 waiting on
code owner, 1 mergeable"), then these groups — **skip any that are empty**:

1. **🟢 Mergeable** — `mergeable`. They can merge now.
2. **🟠 One step from merge** — `needs_update`. Reviews are done; a rebase,
   conflict, or CI fix stands between this and mergeable, and it's the user's own
   to do. Highest leverage after group 1 because it needs nobody else. State the
   specific fix from `action` — never suggest chasing a reviewer here.
3. **🔴 Needs attention** — `needs_codeowner`, `changes_requested`,
   `needs_review`, plus any PR carrying a `flag`. This is where the user should
   spend time. Note `needs_codeowner` is the one place a **code-owner nudge** is
   the correct action (ticket resolved, review gate still open).
4. **🟡 Ready to move to QA** — `ready_for_qa` with no flags. Actionable by the
   user: advance the ticket to Ready for QA and stand up its QA env. *Not* a
   code-owner step.
5. **🔵 In QA / acceptance** — `in_qa`. Approved and moving through
   QA/Testing/Acceptance; waiting on **QA sign-off**, not a code owner. Healthy —
   just monitor. Do NOT suggest pinging a code owner here.
6. **⚪ Draft / early** — `draft`, or PRs whose ticket is still `To Do`.
7. **📋 Tickets without a PR** *(only when `--all` was used)* — the
   `kind: "ticket"` records: `in_progress` / `review_no_pr` / `qa_no_pr` first
   (active work), then `refined` / `todo` (not started), then `epic` records
   last as a tracking footnote. A `review_no_pr` / `qa_no_pr` ticket usually
   means its PR already merged — note that rather than treating it as a gap.

Use a compact table per group. Always render each PR as a markdown link using
its `url` field — `[repo#number](url)` — never as bare text, so terminals with
OSC 8 hyperlink support make it clickable. Include, per row: Jira key + status,
the **branch name** (from the `branch` field, as inline code — it's the most
scannable "what is this" identifier, so always show it), approval count, and
the `action`. For ticket-only rows (no branch/approvals), link the `jira_key`
to its `url` and show status, type, and `action`. Surface every `flag`
prominently — those are the discrepancies the user most wants to catch (a
ticket that should have advanced, a merge conflict, failing CI).

When two PRs share a Jira key (a coyote + lyra pair for the same story), keep
them together and note the ticket only advances when **both** clear their
reviews.

If the user asks only for action items, show groups 1–2 and drop the healthy
ones. If they name a repo, filter to it. Keep prose minimal — the table and the
next-action column are the deliverable.
