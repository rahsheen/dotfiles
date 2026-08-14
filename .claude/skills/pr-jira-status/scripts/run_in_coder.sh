#!/usr/bin/env bash
# Run a command inside a Coder QA workspace's checked-out repo.
#
# Handles the two things that trip up ad-hoc `coder ssh` here:
#  1. The app's Ruby toolchain (asdf) is only on the PATH under an INTERACTIVE
#     shell, so commands must run through `zsh -ic` — otherwise `bundle` /
#     `rake` / `rails` are "command not found".
#  2. Quoting. Everything after `coder ssh <ws> --` that is passed as multiple
#     args gets re-joined and re-split by the remote shell, which destroys the
#     grouping of `zsh -ic '<script>'`. So we build ONE argument and pass it as
#     one string. The inner command is grouped with single quotes, so it may
#     contain double quotes (e.g. `rails runner "Flipper.add(:x)"`) but must NOT
#     contain single quotes.
#
# Usage: run_in_coder.sh <workspace> <repo> <command...>
#   run_in_coder.sh PT-1412-qa-review coyote bundle exec rake pt_1412_backfill
#   run_in_coder.sh PT-1548-qa-review coyote 'bundle exec rails runner "Flipper.add(:clone_bill)"'
set -euo pipefail

ws="${1:?usage: run_in_coder.sh <workspace> <repo> <command...>}"
repo="${2:?usage: run_in_coder.sh <workspace> <repo> <command...>}"
shift 2
inner="$*"

# Repo root inside the workspace. $HOME stays literal so it expands remotely.
root="${QA_WORKSPACE_ROOT:-\$HOME/workspace}"
dir="$root/$(basename "$repo")"

if [[ "$inner" == *"'"* ]]; then
  echo "run_in_coder.sh: command must not contain single quotes: $inner" >&2
  exit 2
fi

echo "▶ [$ws:$(basename "$repo")] $inner" >&2
coder ssh "$ws" -- "zsh -ic 'cd $dir && $inner'"
