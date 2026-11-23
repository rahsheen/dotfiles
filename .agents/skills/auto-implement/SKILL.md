---
name: auto-implement
description: Implement an agreed ticket, spec, or conversation plan through TDD, automated checks, code review, and commits. Use when the user asks to carry agreed work through implementation.
---

Implement the agreed work using the installed `tdd` and `code-review` skills. This is a local adaptation of aihero.dev's `implement`; keep its dependencies unchanged.

## Establish the work

If the user passes a ticket reference, fetch it from the configured issue tracker and state its title before starting. Ask if the reference is ambiguous. Retain the original requirements, including a plan agreed in the conversation, for review.

Read applicable repository instructions, standards, and nearby code and tests. Follow existing conventions, domain terminology, and ADRs. Identify the repository's test, typecheck, and required check commands.

Record the starting HEAD as a fixed review baseline. Inspect existing staged, unstaged, and untracked changes; preserve unrelated work and keep it out of this task's commits and review scope.

## Implement with TDD

Load and apply the installed `tdd` skill (use the Skill tool when available; otherwise read its `SKILL.md` and referenced guidance directly).

**Local seam-selection exception:** In this workflow, the agent owns choosing test seams. Replace `tdd`'s requirement for user confirmation of seams with the following procedure; retain its other rules:

- Honor seams already specified by the user or agreed in the ticket, spec, or conversation.
- Otherwise choose public interfaces that expose the required behavior, preferring existing test conventions and stable interfaces. Consult `codebase-design` when the interface itself needs design.
- Before writing tests, briefly state the chosen seams and what each catches and misses, then proceed without waiting for seam approval. Ask only when unresolved requirements or a consequential interface decision need the user's input.

Work in vertical slices: one failing behavioral test, verify the failure, then the minimal passing implementation. Run relevant test files and available typechecking regularly. Keep refactoring for the review stage, as prescribed by `tdd`.

## Check, commit, and review

Run the full test suite and required repository checks before committing. Resolve failures caused by this work. If a required check cannot run or an existing failure prevents a clean result, report the blocker and do not claim completion.

Commit only this task's implementation to the current branch. Commit before review because the installed reviewer compares committed changes through HEAD.

Load and apply the installed `code-review` skill, supplying the recorded baseline, the original requirements, and the task's commit scope explicitly. Use the original ticket/spec or agreed conversation plan as the Spec source; a supplied file or conversation plan needs no issue-tracker setup. Retain the separate Standards and Spec reviews and their independent sub-agents when available. If delegation is unavailable, perform both reviews separately and disclose that limitation.

Fix significant findings: incorrect behavior, missing requirements, regressions, and material violations of repository standards. Use TDD for behavior fixes. Rerun affected checks and the full suite after fixes, commit the fixes, and repeat review against the original baseline until significant findings are resolved. Review the final committed state, including any changes made by commit hooks. Explain any finding dismissed with supporting evidence.

Report the completed work, check results, review outcome, and commit IDs. If completion is blocked, state what remains and why.
