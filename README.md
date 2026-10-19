# dotfiles

- Link folders - `stow folder_name -t ~`
- Unlink folders - `stow -D folder_name -t ~`

## claude

Only selected files from `~/.claude` (settings, global `CLAUDE.md`), not the whole folder, which
holds credentials, history and transcripts. Move existing files aside before the first stow.
To back up another file, move it into `claude/.claude/` and run `stow -R claude -t ~`.
