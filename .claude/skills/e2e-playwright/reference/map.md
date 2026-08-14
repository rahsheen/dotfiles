# Building the spec→code map

The map answers: *which e2e specs touch the code in this diff?* There is no manifest today, so derive it statically. Cache the result under the scratchpad keyed by `git rev-parse HEAD` of each repo; rebuild when either HEAD moves.

Five edge types. Build only the ones the change surface needs — if the diff is pure Ruby, the POM/selector edge is wasted work.

The same map serves a prospective run from a Jira ticket; only the input differs. For ticket input, read **Vocabulary bridging** at the bottom first — it is the usual reason a covering spec looks missing when it exists.

## 1. spec → seed file → Rails models

The strongest edge, because `features/` specs declare the dependency as a literal.

```ts
const SEED_FILE = 'db/seeds/e2e/create/billing/hauler_collapse_pay_hold.rb';
const SEED_PATTERN = 'e2eHaulerCollapsePayHold';
```

- Grep specs for `SEED_FILE`/`SEED_PATTERN` constants and for `seed(...)` / `seedCleanup(...)` / `.seed(...)` / `.cleanup(...)` call arguments. Coyote's legacy specs pass the path inline rather than via a constant.
- Resolve each path against `coyote/<wt>/` and read it.
- Extract referenced model constants (capitalized `Foo.create`, `Foo.find_by`, `Foo.new`) and any `require_relative` into `shared_test_setup.rb`.

A diff touching `app/models/<model>.rb`, a migration for its table, or the seed file itself implicates every spec on this edge.

## 2. spec → POM → selectors and routes

- Follow the spec's relative imports into `POM/`.
- Each POM may carry a `// POM for Page: <route>` header — that is the route index. Coverage is partial (24 of 44 Lyra POMs: 18/30 in `coyote-e2e`, 6/14 in `customer-portal-e2e`), so infer the rest from `page.goto(...)` calls in the POM and its callers.
- Harvest locator strings from POM fields and spec bodies: `page.locator('...')`, `getByRole`, `getByTestId`, `getByText`, `getByLabel`, and raw `text=` selectors.
- Classify each locator:
  - **test-id / role / label** — stable, low risk
  - **CSS class** — check whether it is a Tailwind utility (`bg-black/45`, `w-full`) versus a semantic class (`link-bill-credits-table-container`); utilities are high risk
  - **text** — substring-matched, see the substring-text-wait detector

Match harvested selectors against added/removed lines in the diff's `.tsx`/`.erb`/`.rb` view files.

## 3. spec → DB tables

Legacy specs resolve their data by querying Postgres directly rather than by using what a seed returned.

- Grep specs for `database.query(...)` and `database.<method>()`.
- For named methods, read the body in `POM/database.ts` to get the SQL.
- Extract table names and any `LIKE 'e2e%'` / `ILIKE` prefix.

Note the queries are string-interpolated, not parameterized, so the table name is usually a literal and easy to extract.

A diff touching a migration for one of those tables, or the seed that populates the matching `e2e*` prefix, implicates the spec.

## 4. spec → CI job

Determines whether the spec runs at all, and which AIO cycle its result lands in.

- Parse `test-files:` values across `coyote/<wt>/.github/workflows/playwright.yml`, `lyra/<wt>/.github/workflows/playwright.yml`, and the `customer-portal-playwright.yml` / `playwright-poc.yml` variants.
- Each is a glob (sometimes a multi-line list under `>-`). Expand and match against the spec path.
- Record the owning job name and its `aio-tag` (an AIO **cycle** key like `PT-CY-291`, not a case key).

A spec matching zero globs never runs — feed that to the unrun-spec detector.

## 5. spec → upload fixture

Cheap, high-precision, and the only reliable way to find file-upload flows — their test titles often do not contain the words a ticket uses.

- List `coyote/<wt>/playwright_tests/upload_files/` and `lyra/<wt>/apps/coyote-e2e/playwright_tests/upload_files/`.
- Grep specs for each filename.

Worked example: PT-1661's testing notes say *"sales bill bulk upload … live bill bulk upload"*. No test title contains "bulk upload". But `bulkSalesBillUpload.csv` and `bulkLiveBillUpload.csv` are both referenced by `playwright_tests/billing/bulk_bill_upload.spec.ts:16-19`, which is the covering spec. Title grep alone would have missed it.

Specs copy the fixture to a timestamped name before uploading (`bulkSalesBillUpload--${timestamp}.csv`), so match on the base filename, not the full literal.

## Vocabulary bridging (ticket input)

Ticket prose rarely uses the suite's nouns. Before concluding a flow is uncovered, try all of: test titles, `describe` block names, spec **filenames**, directory names, POM class and file names, POM route comments, upload fixture names, and seed file names under `db/seeds/e2e/create/`. Domain abbreviations matter — a ticket saying "HA/HATL creation" maps to `hauler_account` / hauler-account-to-location wording in code.

## AIO keys

The AIO **case** key is the literal prefix of the test title: `test('PT-TC-1337 : description')`. Playwright writes it into `<testcase name>` in `junit.xml`; AIO's importer parses it out. Nothing validates the format, so extract it with `/^([A-Z]+-TC-\d+)\s*:/` after stripping any `@tag`s, and treat a title that does not match as having no AIO case.

## Forward compatibility

`PT-1605` intends to replace the workflow matrix with folder-colocated `aio.json` for the `features/` tree only — the legacy workflow suite is out of its scope. Keep the map's internal shape (spec → {seedFiles, models, routes, selectors, tables, ciJob, aioCycle, aioCases}) stable so a manifest can populate those fields directly instead of parsing, without changing any detector.
