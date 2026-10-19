---
name: e2e-playwright
description: E2e impact analysis for the Coyote (Rails) and Lyra (NX) Playwright suites — which specs cover a diff, ticket, or planned change, and whether the change breaks them or makes them pass without proving anything. Use only when the user explicitly asks about e2e, end-to-end, or Playwright tests ("will this break e2e", "which e2e specs cover this", "e2e blast radius for PT-1661", "e2e false positive"), or is about to run or write a Playwright spec. Do not use for general ticket planning, grooming, or code review that does not mention e2e.
compatibility: Coyote (Rails, playwright_tests/) and Lyra (NX, apps/*-e2e/), in either a csdev Coder workspace or a local bare-repo + worktree checkout
---

Static e2e impact analysis. This skill reads code; it does not stand up an environment.

Facts in this skill and its references (counts, line numbers, file paths) were true when written. Verify one before citing it.

## Guardrails

Apply whenever anyone in the session runs or writes a Playwright command, inside this skill or not:

- **Never run `playwright test` without a path filter.** Lyra's root `testDir` is `./apps/`, so collection walks Vitest `.spec.tsx` files, dies on a module resolution error, and runs nothing.
- **Never pass `--project=chromium` when the target includes `features/**`.** The `chromium` project ignores `features/**`, so those specs drop silently and the run exits 0. Omitting `--project` is correct; it is what CI does.
- **Never pass `--workers` above 1.** `features/` specs seed into shared reference data and race.
- **Locally, always set `DEV_TEST_BOX=true`.** Without it the config's URL chain falls through to a deployed domain and the run hits a real environment.
- **Never volunteer a new e2e test.** See Scaffold below.

## Locate the repos

```bash
[ -n "$CODER" ] || [ -n "$CODER_WORKSPACE_NAME" ]   # true => Coder workspace
```

| | Local — bare repo + worktrees | Coder — csdev workspace |
|---|---|---|
| `$COYOTE_ROOT` / `$LYRA_ROOT` | walk up from CWD to the repo root (`nx.json`, or `Gemfile` + `playwright_tests/`); siblings are `<workspace>/{coyote,lyra}/<branch-dir>` | `$HOME/workspace/{coyote,lyra}`, flat clones, one branch per workspace |
| Base ref | `staging` | `origin/staging` |

Resolve the base ref rather than assuming: `git rev-parse --verify staging 2>/dev/null || echo origin/staging`.

In Coder the two repos often sit on different branches (paired PRs carry different names per repo). Report each repo's branch before mapping; a ticket key that matches neither lives in another workspace (`rr dev <TICKET>`).

## Two test populations (Lyra)

| | `features/{domain}/` | everything else (legacy) |
|---|---|---|
| Data | seeds and tears down its own via `SeedClient` | queries pre-existing `e2e*`-prefixed rows |
| Project | `features` | `chromium` |

Coyote has no `features` project. See `reference/detectors.md` for why the split matters.

## Check

Work out what a change does to the suite — above all whether it makes an existing flow **pass without proving anything**. Never edit anything.

### Change surface

| Input | How | Findings are |
|---|---|---|
| Diff — `--branch <name>`, else the base ref | `git diff <base>...HEAD --name-only` | **actual** |
| Jira key or URL | `jira issue view <KEY> --plain` | **prospective** |
| Plain description | read it | **prospective** |

For a ticket, mine the description and any "Testing notes" section — they often name the exact flows to regression test. If the ticket is too vague to localize, say so and ask for the surface; a speculative blast radius is worse than none.

### Then

1. Build the spec→code map per `reference/map.md`, only the edges the change surface needs. Cache it in the scratchpad keyed by each repo's HEAD.
2. Change surface ∩ map → candidate specs.
3. Apply the detectors in `reference/detectors.md`.
4. Report.

### Report

Findings first, ordered by confidence:

```
<path>:<line>  [detector]  confidence: high|medium
  <test title, including its AIO key>
  Implicated by: <diff path, or the ticket line that points here>
  Why it still passes: <one sentence>
```

For prospective input, phrase findings as conditionals and label the section **Prospective**; never say a test *is* broken when no code has changed. End with **Flows to re-run after implementing**: concrete spec paths.

Close with an advisory **Coverage depth** section: covering specs that assert only presence of something whose value the change affects.

No candidates: `"No e2e specs implicated by <the diff|PT-XXXX>."` and stop.

## Running specs

This skill does not run the suite. If asked to:

- **Coder:** csdev provisions no `E2E_USER_EMAIL` / `E2E_USER_PASSWORD`, and every login path needs them. Say so and stop. For interactive runs once credentials exist, point at the Tilt UI-mode resources (`tilt enable lyra-coyote-playwright` on 8081, `coyote-playwright` on 8080). They invoke `playwright test` with no path filter, so expect Lyra's to show a collection error.
- **Local:** needs Rails (9000), Sidekiq, and Lyra (4301) up and the credentials in that repo's `.env`. Run from the repo root, path-scoped, under the guardrails:

  ```bash
  LOCAL=true DEV_TEST_BOX=true DEV_TEST_BOX_DOMAIN=localhost LYRA_URL=http://localhost:4301 \
    rtk playwright test <specs> --workers=1
  ```

  `LYRA_URL` is required in Coyote too; its login helper navigates to it.

## Scaffold

Only on explicit request. Gate first:

| Situation | Action |
|---|---|
| Not a happy path, edge case, or basic validation | Belongs in Vitest/RSpec or a component test. Say so, stop. |
| Discrete, business-critical feature on one page | `features/{domain}/` test |
| Multi-page, business-critical workflow | Full workflow test |

Model it on `$LYRA_ROOT/apps/coyote-e2e/playwright_tests/features/billing/hauler_collapse_pay_hold.spec.ts`, with a matching `$COYOTE_ROOT/db/seeds/e2e/create/<domain>/<name>.rb` whose records carry an `e2e<Name>` prefix. Use a bare `await seed.cleanup(...)`, never wrapped in `.catch()`. Title it `<PROJECT>-TC-PLACEHOLDER : <description>` and close with what the author must do:

1. Create the AIO case and replace the placeholder.
2. Add a workflow job or matrix entry with an `aio-tag`, or the spec never runs in CI.
3. Get Colton or Manuel to approve the PR.
