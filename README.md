# dotfiles

- Link folders - `stow folder_name -t ~`
- Unlink folders - `stow -D folder_name -t ~`

## claude

Only selected files from `~/.claude` (settings, global `CLAUDE.md`), not the whole folder, which
holds credentials, history and transcripts. Move existing files aside before the first stow.
To back up another file, move it into `claude/.claude/` and run `stow -R claude -t ~`.

## agent-hub

Tracks Claude agents across zellij sessions (see `.ai/agent-navigator/README.md`). Needs
`stow agent-hub claude zellij -t ~`, plus `jq`, `fzf` and `libnotify-bin`.

- `Alt a` - agent picker, `Alt u` - jump to the agent waiting longest
- `zellij --layout agent-hub attach --create <name>` - session with the agent status bar
