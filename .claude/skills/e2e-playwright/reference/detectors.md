# False-positive detectors

Each detector finds a way a diff can make an existing spec **pass while proving nothing**. Report only — never edit. Every example below is real code in the suite today.

Confidence: **high** when the diff directly touches the named artifact; **medium** when the link is inferred through a POM or model.

---

## 1. Vacuous negative assertion

**Trigger:** the diff touches an element targeted by `not.toBeVisible()`, `not.toBeAttached()`, or `toHaveCount(0)`.

**Why:** a negative assertion passes trivially when the element is renamed, removed, moved behind a new route, or the page errors out. It cannot distinguish "correctly absent" from "no longer exists".

```ts
// lyra apps/coyote-e2e/playwright_tests/features/billing/hauler_collapse_pay_hold.spec.ts:76
await expect(collapseDashboard.payHoldAlertTitle).not.toBeVisible({ timeout: 15000 });
```

Worst variant — negative assertion on a *substring* text match, which passes if the copy changes at all:

```ts
// coyote playwright_tests/mirror_invoice_and_bill_pairing/one-off_rbbs_pairing.spec.ts:187
await expect(page.getByText('one-off', { exact: false })).not.toBeVisible();
```

Also check POM helpers: `POM/invoice_document_page.ts:88,117,127` use `not.toHaveCount(0)`.

---

## 2. Stale-data binding

**Trigger:** the spec resolves its subject via a `database.*()` query filtering on an `e2e*` prefix, and the diff touches that table's migration, its model, or the seed that populates the prefix.

**Why:** the spec binds to *whatever rows it finds*. If seeding silently produced nothing, or produced a differently-shaped record, the query can still return leftover rows from an earlier run and every assertion passes against the wrong record. This is the pattern Best Practices 2026.06.24 deprecated — *"Tests should seed & tear down their own data"* — but it still dominates the legacy suite.

```ts
const locationResult = await database.query(`SELECT * FROM locations WHERE name like 'e2eAdjCharg%'`);
```

Confidence is **high** when the spec has no `seed()` call at all and only queries.

---

## 3. Swallowed precondition

**Trigger:** a `seed(...)` or `seedCleanup(...)` inside `beforeAll` wrapped in `.catch()`, and the diff touches the referenced `.rb` seed or one of its models.

**Why:** the catch logs and continues. Seeding fails, the spec proceeds, and detector 2 then binds it to stale data. The failure is invisible in the run output beyond one `console.error`.

```ts
// coyote playwright_tests/adjustments/manual_charge_adjustment_location.spec.ts:23
await seedCleanup('e2eAdjCharg').catch((e) => console.error('seedCleanup failed:', e));
```

15+ sites across `adjustments/`, `engagements/`, `mirror_invoice_and_bill_pairing/`, `hashtags_mentions/`. Lyra's `features/` specs use a bare `await seed.cleanup(...)` and are **not** affected — do not flag them.

---

## 4. Substring text-wait

**Trigger:** a spec calls `loadCheckByText('X')` and the diff introduces the string `X` somewhere new on that route — a loading skeleton, toast, breadcrumb, nav item, or empty state.

**Why:** `loadCheckByText` is a wait, not a proof. Its implementation is `page.waitForSelector('text=' + text)`, and Playwright's unquoted `text=` is a **case-insensitive substring** match. It resolves against the first node containing the string, then retries across up to 3 page reloads before throwing. Add the text anywhere earlier in the render and the check satisfies before the real content loads.

```ts
// lyra apps/coyote-e2e/utils/utils.ts
await page.waitForSelector(`text=${text}`, { timeout: 30000 });
```

404 call sites (208 Coyote, 196 Lyra), so scope this detector to the routes the diff actually touches or it will drown the report.

---

## 5. Utility-class selector

**Trigger:** a spec or POM selector is a Tailwind utility class and the diff changes that class.

**Why:** the selector silently stops matching. It is usually inside a `.catch(() => {})` guard, so the step no-ops instead of failing and the test continues in an unexpected UI state.

```ts
// lyra apps/coyote-e2e/playwright_tests/features/billing/hauler_dispute_link_credit.spec.ts
const portalOverlay = page.locator('#dsl-portal .bg-black\\/45');
await portalOverlay.waitFor({ state: 'visible', timeout: 5000 }).catch(() => {});
if (await portalOverlay.isVisible()) { await page.keyboard.press('Escape'); }
```

Change the overlay opacity to `bg-black/50` and the Escape never fires. Distinguish utilities from semantic classes like `.link-bill-credits-table-container`, which are lower risk.

---

## 6. Unrun spec

**Trigger:** a spec path matches no `test-files` glob in any workflow job (map edge 4).

**Why:** the spec never runs. Its AIO case keeps whatever result it last got — indefinitely. The dashboard reads green because the result is stale, not because anything passed. A PR adding a spec in a new directory lands in this state by default.

Already true today of `smoke_navigation/bills.spec.ts` and `fleet-haul/cart_batch_change_order.spec.ts` in Lyra. Use those to sanity-check the detector.

---

## 7. Wrong-project invocation

**Trigger:** a directory or glob covering `features/**` run with `--project=chromium` — in a workflow job, a `coder_run_scripts/*.sh`, or a command the user is about to run.

**Why:** the `chromium` project sets `testIgnore: '**/features/**'`, so those specs are dropped from collection with no warning and the run **exits 0**. Indistinguishable from a clean pass.

Measured on `apps/coyote-e2e/playwright_tests`:

| Invocation | Collected |
|---|---|
| `--project=chromium` | 111 tests / 40 files |
| no `--project` | 118 tests / 44 files |

The 7-test, 4-file gap is the entire `features/billing/` tree, silently skipped.

Do **not** flag a missing `--project` flag on its own — omitting it is correct, and it is what CI does (`lyra/.github/actions/playwright/action.yml` passes no `--project`). Only `--project=chromium` over a features-inclusive target set is a finding. Naming a feature spec by explicit path under `chromium` is also not a finding: that exits 1 with `Error: No tests found`.

Related stale-glob instances worth reporting when nearby: `coder_run_scripts/{all_tests,billing}.sh` reference the deleted `details-tests/`, and `coyote playwright_tests/run_tests.sh:17` references a deleted `camera_services/`.

---

## Coverage depth (advisory, not a defect)

Separate section in the report. When a covering spec asserts only *presence* of something whose **value** the diff changes, name it:

> `PT-TC-1337` exercises this route but only asserts the banner is visible — it never asserts the amount your diff changes.

This is not statically decidable as a bug and must never be reported as a finding. It is a prompt for the author to decide whether the assertion is deep enough.
