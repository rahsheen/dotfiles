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
| Work | context repo (step 2, not built) | work machines | `claude/skills/*`, rr-skills plugins |
| Orchestration | rr-tui (`rr dev`) | Coder boxes | nothing after step 3; it runs `install.sh`, then the context script |

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

## Next steps

1. Context repo: a work manifest with rr-skills, and `claude/install-skills`. Cut
   `claude/skillsync/sources.json` to work-only repos. It shares skillsync's record
   (`~/.claude/.skillsync.json`) with this file, so a run with a smaller list prunes the
   personal skills. Give it its own record, or delete the rr dev skillsync step first.
2. rr-tui: replace `INSTALL_PLUGINS`, `LINK_SKILLS`, and `THIRD_PARTY_SKILLS` with one
   call to the context script.
3. Move the rr-skills entries out of `~/.claude/settings.json` and remove
   `~/.config/claude/work-settings.json`.
