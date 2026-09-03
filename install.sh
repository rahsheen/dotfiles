#!/bin/bash

# Clone dotfiles as bare repo
#
# git clone --bare https://github.com/rahsheen/dotfiles.git $HOME/.cfg
# function config {
#    /usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME $@
# }
# mkdir -p .config-backup
# config checkout
# if [ $? = 0 ]; then
#   echo "Checked out config.";
#   else
#     echo "Backing up pre-existing dot files.";
#     config checkout 2>&1 | egrep "\s+\." | awk {'print $1'} | xargs -I{} mv {} .config-backup/{}
# fi;
# config checkout
# config config status.showUntrackedFiles no

cp -a .config/* $HOME/.config
mkdir -p $HOME/.local/bin
cp -a .local/bin/* $HOME/.local/bin
cp .tmux* $HOME
cp .zshrc $HOME
cp .tool-versions $HOME

# Claude Code user config: CLAUDE.md, RTK.md, settings.json, the rtk PreToolUse
# hook and the statusline script. Copied here, before skillsync and the herdr
# skill install below, so those layer on top instead of being overwritten.
mkdir -p $HOME/.claude
cp -a .claude/. $HOME/.claude/

# Env shim. Three jobs: put ~/.local/bin on PATH, pick up machine-local secrets
# that can't live in this public repo (push-secrets writes ~/.zshenv.local), and
# export the app secrets the Coder template drops in ~/.aws/.env.coder.
#
# It goes in .zshenv, not .zshrc, because zsh sources .zshenv for
# non-interactive shells too — and Claude Code's Bash tool is not an
# interactive shell, so anything only in .zshrc is invisible to it. That is why
# PATH is repeated here despite the .zshrc export above: without it, every tool
# in ~/.local/bin (jira, cme, rtk, claude, herdr) vanishes the moment an agent
# shells out.
#
# Appended behind a marker, never overwritten: on macOS ~/.zshenv already holds
# real secrets, and this script runs there too.
ZSHENV_MARKER="# >>> dotfiles env shim >>>"

if grep -qF "$ZSHENV_MARKER" "$HOME/.zshenv" 2>/dev/null; then
  echo "Env shim already present in ~/.zshenv."
else
  echo "Adding env shim to ~/.zshenv..."
  # Quoted heredoc: this is remote shell code, expand nothing at install time.
  cat >> "$HOME/.zshenv" <<'ZSHENV_SHIM'

# >>> dotfiles env shim >>>
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# asdf's shims as well. .zshrc already adds them, so an interactive shell finds
# ruby/node/nvim while an agent shelling out finds nothing — and settings.json
# allow-lists `bundle exec rspec` and `npx vitest`, which then just fail.
__asdf_shims="${ASDF_DATA_DIR:-$HOME/.asdf}/shims"
if [ -d "$__asdf_shims" ]; then
  case ":$PATH:" in
    *":$__asdf_shims:"*) ;;
    *) export PATH="$__asdf_shims:$PATH" ;;
  esac
fi
unset __asdf_shims

[ -r "$HOME/.zshenv.local" ] && . "$HOME/.zshenv.local"

# NOT `. ~/.aws/.env.coder`: the values are unquoted, and at least one
# (HELCIM_API_KEY) contains a literal '$', which sourcing would expand and
# silently corrupt. Assigning via `export "$line"` never rescans the value.
if [ -r "$HOME/.aws/.env.coder" ]; then
  while IFS= read -r __env_line; do
    case "$__env_line" in ''|'#'*) continue ;; esac
    export "$__env_line"
  done < "$HOME/.aws/.env.coder"
  unset __env_line
fi
# <<< dotfiles env shim <<<
ZSHENV_SHIM
fi

# Add local bin to path
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  echo "export PATH=\$PATH:$HOME/.local/bin" >> $HOME/.zshrc
  export PATH="$PATH:$HOME/.local/bin"
fi

add_git_alias() {
  local alias_name="$1"
  local git_command="$2"

  if git config --global --get "alias.$alias_name" > /dev/null; then
    echo "Git alias '$alias_name' already exists."
    return
  else
    echo "Adding git alias '$alias_name' for '$git_command'."
    git config --global "alias.$alias_name" "$git_command"
  fi
}

add_git_alias "co" "checkout"
add_git_alias "ff" "pull --ff-only"
add_git_alias "br" "branch"
add_git_alias "st" "status"
add_git_alias "lg" "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
git config --global rerere.enabled true

# Get the OS type
unameOut="$(uname -s)"

# Install stuff based on OS
case "${unameOut}" in
  Linux*)     
    sudo apt install -y tmux ripgrep fd-find openjdk-17-jre zsh

    if [[ -z `command -v asdf` ]]; then
      curl -LO https://github.com/asdf-vm/asdf/releases/download/v0.16.6/asdf-v0.16.6-linux-amd64.tar.gz
      tar xzf asdf-v0.16.6-linux-amd64.tar.gz -C $HOME/.local/bin
    fi;;
  Darwin*)   
    brew install tmux ripgrep fd openjdk@17 zsh

    if [[ -z `command -v asdf` ]]; then
      curl -LO https://github.com/asdf-vm/asdf/releases/download/v0.16.6/asdf-v0.16.6-darwin-arm64.tar.gz
      tar xzf asdf-v0.16.6-darwin-arm64.tar.gz -C $HOME/.local/bin
    fi;;
 esac

ZSH_PATH=$(command -v zsh)

# Check if Zsh is installed and if it is not already the default shell
if [[ -n "$ZSH_PATH" && "$SHELL" != "$ZSH_PATH" ]]; then
  echo "Zsh is installed but not your default shell. Running chsh..."
  # Use 'sudo' if the user needs it to change their shell, which is common
  # 'chsh -s /path/to/zsh $(whoami)' changes the shell for the current user
  if command -v sudo > /dev/null; then
    sudo chsh -s "$ZSH_PATH" "$(whoami)"
  else
    chsh -s "$ZSH_PATH"
  fi
  echo "Default shell has been set to Zsh. Please log out and log back in for changes to take effect."
else
  echo "Zsh is either not installed or is already the default shell."
fi

OHMYZSH_DIR="$HOME/.oh-my-zsh"

if [ -d "$OHMYZSH_DIR" ]; then
  echo "Oh My Zsh is already installed in $OHMYZSH_DIR."
else
  echo "Oh My Zsh is not installed. Running installation..."
  
  # Check if curl is installed, as it's required for the installer script
  if command -v curl > /dev/null; then
    # Install Oh My Zsh (unattended mode to prevent chsh prompt)
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
    
    if [ $? -eq 0 ]; then
      echo "Oh My Zsh installed successfully."
    else
      echo "ERROR: Oh My Zsh installation failed."
    fi
  else
    echo "ERROR: 'curl' command is not found. Cannot download Oh My Zsh installer."
    # You could add a 'wget' fallback here if needed, or prompt the user to install curl.
  fi
fi

# tmuxinator. `gem` lives in asdf's shims, which are not on PATH in the
# non-interactive shell that runs this script, so the old bare `gem install`
# just printed "gem: command not found" and left .config/tmuxinator unusable.
if [[ -z `command -v tmuxinator` ]]; then
  GEM_BIN="$(command -v gem || true)"
  [ -n "$GEM_BIN" ] || GEM_BIN="${ASDF_DATA_DIR:-$HOME/.asdf}/shims/gem"
  if [ -x "$GEM_BIN" ]; then
    "$GEM_BIN" install tmuxinator || echo "WARN: tmuxinator install failed."
  else
    echo "WARN: gem not found; skipping tmuxinator."
  fi
fi

# Install the jira CLI if missing. settings.json allow-lists `jira issue *`, and
# the pr-jira-status and ticket-readiness skills shell out to it, so an agent
# without this binary silently loses both. macOS has a tap; Linux takes the
# release tarball, which nests the binary under <name>/bin/jira.
#
# Auth is NOT set up here: JIRA_API_TOKEN and ~/.config/.jira/.config.yml carry
# real credentials and this repo is public. `push-secrets` delivers them.
if [[ -z `command -v jira` ]]; then
  case "${unameOut}" in
    Darwin*)
      echo "jira CLI is not installed. Installing via brew..."
      brew install ankitpokhrel/jira-cli/jira-cli;;
    Linux*)
      echo "jira CLI is not installed. Installing from GitHub releases..."
      JIRA_CLI_VERSION="1.7.0"
      case "$(uname -m)" in
        x86_64|amd64) JIRA_CLI_ARCH="x86_64";;
        aarch64|arm64) JIRA_CLI_ARCH="arm64";;
        *) JIRA_CLI_ARCH="";;
      esac
      if [ -z "$JIRA_CLI_ARCH" ]; then
        echo "ERROR: no jira-cli build for $(uname -m). Skipping."
      else
        JIRA_TMP="$(mktemp -d)"
        if curl -fsSL -o "$JIRA_TMP/jira.tar.gz" \
             "https://github.com/ankitpokhrel/jira-cli/releases/download/v${JIRA_CLI_VERSION}/jira_${JIRA_CLI_VERSION}_linux_${JIRA_CLI_ARCH}.tar.gz" \
           && tar -xzf "$JIRA_TMP/jira.tar.gz" -C "$JIRA_TMP"; then
          JIRA_BIN="$(find "$JIRA_TMP" -type f -name jira -perm -u+x | head -1)"
          if [ -n "$JIRA_BIN" ]; then
            install -m 0755 "$JIRA_BIN" "$HOME/.local/bin/jira"
            echo "Installed jira CLI $(~/.local/bin/jira version 2>/dev/null | head -1)"
          else
            echo "ERROR: no jira binary inside the release tarball."
          fi
        else
          echo "ERROR: failed to download or extract jira-cli."
        fi
        rm -rf "$JIRA_TMP"
      fi;;
  esac
else
  echo "jira CLI is already installed."
fi

# Install confluence-markdown-exporter if missing. It needs Python >= 3.10;
# Ubuntu 22.04 ships 3.10 at /usr/bin/python3, which is called explicitly because
# the asdf `python3` shim has no version pinned in .tool-versions and errors out.
# No PEP-668 marker on 22.04, so a --user install lands cleanly in ~/.local/bin.
#
# Its Atlassian credentials come from CME_AUTH, which push-secrets sets.
if [[ -z `command -v cme` ]]; then
  case "${unameOut}" in
    Darwin*)
      echo "cme is not installed. Installing via pip..."
      python3 -m pip install --user --quiet --no-warn-script-location \
        confluence-markdown-exporter || echo "ERROR: cme install failed.";;
    Linux*)
      echo "cme is not installed. Installing via pip..."
      if [[ -z `command -v pip3` ]] && ! /usr/bin/python3 -m pip --version > /dev/null 2>&1; then
        sudo apt-get install -y -qq python3-pip
      fi
      /usr/bin/python3 -m pip install --user --quiet --no-warn-script-location \
        confluence-markdown-exporter || echo "ERROR: cme install failed.";;
  esac
else
  echo "cme is already installed."
fi

# Install asdf plugins
if [[ -z `command -v neovim` ]]; then
  asdf plugin add neovim
  asdf install neovim stable
fi

# Install FZF if missing
if [[ -z `command -v fzf` ]]; then
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
  ~/.fzf/install
fi

# Install zsh-vi-mode custom plugin if missing (.zshrc lists it in plugins=())
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.config/zsh/custom}"
if [ ! -f "$ZSH_CUSTOM/plugins/zsh-vi-mode/zsh-vi-mode.plugin.zsh" ]; then
  echo "zsh-vi-mode is not installed. Cloning..."
  mkdir -p "$ZSH_CUSTOM/plugins"
  rm -rf "$ZSH_CUSTOM/plugins/zsh-vi-mode"
  git clone --depth 1 https://github.com/jeffreytse/zsh-vi-mode.git \
    "$ZSH_CUSTOM/plugins/zsh-vi-mode"
else
  echo "zsh-vi-mode is already installed."
fi

# Install rtk if missing. macOS takes the homebrew-core bottle; Linux takes the
# vendor installer, which resolves the latest release, verifies the SHA-256 and
# handles the target split (x86_64 ships musl, aarch64 ships gnu). It lands in
# ~/.local/bin, already on PATH from above. The PreToolUse hook wrapper
# (~/.claude/hooks/rtk-hook.sh) no-ops where rtk is absent, so a failed install
# degrades to unfiltered output rather than breaking every Bash call.
if [[ -z `command -v rtk` ]]; then
  case "${unameOut}" in
    Darwin*)
      echo "rtk is not installed. Installing via brew..."
      brew install rtk;;
    Linux*)
      echo "rtk is not installed. Installing from GitHub releases..."
      curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/master/install.sh | sh;;
    *)
      echo "rtk is not installed and no install method is known for ${unameOut}. Skipping (hook will no-op).";;
  esac
else
  echo "rtk is already installed."
fi

# Clone the third-party agent-skill repos and install them as user-level skills.
# Their marketplaces are blocked by enterprise policy, so skillsync installs the
# contents directly. Source repos, refs and pins come from the tracked manifest.
SKILLSYNC_SOURCES="$HOME/.config/agent-skills/sources.json"

if [ -f "$SKILLSYNC_SOURCES" ]; then
  if [[ -z `command -v jq` ]]; then
    echo "ERROR: jq not found. Skipping agent skill sync."
  elif [[ -z `command -v perl` ]]; then
    echo "ERROR: perl not found. Skipping agent skill sync."
  else
    SKILLSYNC_ROOT="$(jq -r '.root // "~/Development/agent-skills"' "$SKILLSYNC_SOURCES")"
    SKILLSYNC_ROOT="${SKILLSYNC_ROOT/#\~/$HOME}"
    export SKILLSYNC_ROOT
    export SKILLSYNC_SKILLS_DIR="$HOME/.claude/skills"
    mkdir -p "$SKILLSYNC_ROOT" "$SKILLSYNC_SKILLS_DIR"

    # Per-repo filters (exclusions, `disabled`) live alongside the clones.
    cp -a "$HOME"/.config/agent-skills/filters/*.skillsync "$SKILLSYNC_ROOT/" 2>/dev/null || true

    while IFS=$'\t' read -r dir url ref pin; do
      [ -n "$dir" ] || continue
      target="$SKILLSYNC_ROOT/$dir"
      if [ ! -d "$target/.git" ]; then
        echo "Cloning $dir from $url"
        git clone --quiet "$url" "$target" || { echo "ERROR: clone failed: $url"; continue; }
      else
        echo "$dir is already cloned. Fetching..."
        git -C "$target" fetch --quiet --tags origin || true
      fi
      if [ "$pin" != "null" ]; then
        git -C "$target" checkout --quiet --detach "$pin" \
          || echo "WARN: $dir: pin $pin not found; left at $(git -C "$target" rev-parse --short HEAD)"
      else
        git -C "$target" checkout --quiet "$ref" 2>/dev/null \
          && git -C "$target" merge --quiet --ff-only "origin/$ref" 2>/dev/null || true
      fi
    done < <(jq -r '.repos[] | select(.enabled != false)
                    | [.dir, .url, (.ref // "main"), (.pin // "null")] | @tsv' "$SKILLSYNC_SOURCES")

    if [[ -n `command -v skillsync` ]]; then
      skillsync
    else
      echo "WARN: skillsync not on PATH; expected $HOME/.local/bin/skillsync"
    fi
  fi
fi

# Install Herdr (terminal workspace manager for coding agents). The curl
# installer picks the right release binary, so macOS and Linux are identical.
if [[ -z `command -v herdr` ]]; then
  if [[ -n `command -v curl` ]]; then
    echo "Herdr is not installed. Installing..."
    curl -fsSL https://herdr.dev/install.sh | sh
  else
    echo "ERROR: 'curl' not found. Cannot install Herdr."
  fi
else
  echo "Herdr is already installed."
fi

# Install the Herdr agent skill (teaches agents to drive herdr when HERDR_ENV=1).
# Prefer the copy bundled with the installed binary so skill and binary always
# match; fall back to a pinned upstream copy on builds older than 0.8.0.
HERDR_SKILL_REF="v0.8.0"
HERDR_SKILL_URL="https://raw.githubusercontent.com/herdrdev/herdr/${HERDR_SKILL_REF}/skills/herdr/SKILL.md"
HERDR_SKILL_DIR="$HOME/.claude/skills/herdr"

if [[ -n `command -v herdr` ]]; then
  mkdir -p "$HERDR_SKILL_DIR"
  if herdr --skill > "$HERDR_SKILL_DIR/SKILL.md.tmp" 2>/dev/null \
     && [ -s "$HERDR_SKILL_DIR/SKILL.md.tmp" ]; then
    mv "$HERDR_SKILL_DIR/SKILL.md.tmp" "$HERDR_SKILL_DIR/SKILL.md"
    echo "Installed Herdr agent skill (bundled with the installed binary)."
  else
    rm -f "$HERDR_SKILL_DIR/SKILL.md.tmp"
    echo "'herdr --skill' unavailable (needs 0.8.0+); fetching ${HERDR_SKILL_REF} from upstream..."
    if [[ -n `command -v curl` ]] && curl -fsSL "$HERDR_SKILL_URL" -o "$HERDR_SKILL_DIR/SKILL.md"; then
      echo "Installed Herdr agent skill (upstream ${HERDR_SKILL_REF})."
    else
      echo "ERROR: could not install the Herdr agent skill."
    fi
  fi
fi

# Work-only Claude Code config (internal plugin marketplace).
#
# These dotfiles run on personal machines too, where the internal marketplace is
# unreachable — Claude Code would error on every startup trying to fetch it. So
# the config is applied ONLY when this looks like a work environment, by merging
# ~/.config/claude/work-settings.json into ~/.claude/settings.local.json
# (untracked, and the file Claude Code reads).
is_work_env() {
  [ -n "${CODER_WORKSPACE_NAME:-}" ] && return 0            # inside a Coder workspace
  [ -d /workspaces ] && return 0                            # Coder workspace, alt marker
  case "$(hostname -s 2>/dev/null)" in RR-*) return 0 ;; esac  # corporate MacBook (MDM naming)
  git config --global user.email 2>/dev/null | grep -qi 'roadrunnerwm\.com' && return 0
  return 1
}

WORK_SETTINGS="$HOME/.config/claude/work-settings.json"
LOCAL_SETTINGS="$HOME/.claude/settings.local.json"

if is_work_env; then
  if [ ! -f "$WORK_SETTINGS" ]; then
    echo "WARN: work environment detected but $WORK_SETTINGS is missing."
  elif [[ -z `command -v jq` ]]; then
    echo "WARN: work environment detected but jq is unavailable; skipping plugin config."
  else
    echo "Work environment detected. Applying internal marketplace config..."
    mkdir -p "$HOME/.claude"
    [ -f "$LOCAL_SETTINGS" ] || echo '{}' > "$LOCAL_SETTINGS"
    # Deep-merge, work settings winning, then drop the comment key.
    if jq -s '.[0] * .[1] | del(._comment)' "$LOCAL_SETTINGS" "$WORK_SETTINGS" \
         > "$LOCAL_SETTINGS.tmp" 2>/dev/null; then
      mv "$LOCAL_SETTINGS.tmp" "$LOCAL_SETTINGS"
      echo "  -> merged into $LOCAL_SETTINGS"
    else
      rm -f "$LOCAL_SETTINGS.tmp"
      echo "ERROR: failed to merge work settings; leaving $LOCAL_SETTINGS untouched."
    fi
  fi
else
  echo "Personal machine: skipping internal marketplace config."
fi

# Install Claude Code if missing (native installer, lands in ~/.local/bin)
if [[ -z `command -v claude` ]]; then
  echo "Claude Code is not installed. Running installation..."

  if command -v curl > /dev/null; then
    curl -fsSL https://claude.ai/install.sh | bash

    if [ $? -eq 0 ]; then
      echo "Claude Code installed successfully."
    else
      echo "ERROR: Claude Code installation failed."
    fi
  else
    echo "ERROR: 'curl' command is not found. Cannot download Claude Code installer."
  fi
else
  echo "Claude Code is already installed ($(claude --version))."
fi
