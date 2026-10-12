---
name: e2e-playwright
description: Playwright e2e guidance for the Coyote (Rails) and Lyra (NX) repos — which specs cover a change, whether it will break them or silently invalidate them, and how to run them in a Coder workspace or locally. Use whenever e2e, end-to-end, or Playwright tests come up, INCLUDING at planning or grooming time before any code exists. Triggers on "how will this affect/impact/effect our e2e tests", "what e2e coverage does this ticket have", "will this break e2e", "which e2e tests cover this", "e2e regression risk", "e2e blast radius", working out the e2e exposure of a Jira ticket or proposed change, "run e2e", "run playwright", "e2e false positive", and "--branch" PR workflows. Also runs specific specs and scaffolds a new feature test on request.
compatibility: Coyote (Rails, playwright_tests/) and Lyra (NX, apps/*-e2e/), in either a csdev Coder workspace or a local bare-repo + worktree checkout
---

Run and triage Playwright e2e tests across Coyote and Lyra. NEVER run `playwright test` without a path filter, and NEVER pass `--project=chromium` when the target set includes `features/**` — that combination silently drops the feature specs and still exits 0.

Parse $ARGUMENTS as: `[run|check|scaffold] [target] [--branch <name> | -b <name>] [--headed]`

If no mode is given: `run` when a target resolves, otherwise `check`.

`check` works with or without code. Use it at grooming or planning time — a Jira key, a ticket URL, or a plain description of intended work is a valid target, and that is the most useful moment to ask, because the implementation can still be shaped to avoid breaking a flow.

## Locate the repos

**Detect the environment first.** Every path, base ref, preflight check and run command below
branches on it, and getting it wrong is silent rather than loud.

```bash
[ -n "$CODER" ] || [ -n "$CODER_WORKSPACE_NAME" ]   # true => Coder workspace (csdev `acme`)
```

Coder is the standard environment for most engineers (`coyote/CLAUDE.md` names `csdev` the
default and `localdev` the fallback), so do not assume local.

| | **Local** — bare repo + worktrees | **Coder** — csdev `acme` workspace |
|---|---|---|
| Discovery | walk up from CWD to a dir holding `nx.json` (Lyra) or `Gemfile` + `playwright_tests/` (Coyote); that is the repo root, its **grandparent** is the workspace root | fixed: `$HOME/workspace/{coyote,lyra}`, flat clones. No walking, no grandparent |
| `$COYOTE_ROOT` | `<workspace>/coyote/<branch-dir>` | `$HOME/workspace/coyote` |
| `$LYRA_ROOT` | `<workspace>/lyra/<branch-dir>` | `$HOME/workspace/lyra` |
| Sibling branches | one worktree dir per branch, `staging` always present | none — **one branch per workspace** |
| Base ref | `staging` | `origin/staging` — a flat clone usually has no local `staging` |

Resolve the base ref instead of assuming:
`git rev-parse --verify staging 2>/dev/null || echo origin/staging`.

Use `$COYOTE_ROOT` / `$LYRA_ROOT` for every cross-repo path from here on, including in
`reference/map.md`.

### Confirm both repos before anything else (Coder)

Coyote and Lyra are independent clones there, and paired PRs for one ticket routinely carry
**different branch names per repo** — so a workspace can sit on the feature branch in one and
`staging` in the other. A Lyra spec failing against a stale Coyote is the most common false
alarm. Report both, don't assume:

```bash
for r in coyote lyra; do
  echo "$r $(git -C "$HOME/workspace/$r" rev-parse --abbrev-ref HEAD) \
behind=$(git -C "$HOME/workspace/$r" rev-list --count HEAD..@{u} 2>/dev/null || echo '?')"
done
```

### `.env`

| Local | Coder |
|---|---|
| Git-ignored, does not carry into a new worktree. If the repo root has no `.env`: `"No .env in <repo>/<wt>. Run: cp <repo>/staging/.env <repo>/<wt>/.env"` and stop. | csdev writes it from `apps/{coyote,lyra}/.env.coder.v2` plus the AWS secret set at `~/.aws/.env.coder`. **Never** emit the `cp .../staging/.env` line — there is no staging checkout to copy from. |

**csdev provisions no Playwright credentials.** `E2E_USER_EMAIL` and `E2E_USER_PASSWORD` appear
in neither `.env.coder.v2` nor the AWS secret set, yet Coyote reads them directly in 73 places
and Lyra takes them as the parameter defaults in `POM/login_page.ts` (`coyoteLogin`, `lyraLogin`,
`ensureLoggedIn`) — so every login path in both suites. In Coder this is a **hard stop**: say
they are missing and that they must be appended to `$COYOTE_ROOT/.env` and `$LYRA_ROOT/.env`.

Local is only half-provisioned too — `lyra/staging/.env` carries them, `coyote/staging/.env`
does not. Check the repo you are about to run, not the one you checked last time.

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
3. **Ticket key** (`PT-1417`, `EP-4440`) —
   - *Local*: find the sibling worktree directory whose name starts with that key, then diff it against the base ref and map.
   - *Coder*: there are no per-ticket directories — the **workspace is the ticket**. Check the key against the checked-out branch in each repo. If neither matches, stop and say so: that ticket lives in a different workspace (`rr dev <TICKET>`), and nothing in this one can be mapped to it.
4. **Bare word** (`billing`, `invoicing`) — `features/<word>/` plus any legacy spec directory whose name contains the word.
5. **Nothing** — diff the checked-out branch against the base ref and map.

If the mapping yields nothing: `"No e2e specs implicated by changes vs <branch>."` and stop.

## Preflight

Check all of these and report **every** failure at once — never launch a run that is going to fail on setup.
The checks are the same in both environments (they run inside the box either way); the **remedies differ**.

| Check | Command | Remedy — local | Remedy — Coder |
|---|---|---|---|
| Rails up | `curl -sf -o /dev/null localhost:9000` | start `rails server` | `tilt enable coyote` |
| **Sidekiq up** | `pgrep -f sidekiq` | start Sidekiq | `tilt enable coyote-workers` (service group) |
| Lyra up | `curl -sf -o /dev/null localhost:4301` | `pnpm nx serve coyote-base` | `tilt enable lyra-coyote` |
| Browsers | `npx playwright --version` | `pnpm playwright:setup` (Lyra) / `yarn playwright:setup` (Coyote) | `pnpm exec playwright install --with-deps` / `yarn playwright install --with-deps` |
| Creds | `E2E_USER_EMAIL` and `E2E_USER_PASSWORD` in that repo's `.env` | add them (Coyote's `.env` lacks them) | **not provisioned at all** — see `.env` above; hard stop |

Seeding is async, which is why Sidekiq matters: without it `seed()` polls for 600s and then
throws, the single most common setup failure in either environment.

**In Coder, services are Tilt resources, not processes you start by hand.** Which ones exist at
all is fixed by the `CODER_SERVICES` parameter chosen when the workspace was created, so a
workspace provisioned with a narrow selection may have no `coyote` resource to enable. `coyote`
(9000), `lyra-coyote` (4301) and the `coyote-workers` Sidekiq group are `autoInit: true` and come
up on their own when selected; the two Playwright resources are `autoInit: false` and never do.
Tilt's own UI is on `localhost:10350` if a resource is red and you need the log.

If the target set includes legacy (non-`features/`) specs, warn: those bind to pre-existing `e2e*`-prefixed rows and need a seeded DB — `bundle exec rails runner db/seeds/e2e/create/<domain>/<file>.rb`, or `./db/seeds/e2e/seed.sh` for the standard set.

## Run

Both `playwright.config.ts` files pick a URL scheme from a **first-match-wins** chain:
`CODESPACE_NAME` → `DEV_TEST_BOX` → `CODER_WORKSPACE` → deployed-domain fallback. `DEV_TEST_BOX`
sits *ahead* of `CODER_WORKSPACE`, so passing it inside a workspace silently suppresses the Coder
branch. That is why the env block differs per environment — it is not cosmetic.

### Local

`DEV_TEST_BOX` is required: with it unset, `CODER_WORKSPACE` is empty locally and the chain falls
through to the deployed-domain branch, which points the run at a real environment.

```bash
# Lyra
cd $LYRA_ROOT && LOCAL=true DEV_TEST_BOX=true DEV_TEST_BOX_DOMAIN=localhost \
  LYRA_URL=http://localhost:4301 rtk playwright test <specs> --workers=1

# Coyote
cd $COYOTE_ROOT && LOCAL=true DEV_TEST_BOX=true DEV_TEST_BOX_DOMAIN=localhost \
  LYRA_URL=http://localhost:4301 rtk playwright test <specs> --workers=1
```

`LYRA_URL` is required on **both**. Coyote's `DEV_TEST_BOX` branch sets only `COYOTE_URL`, but
`POM/login_page.ts:44` (`lyraLogin`) and two `engagements`/`invoicing` specs navigate to
`${process.env.LYRA_URL}/...`. Omit it and nine Coyote specs navigate to
`undefined/users/sign_in`.

### Coder

**Pass no URL env vars at all.** Let the config's `CODER_WORKSPACE` branch resolve them — Lyra
builds `https://{9000,4301}--main--$CODER_WORKSPACE_NAME--$CODER_WORKSPACE_OWNER_NAME.coder.dev.roadrunnerwm.com`,
Coyote reads `CODER_URL_COYOTE` / `CODER_URL_LYRA_COYOTE` from its `.env`. Both ports are declared
`visibility: public` in the csdev template, so the proxy URLs are not auth-gated and a headless
browser reaches them. This branch also sets `LYRA_URL`, which is the `lyraLogin` gap above closing
itself.

```bash
# Lyra
cd $LYRA_ROOT && pnpm exec playwright test <specs> --workers=1

# Coyote
cd $COYOTE_ROOT && npx playwright test <specs> --workers=1
```

Staying in-box instead — `DEV_TEST_BOX=true DEV_TEST_BOX_DOMAIN=localhost LYRA_URL=http://localhost:4301`
— also works and skips the proxy round-trip, but only if you pass `LYRA_URL` explicitly in both
repos. Use it when the proxy is the thing misbehaving; otherwise prefer the default above.

Two config behaviours key off `CODER_WORKSPACE` independently of `DEV_TEST_BOX`, so they apply
either way: the per-test timeout rises to 30 min (from 12), and `retries` becomes 1. Budget for a
failing spec taking roughly twice as long to report as it does locally.

`rtk` is on PATH locally; it is not part of the csdev image, so drop the prefix in Coder unless
`which rtk` says otherwise.

### `--headed`

Local: add the flag. Coder has no display — wrap it the way the csdev Playwright resources do:

```bash
xvfb-run --auto-servernum --server-args='-screen 0 1280x1024x24' <the command above> --headed
```

For interactive work in Coder, prefer Playwright's UI mode, which csdev already wires up:
`tilt enable lyra-coyote-playwright` (port 8081) or `tilt enable coyote-playwright` (port 8080),
then open that port's workspace URL. Both are `autoInit: false`, so they only run when enabled.
Note both resources invoke `playwright test` with **no path filter** — see the wrong-project
detector; expect the Lyra one in particular to surface a collection error rather than a usable
test tree.

When the target set spans both repos, run them as two separate commands — different cwd, different env.

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
3. On failure, give the HTML report path — `playwright-report/index.html` (Lyra) or `playwright_tests/test-results/index.html` (Coyote) — plus any screenshot paths. That is how the team debugs. In Coder the path alone is not openable: either serve it (`npx playwright show-report --host 0.0.0.0 --port <free port>`) and hand over that port's workspace URL, or say which screenshots to pull back over `coder ssh`.
4. Never dump a full run into the conversation.

---

# Mode: check

Work out what a change does to the e2e suite — above all whether it makes an existing flow **pass without proving anything**. Tests staying green after they stop testing is the target, not tests going red.

## Establish the change surface

Three input paths. All converge on a set of touched routes, components, models, tables, and seed files.

| Input | How | Findings are |
|---|---|---|
| **Diff** — `--branch <name>`, else the base ref | `git diff <base>...HEAD --name-only` | **actual** — this code changed |
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

Model a feature test on `$LYRA_ROOT/apps/coyote-e2e/playwright_tests/features/billing/hauler_collapse_pay_hold.spec.ts`: `SEED_FILE` + `SEED_PATTERN` constants, `test.describe.configure({ mode: 'serial' })`, `coyoteLogin()` **and** `lyraLogin()` in `beforeAll`, `SeedClient` with cleanup-before-seed to clear orphans, `try/finally` teardown. Use a bare `await seed.cleanup(...)` — do not wrap it in `.catch()` (see the swallowed-precondition detector). Add a matching `$COYOTE_ROOT/db/seeds/e2e/create/<domain>/<name>.rb` whose records carry an `e2e<Name>` identifier prefix matching `/^e2e[A-Za-z0-9]{3,}$/`.

Title the test `<PROJECT>-TC-PLACEHOLDER : <description>` and always close with the three things the skill cannot do:

1. Replace the placeholder with a real AIO key — **you create the case**, it is the author's responsibility.
2. Add a workflow job or matrix entry with an `aio-tag`, or the spec never runs in CI.
3. Get Colton or Manuel to approve the PR.

---

## Examples

| Invocation | Action |
|---|---|
| `/e2e-playwright run` | Diff the checked-out branch vs the base ref → map → preflight → run implicated specs |
| `/e2e-playwright run features/billing/hauler_collapse_pay_hold.spec.ts` | `cd $LYRA_ROOT` → run with `--project=features --workers=1` |
| `/e2e-playwright run billing` | One command over `features/billing/` + `billing-bills/` + `bills-dashboard-tests/` with **no** `--project` |
| `/e2e-playwright run PT-1417` | *Local*: resolve the `<repo>/PT-1417-*` worktree → diff vs base ref → map → run. *Coder*: match the key against each repo's branch, else stop |
| `/e2e-playwright check --branch staging` | Map → intersect diff → run all detectors → report, no edits |
| `/e2e-playwright check` | Same, diffing against the base ref |
| `/e2e-playwright check PT-1661` | `jira issue view PT-1661 --plain` → mine description + Testing notes → map → **prospective** findings + flows to re-run |
| `/e2e-playwright scaffold "hauler pay hold override"` | Apply the gate table, then emit spec + seed stub + the three follow-ups |
| `/e2e-playwright run billing` **in a Coder workspace** | `cd $HOME/workspace/lyra` → **no** `DEV_TEST_BOX`, no `rtk` → `pnpm exec playwright test ... --workers=1` |
| `/e2e-playwright run PT-1417` **in a Coder workspace** | Compare `PT-1417` against each repo's checked-out branch; if neither matches, stop and point at `rr dev PT-1417` |

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
| "run e2e" in a Coder workspace | Command carries **no** `DEV_TEST_BOX` / `DEV_TEST_BOX_DOMAIN` / `LYRA_URL`, and no `rtk` prefix |
| "run e2e" in a Coder workspace with no `E2E_USER_EMAIL` | Hard stop naming both `.env` files to append to — never the `cp .../staging/.env` line |
| "run e2e" in a Coder workspace with Rails down | Remedy is `tilt enable coyote`, not "start rails server" |
| "run the coyote bill entry e2e test" locally | Command carries `LYRA_URL=http://localhost:4301` even though the target is Coyote |
| "run e2e --headed" in a Coder workspace | Wrapped in `xvfb-run`, or routed to the `*-playwright` Tilt UI-mode resource |
| "add an e2e test for this required-field validation" | Refuses, routes to Vitest per the gate table |
| "write an e2e test for the collapse flow" | `features/billing/` spec with `TC-PLACEHOLDER`, seed stub, and all three follow-ups |
