---
name: ticket-readiness
description: >-
  Check whether a Jira ticket is actually ready to implement before anyone
  starts it — by reading the ticket AND the code it touches, then reporting the
  specific gaps. Use at grooming, refinement, sprint planning, or the moment
  before picking up a ticket. Triggers on "is EP-1234 ready", "groom these
  tickets", "refine the sprint", "what's missing from this ticket", "are the
  acceptance criteria good", "is this well specified", "should I start this
  ticket", "review the backlog before planning", or any ask about whether work
  is defined well enough to begin. Also runs in bulk over a sprint or filter.
  Produces a Ready / Ready-with-assumptions / Not-ready verdict, a gap list
  split by who can answer each gap, and a Jira comment to post back.
---

# Ticket readiness

Decide whether a ticket is defined well enough to implement, and if not, say
exactly what is missing and who has to answer it.

**This runs before implementation, not during it.** The point is to move the
discovery of missing edge cases from "three hours into the branch" to "grooming,
where it costs a comment." Run it in bulk over sprint candidates a few days
before planning so the gaps go back to the PM asynchronously.

## Non-negotiable: ground every probe in the code

A readiness check that only reads the ticket produces generic questions
("what about error cases?") that everyone learns to skip. **Every gap you report
must cite something real** — a status enum value, a nullable column, a policy
rule, an existing caller, a spec file. If you cannot point at the code that
makes a question matter, delete the question.

This means step 2 below is the expensive step and you do not get to skip it.

## Process

### 1. Read the ticket

```bash
jira issue view <KEY> --plain --comments 20
```

Read the description, the acceptance criteria, the comments (decisions often
live only there), linked issues, and any attached design. Note what the ticket
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
| **Blast radius** | Existing callers of a modified method/endpoint/component. Does the ticket acknowledge them? |
| **Test invalidation** | Existing specs on the path. Will this change break them, or worse, silently make them assert nothing? For e2e specifically, hand off to `/e2e-playwright` — it does grooming-time blast radius. |
| **Rollout & reversibility** | Is this behind a flag? If it's wrong in production, what's the undo? Data migrations especially. |
| **Contradiction** | Does the ticket assert something the code disproves? ("currently users can't X" — but they can.) This is the highest-value find and it is only findable by reading the code. |

Not every probe applies to every ticket. A copy change needs three of these; a
schema change needs all ten. Don't pad.

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

Then:

| Verdict | When | Next step |
|---|---|---|
| **Ready** | No gaps, or only "we can decide" gaps that are truly trivial | Start. |
| **Ready with assumptions** | Only "we can decide" gaps | Run `/grilling` to settle them with the engineer picking up the work, then post the resolved assumptions as a Jira comment **before** starting. Written-down assumptions are cheap to correct; unwritten ones become arguments in code review. |
| **Not ready** | Any "only the reporter can decide" gap | Post the comment (below), move the ticket back, and do **not** start. Pull the next ticket instead. |

Be willing to return **Not ready**. A gate that always says ready is not a gate.
Equally, don't manufacture blockers to look thorough — one real question beats
eight speculative ones, and a wall of generic questions is how teams learn to
ignore this.

### 6. Post it back

Post to the ticket:

```markdown
_Readiness check — automated, grounded in the current codebase._

**Verdict:** Not ready — 2 open product questions

**Resolved / assumed (we'll proceed this way unless told otherwise):**
- <assumption> — <the code reason it's the sensible default>

**Needs an answer from @<reporter>:**
1. <specific question, citing the code that raises it>
2. <specific question, citing the code that raises it>

**Sharpened acceptance criteria:**
- [ ] Given …, when …, then …
```

Post with `jira issue comment add <KEY> --template -` from a heredoc so the
markdown survives. Confirm the comment text with the user before posting —
it's visible to the whole team.

## Bulk mode

For "groom the sprint" / "check these ten tickets":

1. Resolve the list — `jira issue list -q '<jql>' --plain` or the keys given.
2. Check each one independently (parallel `Explore` agents are fine; the
   codebase reads don't conflict).
3. Render one table — key, title, verdict, gap count, the single biggest gap.
4. Post comments only on the not-ready ones, and only after the user confirms.

Lead with the not-ready ones. That list is the actual output of grooming.

## Feedback loop

When implementation uncovers a gap this check missed, that's the signal worth
acting on: add a probe row for it here. The probe table should grow from real
misses, not from imagination — a table of hypothetical probes is noise, a table
of "this bit us in EP-4471" is a checklist with teeth.
