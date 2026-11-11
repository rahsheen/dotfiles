---
name: ticket-readiness
description: >-
  Readiness check for a Jira ticket before implementation: reads the ticket and
  the code it touches, reports the gaps, and drafts a Jira comment. Use for one
  ticket ("is PT-1234 ready", "should I start this") or in bulk over a sprint
  or filter at grooming and refinement.
---

# Ticket readiness

Decide whether a ticket is defined well enough to implement, and if not, say
exactly what is missing and who has to answer it.

**This runs before implementation, not during it.** The point is to move the
discovery of missing edge cases from "three hours into the branch" to "grooming,
where it costs a comment." Run it in bulk over sprint candidates a few days
before planning so the gaps go back to the PM asynchronously.

## Read-only: the user posts

This skill reads Jira and writes nothing to it. Its output is content for the
user to share: the verdict, the gap list, and draft comments in fenced blocks,
ready to paste. The user decides what goes out and when, because a comment is
visible to the whole team. This holds in every mode, bulk included: no
comments, transitions, labels, field edits, or assignee changes. Write to Jira
only when the user asks for that specific write in this session.

## Non-negotiable: ground every probe in the code

A readiness check that only reads the ticket produces generic questions
("what about error cases?") that everyone learns to skip. **Every gap you report
must cite something real** — a status enum value, a nullable column, a policy
rule, an existing caller, a spec file. If you cannot point at the code that
makes a question matter, delete the question.

This means step 2 below is the expensive step and you do not get to skip it.

## Process

### 1. Read the ticket

Read the ticket with the Jira tool you have, including its comments. With
jira-cli:

```bash
jira issue view <KEY> --plain --comments 20
```

With the Atlassian MCP, fetch the issue and its comments. If neither is
available, ask the user to paste the ticket.

Check the status first. If the ticket is past In Progress (in review, QA,
Ready for Acceptance, or Done), a readiness check does not apply. Report the
status and the open blocker from the latest comments, then stop.

Read the description, the acceptance criteria, the comments (decisions often
live only there), linked issues, and any attached design. View attachments
with the `jira-attachments` skill when you have it. Note what the ticket
*claims* — the actors, the entities, the trigger, the outcome.

### 2. Locate the code

Find the code the ticket touches, using the ticket's domain nouns rather than
its exact wording. You need, at minimum:

- the model(s) / entity(ies) named or implied
- their statuses, states, or lifecycle enums
- the authorization surface (policy, ability, `can?`, guard, role check)
- the schema for any field being read or written (nullability, defaults, indexes)
- the existing callers of anything being modified
- the existing tests covering that path

Delegate this with the `Explore` agent when it spans more than a couple of
files. If the codebase has a domain glossary or ADRs in the area, read them —
a ticket that contradicts an ADR is a gap, not an instruction.

### 3. Run the probes

For each probe, the question is always: *does the ticket say what happens, and
does the code offer a case the ticket didn't consider?* Report only the ones
where the code shows a real branch the ticket is silent on.

| Probe | What to actually look at |
|---|---|
| **Actors & permissions** | The policy/ability for the resource. Which roles can reach this? Does the ticket say what the others see — hidden, disabled, or 403? |
| **Lifecycle states** | The status enum / state machine. List every value. Which ones does the ticket address? The unaddressed ones are the gap. |
| **Cardinality** | Zero, one, many. What renders at 0 rows? What happens at 10k — is there pagination, a timeout, an N+1? |
| **Nullability & existing data** | The migration/schema. Is a new field nullable? What do rows created before this change do? Is a backfill needed, and does the ticket mention it? |
| **Idempotency & concurrency** | Is this reachable twice — double-click, retry, a job that can re-run, a webhook that can redeliver? Does the code have a uniqueness constraint or a lock, or does the ticket assume one exists? |
| **External dependencies** | Every network/service call on the path. What does the ticket say happens when it times out or 500s? Usually: nothing. |
| **Blast radius** | Existing callers of a modified method/endpoint/component. For a changed page, also the inbound links and routes into it, with their query params — a link that hard-codes a param can override the new behavior. Does the ticket acknowledge them? |
| **In-flight work** | Open PRs on the files from step 2: `gh pr list --state open --limit 200 --json number,title,headRefName,files`, intersected with that file list. Also any open PR the work must build on. Name each one. Does the ticket say whether to wait, stack, or coordinate? A shared abstraction designed against a file that an open PR rewrites is rework. |
| **Point-in-time vs current** | A displayed or exported field that has both a value stored on the record and a live value on an associated record (e.g. a vendor ID on the synced bill vs on the vendor today). Which one does the ticket mean? Ask the reporter. |
| **Test invalidation** | Existing specs on the path. Will this change break them, or worse, silently make them assert nothing? Include e2e specs (Playwright) that drive the affected page or endpoint. If an e2e impact skill such as `e2e-playwright` is installed, hand off to it for this probe: it finds specs that would keep passing without proving anything. |
| **UI states** | Frontend tickets only. The component's loading, empty, and error states, and what a role without access sees (hidden or disabled). Does the ticket or design cover each state the component renders? |
| **Rollout & reversibility** | Is this behind a flag? If it's wrong in production, what's the undo? Data migrations especially. |
| **Contradiction** | Does the ticket assert something the code disproves? ("currently users can't X" — but they can.) This is the highest-value find and it is only findable by reading the code. |

Not every probe applies to every ticket. A copy change needs three of these; a
schema change needs most of them. Don't pad.

### 4. The acceptance-criteria test

This is the objective gate, and it's mechanical:

> **Every acceptance criterion must be rewritable as `Given <concrete state>,
> when <concrete action>, then <observable outcome>` — with real values, not
> placeholders. If you cannot name the test you'd write for it, the criterion is
> not a criterion.**

Apply it to each AC and show the rewrite. When an AC fails the test, the
sharpened version *is* the question you send back.

<example>
**As written:** "The dashboard should handle large accounts gracefully."

**Fails:** "gracefully" is not observable and "large" has no value.

**Sharpened, as a question for the reporter:** At what shipment count do we
paginate — the code loads all of them today and the largest account has 14,200?
And is the target "renders under 2s" or "renders the first page under 2s"?
</example>

<example>
**As written:** "Cancelled loads should be excluded from the report."

**Fails:** `Load` has `cancelled`, `voided`, and `pending_cancellation`.

**Sharpened:** Given a load in `pending_cancellation`, when the report runs,
is it included? Same question for `voided`.
</example>

A ticket where every AC passes this test is *usually* fine even if the
description is thin. A ticket with a beautiful description and three
untestable ACs is not ready.

### 5. Verdict

Sort every gap into two buckets — this is the part that makes the output
actionable:

- **We can decide** — an engineer can pick a reasonable answer and record it.
  Implementation details, naming, which existing pattern to follow.
- **Only the reporter can decide** — product intent, business rules, priority
  of a tradeoff, anything where guessing wrong means rework rather than a
  code-review comment.

The test: if existing code gives a precedent you would recommend, and a wrong
guess is a small change later, the gap is "we can decide". Record the default;
do not ask. The exception: when the code offers two defensible answers that
users would see differently (the point-in-time probe is the common case), ask
the reporter even if you have a recommendation.

Then:

| Verdict | When | Next step |
|---|---|---|
| **Ready** | No gaps that would change what gets built | Start. |
| **Ready with assumptions** | Only "we can decide" gaps that change what gets built | Stop here. List the "we can decide" gaps as numbered open decisions, each with your recommended answer, and settle them with the user in this session (`/grill-with-docs` does this well if it is installed). After they are settled, draft the resolved assumptions as a Jira comment (below) for the user to post **before** starting. Written-down assumptions are cheap to correct; unwritten ones become arguments in code review. |
| **Not ready** | Any "only the reporter can decide" gap | Draft the comment (below) and stop. Do **not** start. Pull the next ticket instead. |

Be willing to return **Not ready**. A gate that always says ready is not a gate.
Equally, don't manufacture blockers to look thorough — one real question beats
eight speculative ones, and a wall of generic questions is how teams learn to
ignore this.

### 6. Draft the comment

Draft this for the ticket:

```markdown
_Readiness check — automated, grounded in the current codebase._

**Verdict:** Not ready — 2 open product questions

**Resolved / assumed (we'll proceed this way unless told otherwise):**
- <assumption> — <the code reason it's the sensible default>

**Needs an answer from <reporter's name>:**
1. <specific question, citing the code that raises it>
2. <specific question, citing the code that raises it>

**Sharpened acceptance criteria:**
- [ ] Given …, when …, then …
```

Print it in a fenced block for the user to post. A plain-text `@name` does not notify anyone in Jira,
so tell the user to @-mention the reporter in the Jira editor when they post.

## Bulk mode

For "groom the sprint" / "check these ten tickets":

1. Resolve the list from the keys given, or run the JQL with your Jira tool
   (jira-cli: `jira issue list -q '<jql>' --plain`).
2. Check each one independently (parallel `Explore` agents are fine; the
   codebase reads don't conflict).
3. Render one table — key, title, verdict, gap count, the single biggest gap.
4. Draft comments only for the not-ready ones.

Lead with the not-ready ones. That list is the actual output of grooming.

## Feedback loop

When implementation uncovers a gap this check missed, that's the signal worth
acting on. Tell the user to open a PR on `RoadRunnerEngineering/rr-skills`
that adds a probe row for it, and to cite the ticket that exposed the miss in
the PR description. The probe table should grow from real misses, not from
imagination — a table of hypothetical probes is noise.
