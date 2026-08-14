#!/usr/bin/env bash
#
# PreToolUse(Bash) hook wrapper for rtk (Rust Token Killer).
#
# rtk is homebrew-core only, so it is absent on Linux/Coder workspaces. This
# tracked settings.json ships the hook to every machine, so the wrapper has to
# no-op cleanly where rtk isn't installed — otherwise the hook fails on every
# single Bash call and the machine is effectively unusable.
#
# Exit 0 with no output = "hook has nothing to say, proceed normally".

command -v rtk >/dev/null 2>&1 || exit 0
exec rtk hook claude
