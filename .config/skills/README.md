# Skills installation

`install.sh` copies this configuration and the installer into your home directory.
It then runs `skills-install`. Installation failures make both commands exit nonzero.

```sh
skills-install --dry-run  # show sources, exact pins, targets, and methods
skills-install           # restore, migrate previous installations, then verify
skills-install --check   # check sources and installed files; do not install
skills-update mattpocock-skills --ref main
skills-update palkan-skills --ref v3.1.0
```

## Sources and ownership

`sources.json` is the source of truth. It declares exact commit pins and selected skill paths.
Each source declares its installation method for Codex and Claude.
An agent absent from `PATH` is skipped.

| Source | Codex | Claude |
|---|---|---|
| Matt Pocock | Generic skill directories | Generic skill directories |
| Layered Rails | Generic skill directory | Full native plugin |
| Herdr | Binary-provided skill, or pinned fallback | Same |

The implementation is `~/.local/bin/skills-manager.py`.
It uses Python 3.9 or later, Git, and the declared installer tools.
The shell wrappers prefer `/usr/bin/python3` to avoid an unconfigured asdf shim.
Generic installation needs Node.js and npx. The skills CLI version is pinned in the manifest.
Native installation needs the Claude CLI. Restricted installation also needs `skillsync`, jq, and Perl.

Personal skills belong here. Work-specific skills remain owned by the work context repository.
Project-specific skills belong in their project repositories.
Do not add authentication, agent sessions, or unrelated runtime data to these dotfiles.

## Restoration

Git sources are fetched at their exact pin into:

```text
~/.local/share/agent-skill-sources/<source>/<commit>/
```

Existing clean snapshots are reused without fetching upstream.
A different pin gets another snapshot. Dirty snapshots cause an error.
The installer checks each declared skill path before installation.

Generic installation uses `npx skills@<version> add <local-snapshot>`.
It passes explicit skill names, the target agent, global scope, and copy mode.
Copies preserve complete skill directories, including references, scripts, and Codex metadata.
Codex receives `~/.agents/skills/<name>`; Claude receives `~/.claude/skills/<name>`.
Only the manifest-selected skills are installed. Broad discovery can include experimental skills.

Claude installs Layered Rails from the pinned snapshot as a local marketplace.
Its canonical plugin ID is `layered-rails@layered-rails-skills`.
The complete plugin retains its eight commands and two agent definitions.
The installer verifies the plugin payload, installation record, and enabled user setting.
It does not rely on Claude eventually installing a settings declaration.

Herdr uses `herdr --skill` when supported. Older binaries use the declared fallback URL.
Writes are atomic. Failed downloads leave the previous skill file intact.
A version and content record avoids downloading an unchanged fallback on every restore.

## Migration and repair

After replacement content passes verification, the installer disables the old Claude plugin IDs.
It removes the old Matt Codex plugin through Codex's CLI.
Other plugins and settings are preserved.
The dotfiles settings no longer declare these third-party plugins independently.
Claude writes local marketplace paths into runtime settings. Keep those machine-specific paths out of commits.

Standalone Layered Rails copies are removed from Claude after its native plugin passes verification.
Previous skill folders, symlinks, settings, and repaired plugin caches are backed up under:

```text
~/.local/state/agent-skills/backups/
```

A matching legacy symlink is also replaced with a pinned copy.
Modified copies are backed up before restoration. Custom skills with other names are untouched.
Declared names are installer-owned; keep personal variants under different names.
Disabled or removed sources are skipped, not automatically deleted.
Remove their old runtime files deliberately when retiring a source.
Do not run another global skill updater against these managed names.

## Verification

`--check` does not fetch pinned sources, install packages, or perform migrations.
It requires the pinned snapshots from restoration.
It compares every delivered skill file with its pinned source.
It detects missing references, broken links, changed files, and lost Codex metadata.
It checks complete native plugin payloads and enabled user settings.
It reports enabled legacy plugin duplicates.
Codex's plugin-list command may contact its catalog and maintain its own CLI caches.
It does not test model behavior or inspect project-level overrides.

Failures are reported per source and agent. Other targets still run.
Any failed installation or verification gives a nonzero exit status.

## Deliberate updates

`skills-update SOURCE --ref REF` resolves a branch or tag to an exact commit.
It prints the current pin, proposed pin, and upstream comparison link.
It does not change the manifest or installed skills.

Review the upstream diff. Then edit `pin` in `sources.json`.
For native plugins, also update the declared plugin version.
Review the selected skill paths when the plugin's skill list changes.
Run `skills-install`, then `skills-install --check`.
Commit the reviewed manifest change when ready.

## Restricted Claude

Claude is restricted when `$CODER` is set or managed settings contain `strictKnownMarketplaces`.
Generic Matt skills use the same installation method on every machine.
Layered Rails uses `skillsync` only on restricted machines.
The fallback exports skills, commands, and agents from its pinned clone.
The installer verifies skill files and rewritten command and agent content.
It disables the corresponding user plugin IDs to avoid duplicate installations.
Existing `skillsync` ownership rules still apply; an unowned conflict causes verification to fail.

The fallback reads a temporary manifest containing only the native source.
Its clones live under `<source-root>/restricted/`.
`~/.claude/.skillsync.json` remains its ownership record.
It does not install plugin hooks or MCP servers. Layered Rails has neither at the current pin.

## Evidence and tests

See [installation tradeoffs](INSTALLATION-TRADEOFFS.md) for the source comparison.

```sh
python3 -m unittest discover -s .config/skills/tests -v
```

The tests use real Git sources and isolated homes.
Agent and package CLI fixtures exercise restoration, migration, failures, and verification.
They also run the real restricted `skillsync` adapter.
