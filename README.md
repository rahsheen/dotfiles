## Generate an SSH key
https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent

## Add your new SSH key

https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account

## Configure your system and clone this repo 

https://www.atlassian.com/git/tutorials/dotfiles

This README is based on the popular "Bare Git Repository" method described in the Atlassian tutorial. You can copy the content below into a `README.md` file in your repository.

---

# Dotfiles

This repository uses the "Bare Git Repository" method to manage dotfiles without extra tooling or symlinks. It allows you to track files directly in your `$HOME` directory while keeping the Git metadata in a separate side-folder.

## Quick Setup (New Machine)

To install these dotfiles onto a new system, run the following commands:

```bash
# 1. Clone the repo as a bare repository into a hidden folder
git clone --bare <YOUR-GIT-REPO-URL> $HOME/.cfg

# 2. Define a temporary alias for the current session
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'

# 3. Attempt to checkout the files
config checkout

# 4. If step 3 fails with errors like "The following untracked working tree files would be overwritten", 
# it means you have existing config files. Back them up and try again:
mkdir -p .config-backup && \
config checkout 2>&1 | egrep "\s+\." | awk {'print $1'} | \
xargs -I{} mv {} .config-backup/{}

# 5. Checkout again after moving conflicting files
config checkout

# 6. Hide untracked files so 'config status' only shows files you care about
config config --local status.showUntrackedFiles no

# 6.5 Explicitly set the core.worktree configuration variable in the bare repository's config file to help
# tools like vim-fugitive 
/usr/bin/git --git-dir=$HOME/.cfg config --local core.worktree $HOME

# 7. Add the alias to your .bashrc or .zshrc for future use
echo "alias config='/usr/bin/git --git-dir=\$HOME/.cfg/ --work-tree=\$HOME'" >> $HOME/.bashrc

```

## How to Use

Instead of using the standard `git` command, use the `config` alias to manage your dotfiles.

### Check status

```bash
config status

```

### Add a new file

```bash
config add .vimrc
config commit -m "Add vimrc"

```

### Push changes

```bash
config push

```

### Pull updates

```bash
config pull

```

## Starting from Scratch (Initialization)

If you are creating a new dotfiles repo from scratch:

1. Create the bare repo: `git init --bare $HOME/.cfg`
2. Set the alias: `alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'`
3. Ignore untracked files: `config config --local status.showUntrackedFiles no`
4. Add the alias to your `.bashrc` or `.zshrc`.

## Credits

This workflow was popularized by [Nicola Paolucci via Atlassian](https://www.atlassian.com/git/tutorials/dotfiles) and originally shared by Hacker News user `StreakyCobra`.
