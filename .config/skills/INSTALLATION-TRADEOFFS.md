# Skill installation tradeoffs

Checked on 2026-11-23. **Checked** means inspected source or command output. **Inferred** means a consequence of that evidence. This compares Matt at `abeeaf95660ba9e8b7c753eb38f441ca707a8823` and Palkan at `8fb4b26b674dc01612d582f0328bc6cf9bb0ce85`.

## Decision

**Inferred:** Use portable Matt skills for Claude and Codex when reproducible installation and portability matter more than automatic plugin updates. Use Matt's manifest as the allowlist. Keep the complete skill directories.

**Checked:** Palkan explicitly recommends its native Claude plugin for commands and sub-agents. It recommends the skill-only route for Codex. Keep that split. The portable tree still contains the workflows behind those commands. [Palkan installation guide](https://github.com/palkan/layered-rails-skills/blob/8fb4b26b674dc01612d582f0328bc6cf9bb0ce85/README.md)

**Inferred:** A binary-generated Herdr skill should match the binary's version. Capability detection is required: the installed `herdr --skill` command returned `unknown option: --skill` during this check. Its successful generation is not verified here.

## What each route preserves

| Item | Native plugin | Portable skill directories |
|---|---|---|
| Skill instructions and bundled references | Preserved | Preserved when the whole directory is installed |
| Plugin commands and registered sub-agents | Loaded by the harness | Not registered merely by copying skills |
| Plugin hooks and MCP servers | Loaded when declared and supported | Require separate integration |
| Plugin namespace | Provided by the harness | Bare skill names share a namespace |
| Updates | Plugin manager owns them | Installer or reviewed pin changes own them |

**Checked:** Claude's plugin manifest supports commands, agents, hooks and MCP configuration. Its plugin name namespaces components. These capabilities belong to the plugin format. They are not supplied by a portable `SKILL.md` folder. [Claude manifest reference](https://code.claude.com/docs/en/plugins-reference)

**Checked:** Matt's pinned manifest lists 27 skills. Its repository has no standalone plugin commands, registered plugin agents, hooks or MCP configuration. The `agents/openai.yaml` files inside skills are Codex metadata, not sub-agent registrations. Therefore no existing command, sub-agent, hook or MCP integration is lost by exporting those 27 full directories. [Matt manifest](https://github.com/mattpocock/skills/blob/abeeaf95660ba9e8b7c753eb38f441ca707a8823/.claude-plugin/plugin.json), [pinned repository tree](https://github.com/mattpocock/skills/tree/abeeaf95660ba9e8b7c753eb38f441ca707a8823)

**Checked:** Palkan has eight command files and two registered agents, `layered-rails-planner` and `layered-rails-reviewer`. It has no plugin hooks or MCP configuration at this pin. Portable installation loses those bindings and registrations. It retains the eight workflows. [Palkan plugin tree](https://github.com/palkan/layered-rails-skills/tree/8fb4b26b674dc01612d582f0328bc6cf9bb0ce85/layered-rails)

## Metadata, paths and names

**Checked:** Matt includes Codex `agents/openai.yaml` metadata. For example, `grill-with-docs` sets `allow_implicit_invocation: false`; its `SKILL.md` separately sets Claude's `disable-model-invocation: true`. Preserve both files unchanged. [Codex metadata](https://github.com/mattpocock/skills/blob/abeeaf95660ba9e8b7c753eb38f441ca707a8823/skills/engineering/grill-with-docs/agents/openai.yaml), [skill frontmatter](https://github.com/mattpocock/skills/blob/abeeaf95660ba9e8b7c753eb38f441ca707a8823/skills/engineering/grill-with-docs/SKILL.md)

**Checked:** The generic CLI copies skill directories recursively for Claude and Codex. Its canonical directory uses the skill name, not a plugin prefix. **Inferred:** Retaining whole directories preserves bundled metadata and internal relative links. Name collisions need explicit handling. Copying only `SKILL.md` is insufficient. [CLI installer source](https://github.com/vercel-labs/skills/blob/main/src/installer.ts)

**Checked:** Palkan's command wrappers link to `../skills/layered-rails/workflows/...`. The workflows themselves live inside the portable skill tree. **Inferred:** Keep native command wrappers in their plugin layout. A future command export must rewrite or preserve their paths. [Review wrapper](https://github.com/palkan/layered-rails-skills/blob/8fb4b26b674dc01612d582f0328bc6cf9bb0ce85/layered-rails/commands/review.md)

## Discovery and updates

**Checked:** Generic CLI discovery searches skill containers as well as manifest paths. Its skip list does not exclude `deprecated` or `in-progress`. **Inferred:** It can discover deprecated skills if those folders contain valid skill files. A manifest is not an exclusive allowlist for that CLI. [Discovery source](https://github.com/vercel-labs/skills/blob/main/src/skills.ts)

**Checked:** Matt has 39 `SKILL.md` files at this pin. Twelve are outside the 27-entry manifest: eight in `in-progress`, four in `misc`. `skills/deprecated` contains only a README at this pin. A claim that deprecated skills currently install would be incorrect. **Inferred:** Select the 27 manifest entries explicitly rather than accepting every discovered skill. [Pinned tree](https://github.com/mattpocock/skills/tree/abeeaf95660ba9e8b7c753eb38f441ca707a8823/skills)

**Checked:** Matt documents native plugin updates and manual generic updates. It warns that installing both routes for one agent duplicates skills. **Inferred:** Disable the old Matt plugin when switching that harness to portable installation. Keep reviewed commit SHAs as the installer's source of truth. [Matt installation guide](https://github.com/mattpocock/skills/blob/abeeaf95660ba9e8b7c753eb38f441ca707a8823/README.md)

**Checked:** The current generic CLI also has `check` and `update`. Its project lock records commits, and restore fetches the recorded commit. **Inferred:** Generic installation can be pinned; it is not inherently a latest-version install. A custom pinned exporter and the generic CLI have separate ownership records. Choose one owner per destination. [CLI README](https://github.com/vercel-labs/skills#lock-file-content-hash)

## Verification limits

Both requested source revisions were inspected. Matt's local Codex cache reports the exact requested revision; its pinned manifest and GitHub tree were also checked. Palkan was inspected with `git show` and `git ls-tree` at its requested revision. The generic CLI sources and Claude documentation above are current, unpinned web references. No model session was used to test skill behavior. Organization policy enforcement remains unverified.


## Implementation validation

**Checked:** Eleven integration tests pass. They use local Git sources and isolated home directories.
They cover selected skills, metadata retention, repeat restores, migration, corruption, failed installers, binary fallback, and update proposals.
The restricted test runs the real `skillsync` script.
Command: `python3 -m unittest discover -s .config/skills/tests -v`.

**Checked:** A separate smoke test used the real skills CLI `1.5.18`, Codex CLI, and Claude CLI.
It installed the 27 selected Matt skills for both agents and Layered Rails for Codex.
It installed the complete Layered Rails `3.1.0` Claude plugin.
Sources came from local Git caches at the declared pins. Package and source downloads were not tested.
Installed files matched the pinned sources, including bundled Codex metadata.

**Checked:** Real restoration and `--check` succeeded on a second run in the isolated home.
Switching to restricted mode preserved all Layered Rails commands and agents through `skillsync`.
Switching back restored the native plugin and removed the duplicate standalone skill.
The smoke test used an isolated home under `/private/tmp/dotfiles-skills-real-smoke`.

**Checked:** Claude's installer enables new plugins automatically.
An unconditional second enable command fails. The adapter now checks before enabling.
