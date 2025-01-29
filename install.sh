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

# Add local bin to path
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  echo "export PATH=\$PATH:$HOME/.local/bin" >> $HOME/.zshrc
  export PATH="$PATH:$HOME/.local/bin"
fi
# echo "export PATH=\$PATH:$HOME/.local/bin" >> $HOME/.zshrc
# export PATH=$PATH:$HOME/.local/bin

unameOut="$(uname -s)"

# Install stuff based on OS
if [[ -z `command -v nvim` ]]; then

  case "${unameOut}" in
    Linux*)     
      curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
      sudo rm -rf /opt/nvim
      sudo tar -C /opt -xzf nvim-linux64.tar.gz
      export PATH=$PATH:/opt/nvim-linux64/bin
      echo "export PATH=\$PATH:/opt/nvim-linux64/bin" >> $HOME/.zshrc;;
    Darwin*)   
      curl -LO https://github.com/neovim/neovim/releases/download/nightly/nvim-macos-arm64.tar.gz
      tar xzf nvim-macos-arm64.tar.gz
      cp nvim-macos-arm64/bin/nvim $HOME/.local/bin;;
   esac
fi

# Install tmux, ripgrep, and fd if not installed based on unameOut above
if [[ -z `command -v tmux` ]]; then
  case "${unameOut}" in
    Linux*)
      sudo apt update
      sudo apt install -y tmux ripgrep fd-find;;
    Darwin*)
      brew install tmux ripgrep fd;;
  esac
fi

# Install FZF if missing
if [[ -z `command -v fzf` ]]; then
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
  ~/.fzf/install

  source ~/.fzf.zsh
fi
