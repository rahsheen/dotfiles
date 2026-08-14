---
name: e2e-playwright
description: Playwright e2e guidance for the Coyote (Rails) and Lyra (NX) repos — which specs cover a change, whether it will break them or silently invalidate them, and how to run them locally. Use whenever e2e, end-to-end, or Playwright tests come up, INCLUDING at planning or grooming time before any code exists. Triggers on "how will this affect/impact/effect our e2e tests", "what e2e coverage does this ticket have", "will this break e2e", "which e2e tests cover this", "e2e regression risk", "e2e blast radius", working out the e2e exposure of a Jira ticket or proposed change, "run e2e", "run playwright", "e2e false positive", and "--branch" PR workflows. Also runs specific specs locally and scaffolds a new feature test on request.
compatibility: The roadrunner workspace — Coyote (Rails, playwright_tests/) and Lyra (NX, apps/*-e2e/)
---

Run and triage Playwright e2e tests across Coyote and Lyra. NEVER run `playwright test` without a path filter, and NEVER pass `--project=chromium` when the target set includes `features/**` — that combination silently drops the feature specs and still exits 0.

Parse $ARGUMENTS as: `[run|check|scaffold] [target] [--branch <name> | -b <name>] [--headed]`

If no mode is given: `run` when a target resolves, otherwise `check`.

`check` works with or without code. Use it at grooming or planning time — a Jira key, a ticket URL, or a plain description of intended work is a valid target, and that is the most useful moment to ask, because the implementation can still be shaped to avoid breaking a flow.

## Find the workspace

Walk up from CWD until you hit a directory containing either `nx.json` (Lyra worktree) or both `Gemfile` and `playwright_tests/` (Coyote worktree). That directory is the repo root; its grandparent is the workspace root (`roadrunner/`). Sibling worktrees are `<workspace>/{coyote,lyra}/<branch-dir>`, with `staging` always present.

`.env` is git-ignored and does not carry into new worktrees. If the repo root has no `.env`, output:
`"No .env in <repo>/<wt>. Run: cp <repo>/staging/.env <repo>/<wt>/.env"` and stop.

## Two test populations

Every mode branches on this. See `reference/detectors.md` for why it matters.

| | `features/{domain}/` | everything else |
|---|---|---|
| Data | seeds and tears down its own via `SeedClient` | queries pre-existing `e2e*`-prefixed DB rows (deprecated) |
| Project | `features` (`testMatch: '**/features/**/*.spec.ts'`) | `chromium` (`testIgnore: '**/features/**'`) |
| Runtime | 5–30s | 1–5+ min |

Coyote has no `features` project — the split is Lyra-only.

---

# Mode: run

## Resolve the target

Apply in order, stopping at the first match:

1. **Contains `/`** — treat as an explicit spec path or directory, use directly.
2. **`--branch <name>`** — `git diff <name>...HEAD --name-only`, then map to specs per `reference/map.md`.
3. **Ticket key** (`PT-1417`, `EP-4440`) — find the sibling worktree directory whose name starts with that key, then diff it against `staging` and map.
4. **Bare word** (`billing`, `invoicing`) — `features/<word>/` plus any legacy spec directory whose name contains the word.
5. **Nothing** — diff the current worktree against `staging` and map.

If the mapping yields nothing: `"No e2e specs implicated by changes vs <branch>."` and stop.

## Preflight

Check all of these and report **every** failure at once — never launch a run that is going to fail on setup.

| Check | Command | Why |
|---|---|---|
| Rails up | `curl -sf -o /dev/null localhost:9000` | `COYOTE_URL` target; also serves the seed endpoints |
| **Sidekiq up** | `pgrep -f sidekiq` | Seeding is async. Without it `seed()` polls 600s then throws — the most common local failure |
| Lyra up | `curl -sf -o /dev/null localhost:4301` | Only when the target set includes Lyra specs |
| Browsers | `npx playwright --version` | Else `pnpm playwright:setup` (Lyra) / `yarn playwright:setup` (Coyote) |
| Creds | `E2E_USER_EMAIL` and `E2E_USER_PASSWORD` in `.env` | Every spec logs in through the UI; there is no `storageState` |

If the target set includes legacy (non-`features/`) specs, warn: those bind to pre-existing `e2e*`-prefixed rows and need a seeded DB — `bundle exec rails runner db/seeds/e2e/create/<domain>/<file>.rb`, or `./db/seeds/e2e/seed.sh` for the standard set.

## Run

```bash
# Lyra
cd <workspace>/lyra/<wt> && LOCAL=true DEV_TEST_BOX=true DEV_TEST_BOX_DOMAIN=localhost \
  LYRA_URL=http://localhost:4301 rtk playwright test <specs> --workers=1

# Coyote
cd <workspace>/coyote/<wt> && LOCAL=true DEV_TEST_BOX=true DEV_TEST_BOX_DOMAIN=localhost \
  rtk playwright test <specs> --workers=1
```

Add `--headed` when asked. When the target set spans both repos, run them as two separate commands — different cwd, different env.

### Choosing `--project` (Lyra only)

Omitting `--project` is the safe default and is exactly what CI does: each spec is routed to the project whose `testMatch`/`testIgnore` claims it. Only add the flag to *narrow* a run:

| Target set | Flag |
|---|---|
| Mixed, or unsure | omit — both projects run, each spec routed correctly |
| Only `features/**` | `--project=features` (optional; narrows output) |
| Only legacy specs | `--project=chromium` (optional) |

- **NEVER pass `--project=chromium` when any `features/**` spec is in the target set.** Verified against a directory-scoped run: `--project=chromium` collected **111 tests**, no flag collected **118**. The 7 feature tests were dropped with no warning and exit 0. Naming a feature spec by explicit path under `chromium` is safe by comparison — that fails loudly with `Error: No tests found` and exit 1.
- **NEVER run bare `playwright test` with no path filter.** Lyra's root `testDir` is `./apps/`, so collection walks `apps/customer-portal/src/` and tries to load Vitest `.spec.tsx` files. It dies during collection on a `@roadrunnerengineering/dsl` module resolution error and runs nothing. Always pass a path.
- **NEVER pass `--workers` greater than 1.** `features/` specs seed into shared reference data and race.

## Output Handling

Playwright output is large and video is recorded unconditionally.

1. **Summarize first**: pass/fail counts and the titles of any failed tests.
2. **Large output** (>~100 lines): redirect and read targeted sections.
   ```bash
   rtk playwright test <specs> --workers=1 2>&1 > /tmp/pw_out.txt; wc -l /tmp/pw_out.txt
   ```
3. On failure, give the HTML report path — `playwright-report/index.html` (Lyra) or `playwright_tests/test-results/index.html` (Coyote) — plus any screenshot paths. That is how the team debugs.
4. Never dump a full run into the conversation.

---

# Mode: check

Work out what a change does to the e2e suite — above all whether it makes an existing flow **pass without proving anything**. Tests staying green after they stop testing is the target, not tests going red.

## Establish the change surface

Three input paths. All converge on a set of touched routes, components, models, tables, and seed files.

| Input | How | Findings are |
|---|---|---|
| **Diff** — `--branch <name>`, else vs `staging` | `git diff <base>...HEAD --name-only` | **actual** — this code changed |
| **Ticket** — a Jira key (`PT-1661`) or browse URL | `jira issue view <KEY> --plain` | **prospective** — this work is planned |
| **Description** — plain prose | read it directly | **prospective** |

For a ticket, mine the description *and* any "Tech Notes" / "Testing notes" section — they frequently name the exact flows to regression test in prose ("sales bill bulk upload HA and HATL creation…"). Map those named flows to specs directly; it is the highest-signal input available. Grep spec titles, `describe` blocks, and POM route comments for the nouns.

When the ticket names a Jira epic or links code, follow it. When it is too vague to localize, say so and ask for the surface rather than guessing — a speculative blast radius is worse than none.

## Then

1. Build the spec→code map per `reference/map.md`. Cache it under the scratchpad keyed by repo HEAD.
2. Change surface ∩ map → candidate specs.
3. Apply every detector in `reference/detectors.md`.
4. Report. **Never edit anything in this mode.**

## Report

Findings first, ordered by confidence:

```
<path>:<line>  [detector]  confidence: high|medium
  <test title, including its AIO key>
  Implicated by: <diff path, or the ticket line that points here>
  Why it still passes: <one sentence>
```

For prospective runs, phrase findings as conditionals — *"if you rename `payHoldAlertTitle`, PT-TC-1339's `not.toBeVisible()` goes vacuous"* — and label the section **Prospective**. Never state that a test *is* broken when no code has changed.

Prospective runs should also carry a short **Flows to re-run after implementing** list: the concrete spec paths, ready to hand to `run`. That is usually what the person actually wanted.

Close with a **Coverage depth** section, clearly advisory: where a covering spec only asserts visibility of something whose *value* the change affects, say so. Coverage quality, not a defect.

If no candidate specs: `"No e2e specs implicated by <the diff|PT-XXXX>."` and stop. Do not speculate a list.

---

# Mode: scaffold

**Only on explicit request.** Never volunteer a new test. Per Playwright Best Practices 2026.06.24: *"AI generated code is known to add lower level feature testing that we do not want."*

Gate before writing anything:

| Situation | Action |
|---|---|
| Not a happy path | Belongs in Vitest/RSpec. Say so, stop. |
| Edge case or basic validation | Component test. Say so, stop. |
| Discrete feature, one page, business-critical | `features/{domain}/` test |
| Multi-page, cross-feature, business-critical | Full workflow test |

Model a feature test on `lyra/<wt>/apps/coyote-e2e/playwright_tests/features/billing/hauler_collapse_pay_hold.spec.ts`: `SEED_FILE` + `SEED_PATTERN` constants, `test.describe.configure({ mode: 'serial' })`, `coyoteLogin()` **and** `lyraLogin()` in `beforeAll`, `SeedClient` with cleanup-before-seed to clear orphans, `try/finally` teardown. Use a bare `await seed.cleanup(...)` — do not wrap it in `.catch()` (see the swallowed-precondition detector). Add a matching `coyote/<wt>/db/seeds/e2e/create/<domain>/<name>.rb` whose records carry an `e2e<Name>` identifier prefix matching `/^e2e[A-Za-z0-9]{3,}$/`.

Title the test `<PROJECT>-TC-PLACEHOLDER : <description>` and always close with the three things the skill cannot do:

1. Replace the placeholder with a real AIO key — **you create the case**, it is the author's responsibility.
2. Add a workflow job or matrix entry with an `aio-tag`, or the spec never runs in CI.
3. Get Colton or Manuel to approve the PR.

---

## Examples

| Invocation | Action |
|---|---|
| `/e2e-playwright run` | Diff current worktree vs `staging` → map → preflight → run implicated specs |
| `/e2e-playwright run features/billing/hauler_collapse_pay_hold.spec.ts` | `cd lyra/<wt>` → run with `--project=features --workers=1` |
| `/e2e-playwright run billing` | One command over `features/billing/` + `billing-bills/` + `bills-dashboard-tests/` with **no** `--project` |
| `/e2e-playwright run PT-1417` | Resolve `<repo>/PT-1417-*` worktree → diff vs `staging` → map → run |
| `/e2e-playwright check --branch staging` | Map → intersect diff → run all detectors → report, no edits |
| `/e2e-playwright check` | Same, diffing against `staging` |
| `/e2e-playwright check PT-1661` | `jira issue view PT-1661 --plain` → mine description + Testing notes → map → **prospective** findings + flows to re-run |
| `/e2e-playwright scaffold "hauler pay hold override"` | Apply the gate table, then emit spec + seed stub + the three follow-ups |

## Expected Behavior

Use these to verify the skill is working correctly before shipping changes.

| Prompt | Expected action |
|---|---|
| "run the pay hold e2e test" | Command carries `--workers=1` and either `--project=features` or no `--project`; never `--project=chromium` |
| "run e2e" with Rails down | Reports Rails and Sidekiq status together and stops — does not launch Playwright |
| "run e2e" from a worktree with no `.env` | Outputs the `cp <repo>/staging/.env ...` line and stops |
| "run all the billing e2e tests" | A single path-scoped command with no `--project`, never `--workers=2` |
| "will this PR break e2e" | Enters `check`, builds the map, reports findings with file:line and confidence, edits nothing |
| "will this PR break e2e" on a diff touching no mapped code | Outputs "No e2e specs implicated by changes vs staging." |
| "look at PT-1661 and plan it — how will this affect our e2e tests?" | Skill fires despite the prompt being mostly about planning; runs `check` on the ticket, findings labeled **Prospective**, ends with flows to re-run |
| "how will this effect e2e" (misspelled) | Fires — `affect`/`effect`/`impact` are all trigger spellings |
| A ticket too vague to localize | Says so and asks which area is being changed; does not guess a blast radius |
| "add an e2e test for this required-field validation" | Refuses, routes to Vitest per the gate table |
| "write an e2e test for the collapse flow" | `features/billing/` spec with `TC-PLACEHOLDER`, seed stub, and all three follow-ups |
