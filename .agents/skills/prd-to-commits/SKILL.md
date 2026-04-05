---
name: prd-to-todo
description: Break a PRD into independently-grabbable Todo List items using tracer-bullet vertical slices. Append these to the plan.md file instead of creating Jira or GitHub issues.
---

# PRD to Todo List

Break a PRD into independently-grabbable Todo List items using vertical slices (tracer bullets).

## Process

### 1. Locate the PRD

Ask the user for the PRD.

If the PRD is not already in your context window, fetch it by reading the `plan.md` file directly.

### 2. Explore the codebase (optional)

If you have not already explored the codebase, do so to understand the current state of the code.

### 3. Draft vertical slices

Break the PRD into **tracer bullet** Todo List items. Each item is a thin vertical slice that cuts through ALL integration layers end-to-end, NOT a horizontal slice of one layer.

Slices may be 'HITL' or 'AFK'. HITL slices require human interaction, such as an architectural decision or a design review. AFK slices can be implemented and merged without human interaction. Prefer AFK over HITL where possible.

<vertical-slice-rules>
- Each slice delivers a narrow but COMPLETE path through every layer (schema, API, UI, tests)
- A completed slice is demoable or verifiable on its own
- Prefer many thin slices over few thick ones
</vertical-slice-rules>

### 4. Quiz the user

Present the proposed breakdown as a numbered list. For each slice, show:

- **Title**: short descriptive name
- **Type**: HITL / AFK
- **Blocked by**: which other slices (if any) must complete first
- **User stories covered**: which user stories from the PRD this addresses

Ask the user:

- Does the granularity feel right? (too coarse / too fine)
- Are the dependency relationships correct?
- Should any slices be merged or split further?
- Are the correct slices marked as HITL and AFK?

Iterate until the user approves the breakdown.

### 5. Add to the plan.md file

For each approved slice, append it to the `plan.md` file as a Todo List item. Include the following details:

<Todo-item-template>
- **Title**: short descriptive name.
- **Type**: HITL or AFK.
- **Blocked by**: which other items (if any) must complete first.
- **User stories addressed**: references from the parent PRD.
- **Details**: concise end-to-end description of the slice covering schema, API, UI, and tests.
</Todo-item-template>

Ensure that each Todo List item is added in dependency order (blockers first).
