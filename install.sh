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

# Copy dotfiles when initializing codespaces/coder environment
cp -a .config/* $HOME/.config
mkdir -p $HOME/.local/bin
cp -a .local/bin/* $HOME/.local/bin
cp .tmux* $HOME
cp .zshrc $HOME
cp .tool-versions $HOME

if [ -d "/workspaces" ]; then
  echo ". /workspaces/.env.secrets" >> /home/coder/.zshrc
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

if [[ -z `command -v tmuxinator` ]]; then
  gem install tmuxinator
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
