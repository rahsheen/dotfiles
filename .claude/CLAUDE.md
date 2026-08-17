@RTK.md

# Environment

Terminal is Ghostty running inside tmux, with OSC 8 hyperlinks working. Use compact
masked links — `[coyote#123](url)` — rather than bare literal URLs; they render clickable.

# Guardrails

**Never rename a git branch that is the head of an open PR.** On RoadRunnerEngineering
repos the REST rename endpoint closes the PR instead of retargeting it. Recovery is
possible (recreate the old ref at the new tip, then reopen) — see the
`github-branch-rename-closes-prs` memory.
