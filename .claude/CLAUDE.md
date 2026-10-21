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
- Figma is the authority for colors, spacing, and type. Flag a visual value only when it is
  provably broken (a missing token, a class with no effect).

# Coyote

- Put new code in the `app/` directory for its layer. Use the `layered-rails` skill to
  find the layer.
- Do not add files to `app/classes/` or `app/modules/`. These directories are legacy and
  have no convention. Their files do not show where new code goes.
- Remove ActiveRecord callbacks that do more than data integrity. Move the work into a
  service, and delete the paths that write the record directly. Do not retime or defer a
  callback. Name services `Creator`, `Updater`, `Deleter`, or `Canceler`. They return the
  record and raise on failure. Standard: [Callback Hell](https://roadrunnerwm.atlassian.net/wiki/spaces/ROAD/pages/3655401474).
- Do not run the full rspec suite locally. Run the specs for the change and its dependents.
- `staging` is behind a merge queue. `gh pr merge` fails on a stacked PR. Ask the user to
  merge it in the GitHub UI.
- When Lyra fails against a local backend, first check that the coyote checkout on port 9000
  is current with origin.
- Coder startup runs migrations, which rewrites `db/structure.sql`. Ignore that diff when the
  change adds no migration. Do not commit, review, or explain it. Before a commit, restore it
  with `git checkout -- db/structure.sql`.

# Tools

- `rr` owns PR and ticket status, QA handoff, workspace provisioning, and reclaim. Use
  `rr status --json`. Do not rebuild that data from `gh` and `jira`.
- `jira issue move` matches the transition name, not the status. A PT Task goes to In Progress
  with `"Transition to "` (trailing space). For other targets, use `rr`.
- In JQL, use `statusCategory`, not `resolution`. Done tickets often have no resolution.
- jira-cli corrupts the first markdown heading. Start a description with a throwaway
  `### Context`. `--skip-notify` returns 403.
- Read Confluence with `confluence-markdown-exporter pages <url>` (`cme`), not WebFetch. For a
  personal-space URL (`~<accountid>`), replace the space segment with `x`.
- A `+N more` marker means rtk summarized the output. Use `rtk proxy` for that one command
  only. Prefer the Grep and Read tools to shell `grep` and `cat`.
- Third-party skills install with `skillsync` from clones in `~/Development/agent-skills/`
  (runbook: its `README.md`). rr-skills uses `claude plugin`. Do not edit other engineers'
  plugins in rr-skills.

# Dotfiles

- Dotfiles are a public bare repo: git dir `~/.cfg`, work tree `$HOME`. New files need an
  explicit `git add`. Do not commit secrets.
- `~/Library/Application Support/coderv2/dotfiles` is a decoy clone. Do not edit it.
- Put work-only provisioning in work scripts (`dev-coder`), not in `install.sh` conditionals.

# Environment

Terminal is Ghostty running inside tmux, with OSC 8 hyperlinks working. Use compact
masked links — `[coyote#123](url)` — rather than bare literal URLs; they render clickable.

On Coder boxes, repos are flat clones at `~/workspace/<repo>`, not worktrees.

# Guardrails

**Do not rename or delete the remote head branch of an open PR.** GitHub closes the PR.
To recover, recreate the old branch at the new tip, then run `gh pr reopen <n>`.
