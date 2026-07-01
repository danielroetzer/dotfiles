# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/). There is no build, test, or lint step — changes are validated by symlinking a package and launching the relevant application.

## Stow commands

```sh
stow <package> -t ~      # symlink a package into $HOME
stow -D <package> -t ~   # remove a package's symlinks
stow -R <package> -t ~   # restow (unlink + relink) after adding/removing files
```

## Repository layout (the key convention)

Each top-level directory is a **Stow package** whose internal path mirrors exactly where its files land under `~`. Stow symlinks the package contents into `$HOME`, so the tree inside a package *is* the target tree:

- `git/.gitconfig` → `~/.gitconfig`
- `git/.config/git/*` → `~/.config/git/*`
- `nvim/.config/nvim/` → `~/.config/nvim/`
- `zed/.config/zed/` → `~/.config/zed/`
- `wezterm/.wezterm.lua` → `~/.wezterm.lua`
- `ssh/.ssh/config` → `~/.ssh/config`

When adding a new config file to a package, place it at the path relative to `$HOME` that the target application expects, then restow the package.

## Git identity switching

`git/.gitconfig` uses `includeIf "gitdir:..."` to select the committer identity by working-directory location — no manual per-repo `user.email`:

- Repos under `~/Documents/Personal/` → `~/.config/git/.gitconfig-personal`
- Repos under `~/Documents/Work/` → `~/.config/git/.gitconfig-work`

Each identity file only overrides `[user]`; everything else (aliases, defaults, credential helpers via `gh`) lives in the shared `.gitconfig`. Note `rebase = false` on `pull` and the git-core-recommended defaults block.
