@RTK.md

# Writing

Write all prose in ASD-STE100 Simplified Technical English (20/25-word sentence limits).
This includes chat, PR bodies, Jira comments, and commit messages.

- Put the main point first.
- State a fact one time. Do not restate it in a summary.
- Do not use filler, hedges, or scene-setting.
- For options or a design analysis, start with the seams and the real decisions. Put the
  evidence after the recommendation.
- Resolve decisions in prose. Do not use the multiple-choice question tool.
- PR body: fill in `.github/PULL_REQUEST_TEMPLATE.md`. The description tells what changed and
  where, plus what a reviewer cannot get from the diff. Do not add rationale sections or tell
  how you found the problem.
- PR notes and Jira comments: one short paragraph per finding, with a label
  (`Before flag-on:`, `Minor:`).
- Put a caveat in one place (PR or ticket). Refer to it from the other place.

Do not apply these rules to code, quoted text, or fixed templates.

# Working style

Act on reasonable defaults. Ask only before an irreversible step or when the request is
truly ambiguous.

# Code

- Comment only a non-obvious "why". Do not comment on removed code. When told to cut
  comments, delete them. Do not reword them.

# Tools

- A `+N more` marker means rtk summarized the output. Use `rtk proxy` for that one command
  only. Prefer the Grep and Read tools to shell `grep` and `cat`.
- Third-party skills install with `skillsync` from clones in `~/Development/agent-skills/`
  (runbook: its `README.md`).

# Work context

Work rules (Coyote, Jira, `rr`, Confluence) live in `~/roadrunner/CLAUDE.md`, in the private repo
`rahsheen/roadrunner-context`. `rr dev` checks it out at `~/workspace/` on Coder boxes.

# Dotfiles

- Dotfiles are a public bare repo: git dir `~/.cfg`, work tree `$HOME`. New files need an
  explicit `git add`. Do not commit secrets.
- `~/Library/Application Support/coderv2/dotfiles` is a decoy clone. Do not edit it.
- Put work-only provisioning in `rr dev` (`~/roadrunner/rr-tui`), not in `install.sh` conditionals.

# Environment

Terminal is Ghostty running inside tmux, with OSC 8 hyperlinks working. Use compact
masked links — `[coyote#123](url)` — rather than bare literal URLs; they render clickable.

# Guardrails

**Do not rename or delete the remote head branch of an open PR.** GitHub closes the PR.
To recover, recreate the old branch at the new tip, then run `gh pr reopen <n>`.
