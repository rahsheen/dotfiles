# Skills install

`install.sh` runs `~/.local/bin/skills-install`. It installs my preferred skills for each
agent harness on PATH, on every machine. Each harness uses the method that the skill repo
recommends. skillsync runs only where policy blocks that method. rr-tui is not necessary.

```sh
skills-install --dry-run   # print each decision, change nothing
skills-install             # apply
```

## Layers

| Layer | Owner | Runs on | Installs |
|---|---|---|---|
| Personal | dotfiles: `skills-install` reads `sources.json` in this folder | every machine | mattpocock, layered-rails, herdr |
| Work | context repo: `claude/install-skills` (its `claude/README.md`) | work machines | `claude/skills/*`, rr-skills plugins |
| Orchestration | rr-tui (`rr dev`) | Coder boxes | nothing itself; Coder runs `install.sh`, and `rr dev` runs the context script |

## Methods

| Harness | Not restricted | Restricted |
|---|---|---|
| Claude | `~/.claude/settings.json` declares the plugins (`extraKnownMarketplaces`, `enabledPlugins`). Claude installs them. | `skillsync --sources sources.json` links the skills into `~/.claude/skills`. |
| Codex | The `codex` commands in `sources.json`, from each repo's README. | Codex has no policy here. |
| herdr skill | `herdr --skill`, written into `~/.claude/skills` and `~/.agents/skills` for each harness on PATH. | same |

A harness that is not on PATH is skipped. Codex does not run on work machines, so its
commands do nothing there. Test them on a personal machine.

Install exactly one method for each harness. Two methods give every skill twice
(`mattpocock/skills` `README.md:27`). On a restricted machine, the policy blocks the
`settings.json` plugins, so only the skillsync copy loads.

## Restricted check

One decision for the whole machine. Claude is restricted when either is true:

1. `$CODER` is set. The Coder agent sets it in every workspace (checked on `pt-1996`,
   2026-11-23).
2. `strictKnownMarketplaces` is in `~/.claude/remote-settings.json` or in a system
   `managed-settings.json`.

Claude writes `remote-settings.json` from the org's server-managed settings after login.
On a new Coder box it does not exist yet when `install.sh` runs, so check 1 covers that
case. Check 2 covers the work Mac. Hostnames are not used.

On the work Mac, `anthropics/claude-plugins-official` is blocked (checked:
`claude plugin marketplace add` returned "blocked by enterprise policy", 2026-11-23).

## Pins

The Claude plugins and skillsync use the same SHA: the `ref` in `settings.json` and the
`pin` in `sources.json`. Bump both after you read the upstream diff. The Codex commands
follow upstream, because their installers take no pin.

## rr-skills entries in settings.json

`settings.json` also declares the work rr-skills plugins. They stay there. If they moved
out, `claude plugin install` on the Mac would write them back into this tracked file at
each run. On a personal machine the private marketplace does not load, and nothing breaks.

## skillsync

`~/.local/bin/skillsync` is the restricted Claude fallback. Only this `sources.json` drives
it, so only one list ever owns its record, `~/.claude/.skillsync.json`.

```sh
skillsync --sources ~/.config/skills/sources.json --dry-run   # preview
skillsync --list                                              # what it owns
```

- It clones each enabled repo into `root` and checks out its `pin`. A repo with no pin
  follows the tip of `ref`, and the run prints a warning.
- It reads each repo's `.claude-plugin/marketplace.json` or `plugin.json`. It does not glob
  for `SKILL.md`, so `deprecated/` and `in-progress/` folders stay out.
- It links skills, so a checkout change is live at once. It copies commands and agents and
  changes plugin-relative links and `${CLAUDE_PLUGIN_ROOT}` to absolute paths.
- It changes only the paths in its own record and skips a file it did not make.
  `--adopt <name>` moves that file to `~/.claude/skills-local/` and installs over it.
- It does not install plugin `hooks/`. It prints a `settings.json` block to paste.
- Filters: `filters/<dir>.skillsync` in this folder. A `-glob` line excludes the paths
  that match. A line that is exactly `disabled` skips the repo.
- To remove a repo, delete its entry or set `"enabled": false`. The next run prunes it.

A skill must be `<name>/SKILL.md`, one level below the skills directory. A loose `.md`
file or a deeper folder does not register.
