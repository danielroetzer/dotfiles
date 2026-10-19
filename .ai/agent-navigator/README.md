# Agent navigator for Zellij

**Status:** implemented 2026-10-19 (everything except `agent-new`). Interactive checks pending; see
"Risks and open items".
**Planned:** 2026-10-19. Host: Zellij 0.45.1, Claude Code 2.1.303, KDE.

Goal: a lightweight, LLM-free layer that tracks every Claude agent (one per worktree, one Zellij
session per worktree), notifies you when one needs you, and lets you jump to it.

---

## TL;DR

- Claude Code hooks call one script, `agent-event`, which overwrites one JSON file per session in
  `~/.local/state/agent-hub/` and sends a desktop notification when an agent needs input or finishes.
- `agent-nav` reads those files:
  - `--summary` feeds a zjstatus bar segment (`🔴2 🟢1 🟡3`).
  - `Alt a` opens an fzf picker.
  - `Alt u` jumps to the agent that has waited longest.
- Everything is versioned in this repo as Stow packages. Runtime state and `libnotify-bin` are the
  only things outside it.
- **Out of scope for now:** `agent-new` (the worktree and session launcher). For now you create
  worktrees yourself. Zed's terminal already creates a session named after the worktree directory
  (`attach --create "$(basename "$PWD")"`), and that name is the key everywhere.

---

## Verification of the original design (done 2026-10-19)

Tested against the real binaries; the cross-session tests used throwaway background sessions.

| Claim | Result |
|---|---|
| `zellij -s X action …` works on other sessions | ✅ `list-panes --json --all` and `dump-screen --pane-id` both work |
| `list-panes` JSON can detect dead panes and find tabs | ✅ has `exited`, `tab_id`, `tab_position`, `tab_name` |
| `switch-session` moves the client | ✅ works from the CLI |
| `switch-session --pane-id` brings the right tab forward | ❓ inconclusive; the headless test setup was unreliable. **Needs a manual check** |
| `switch-session` to a missing session | ⚠️ exit 0, nothing created, no error (one test, may not be reliable) |
| Hooks see `ZELLIJ_SESSION_NAME` and `ZELLIJ_PANE_ID` | ✅ processes Claude starts see them; the docs say hooks inherit Claude's environment |
| "Use existing zjstatus" | ❌ wasn't installed. ✅ now v0.25.0 at `zellij/.config/zellij/plugins/zjstatus.wasm` (sha256 matches the release); `file:~/…` resolves correctly |
| `Alt n` for jump-next | ❌ already bound to `NewPane`; use `Alt u` |
| `notify-send` | ✅ `libnotify-bin` installed |
| "Notification hook means needs input" | ❌ `idle_prompt` fires ~60s after every finished turn; must filter on `notification_type` |
| Notification `message` contains the question | ❌ generic text; the real text comes from other hooks (below) |

---

## Files (Stow packages)

| Package | File | Purpose |
|---|---|---|
| `agent-hub` (new) | `.local/bin/agent-event` | Hook target: writes state, sends notification |
| | `.local/bin/agent-nav` | Picker (default), `--next`, `--summary`, `--preview` (used by fzf) |
| `claude` (new) | `.claude/settings.json` | Current settings plus hook wiring |
| | `.claude/CLAUDE.md` | Global Claude preferences (moved in as-is) |
| `zellij` | `.config/zellij/config.kdl` | `Alt a` and `Alt u` keybinds |
| | `.config/zellij/layouts/agent-hub.kdl` (new) | Session layout with the zjstatus bar |
| | `.config/zellij/plugins/zjstatus.wasm` | zjstatus v0.25.0, committed (~4 MB) |
| `zed` | `.config/zed/keymap.json` | Pass `alt-a` and `alt-u` through to the terminal |

- **Runtime state:** `~/.local/state/agent-hub/<session>.json`. It stays out of the repo, and the
  location can be overridden with `$AGENT_HUB_STATE`.
- **zjstatus:** loaded locally via `plugin location="file:~/.config/zellij/plugins/zjstatus.wasm"`.
  To update it, replace the file and commit. It asks once for plugin permissions (run commands,
  read app state).
- **`claude` package: specific files, not the whole folder.** `~/.claude` stays a real directory,
  and Stow symlinks only the files the package contains. Stowing the whole folder was rejected
  because it would move these into the repo's working tree:
  - Claude's credentials and prompt history
  - 221 MB of conversation transcripts
  - auto-memory
  - `skills/`, which holds only work content (mdev copies and symlinks into
    `~/Documents/Work/…/agents-base`)

  To back up something new, move it into the package and run `stow -R claude -t ~`. Personal skills
  go in as `claude/.claude/skills/<name>/`. Because `~/.claude/skills/` already exists, Stow links
  just that skill's folder next to the work skills. No gitignore rules are needed.
- **Install** (to go in the repo README):
  1. Move the existing `~/.claude/settings.json` and `~/.claude/CLAUDE.md` aside first, since Stow
     won't overwrite real files; their content goes into the package.
  2. Run `stow agent-hub claude -t ~`.
  3. Desktop notifications need the `libnotify-bin` system package.

---

## Write side: `agent-event`

Bash plus `jq`. It reads the hook payload from stdin and keys on `$ZELLIJ_SESSION_NAME`. Outside
Zellij it does nothing. It **always exits 0**, because exit 2 from a `PreToolUse` hook would block the
tool.

### Event → state mapping

| Hook | State | Notes |
|---|---|---|
| `SessionStart` | `idle` | Registers the agent before its first prompt |
| `UserPromptSubmit` | `working` | Stores `prompt` as `task` |
| `PermissionRequest` | `needs_input` | `detail` = "Allow `<tool_name>`: `<command / file_path / input>`" |
| `PreToolUse` (matcher `AskUserQuestion`) | `needs_input` | `detail` = the question from `tool_input` (payload shape still to confirm) |
| `Notification` (matcher `permission_prompt\|elicitation_dialog\|agent_needs_input`) | `needs_input` | Keeps the more specific `detail` if already waiting; `idle_prompt` is ignored |
| `PostToolUse` | `working` | Only when not already `working` (otherwise exits early, so it stays cheap). Covers "permission granted, agent resumed" |
| `Stop` | `done` | `detail` = `last_assistant_message` (whitespace collapsed, truncated) |
| `StopFailure` | `error` | Ranked as urgent as `needs_input` |
| `SessionEnd` | — | Deletes the state file |

### State file

```json
{
  "session": "mt-web-foo",
  "pane": "terminal_3",
  "state": "needs_input",
  "since": 1760860800,
  "updated": 1760860812,
  "cwd": "/home/daniel/…/mt-web-foo",
  "task": "first ~300 chars of the last prompt",
  "detail": "pending question / last message"
}
```

- `since` changes only when the state changes; age and jump-next ordering use it.
- `cwd` is `$CLAUDE_PROJECT_DIR`, falling back to the payload's `cwd`. Git info is computed from it
  at read time.
- Writes are atomic: a temp file, then `mv`.

### Notifications

- Fires only on a **transition** into `needs_input`, `error` or `done`, so you don't get duplicates
  when `PermissionRequest` and `Notification` both arrive.
- `notify-send -a agent-hub "<session> needs you" "<detail>"`. Skipped silently if `notify-send`
  is missing.

### Debugging

`AGENT_HUB_DEBUG=1` appends raw payloads to `~/.local/state/agent-hub/debug.log`. Use it once to
confirm the payloads for `AskUserQuestion` and `PermissionRequest`.

---

## Read side: `agent-nav`

### Live agents

A state file counts only if its session appears in `zellij ls -n` and is not `EXITED`. Crashed
agents that never ran `SessionEnd` therefore drop out once their session is gone. A pane-level
`exited` check (from `list-panes`) is left out of v1 to keep `--summary` cheap. Add it if stale
entries turn up.

### Urgency order

1. `needs_input` / `error`
2. `done`
3. `idle`
4. `working`

Within a group, the oldest `since` comes first, so the agent that has waited longest leads.

### `--summary` (zjstatus)

- Prints `🔴<needs_input+error> 🟢<done> 🟡<working>`, leaving out zero counts. Prints nothing when
  no agents are running.
- Only reads the JSON files and calls `zellij ls` once, so polling it every 2s from every session
  is fine.

### Picker (`Alt a`)

- One line per agent: icon, session, age, branch, dirty-file count, then `detail` (or `task` while
  working).
- **Preview:**
  - Full `task` and `detail`.
  - `git log --oneline -5` and `git diff --stat`.
  - The agent's live screen via `zellij -s <session> action dump-screen --pane-id <pane>`, blank
    lines removed, last ~40 lines.
- **Enter** jumps to the agent.
- Git is computed live per line. In big repos (mt-web) `git status` can take a few hundred ms each;
  run those calls in parallel if the picker feels slow.

### `--next` (`Alt u`)

- Jumps to the first agent in urgency order, limited to `needs_input`, `error` and `done`, and
  skipping the current session.
- Repeated presses cycle through everything that needs you. Each agent stays in the list until you
  reply to it.
- Shows "Nothing needs you" for a second if the list is empty.

### Jumping

- **Other session:** `zellij action switch-session <session> --pane-id <pane>`. If the manual check
  shows the tab doesn't come forward, add `--tab-position` (looked up via `list-panes`).
- **Same session:** `zellij action focus-pane-id <pane>`.
- **Outside Zellij:** `exec zellij attach <session>`.

---

## Zellij config

### Keybinds

In `shared_except "locked"`, next to the other direct actions:

```kdl
// Agents (agent-hub package)
bind "Alt a" { Run "agent-nav" { floating true; close_on_exit true; name "agents"; }; }
bind "Alt u" { Run "agent-nav" "--next" { floating true; close_on_exit true; name "agents"; }; }
```

- `--next` briefly flashes a floating pane. Zellij has no keybind action that runs a command
  without opening a pane, so this is accepted.
- Add `alt-a` → `"\u001ba"` and `alt-u` → `"\u001bu"` to the Zed `Terminal` pass-through block.

### Layout `agent-hub.kdl`

A new layout, **separate from Zed for now**: `zed-tabs.kdl` and Zed's `terminal.shell` stay
unchanged. You use it by hand, from a terminal outside Zellij:
`zellij --layout agent-hub attach --create <worktree-name>`.

- **Tabs:** the same as `zed-tabs`: `git` (lazygit, focused), `ai` (empty shell; start `claude`
  yourself) and `server`.
- **Bars:** Zellij's built-in `zellij:tab-bar` stays at the top for tabs and modes. A one-row
  zjstatus bar at the bottom shows only the agent counts: `format_right "{command_agents}"`, with:
  - `command_agents_command "agent-nav --summary"`
  - `command_agents_interval "2"`
  - `command_agents_rendermode "static"`

**Only sessions started with `agent-hub` get the bar.** Sessions created by Zed (`zed-tabs`) and
plain `zellij` sessions keep their current bars. The keybinds, notifications and picker still work
in every session, because they only depend on the hooks. Wiring Zed to this layout is a later step.

---

## Test plan

1. **`agent-event` unit run:** pipe hand-written payloads for each event into it, with
   `ZELLIJ_SESSION_NAME=hubtest` and `AGENT_HUB_STATE=<scratch dir>`. Check the state file, the
   transitions and that `idle_prompt` is ignored.
2. **Real hooks:** after stowing, run `claude -p "say hi"` with `ZELLIJ_SESSION_NAME=hubtest` and
   `AGENT_HUB_DEBUG=1`. Confirm that `UserPromptSubmit` and `Stop` fire, the env vars arrive and
   `last_assistant_message` is filled.
3. **Interactive checks (you):**
   - Trigger a permission prompt and an `AskUserQuestion` in a real agent, then read `debug.log`.
   - Confirm the hooks still fire after a `/config` change, and that `~/.claude/settings.json` is
     still a symlink afterwards (`ls -l`). If Claude replaced it with a plain file, copy it back
     into the package and restow.
4. **Zellij:**
   - `zellij setup --check` for `config.kdl`.
   - Start a background session with
     `env -u ZELLIJ -u ZELLIJ_SESSION_NAME -u ZELLIJ_PANE_ID zellij --layout agent-hub attach --create-background <name>`,
     check its panes with `list-panes`, then attach once (you) to grant the plugin permissions and
     see the bar.
5. **Navigation (you):**
   - `Alt a` and `Alt u` across two sessions.
   - The manual `switch-session --pane-id` tab check: target a pane in a non-active tab of another
     session.

---

## Risks and open items

- [x] **`PATH` for Zellij:** verified. Every running Zellij server, including the ones Zed started,
  has `~/.local/bin` on its `PATH`. If that ever breaks, fall back to
  `Run "bash" "-c" "$HOME/.local/bin/agent-nav"`.
- [ ] **`switch-session --pane-id` tab focus:** manual check pending.
- [ ] **`AskUserQuestion`:** `PreToolUse` payload shape unconfirmed. Does it also trigger
  `PermissionRequest`?
- [ ] **Stowed `settings.json` / `CLAUDE.md`:** Claude might replace the symlink with a plain file
  when it rewrites settings (`/config`) or memory (`/memory`). Check with
  `ls -l ~/.claude/settings.json ~/.claude/CLAUDE.md` after the first change.
- [ ] **Session names with literal quotes** exist (e.g. `"mt-web-…-frame-routing""`) from an older
  launcher. Harmless for the state files, which use the name as-is, but they'll look odd in the
  picker.
- [ ] **One agent per session:** a second Claude in the same session overwrites the first one's
  state. Acceptable for now; the design is one agent per worktree.

## Later

- `agent-new` launcher (worktree + background session with the `agent-hub` layout +
  `claude -n <name>`). Known-good creation: `zellij attach --create-background <name>`.
  **Gotcha (verified):** when run from inside Zellij,
  `zellij --layout X attach --create-background <name>` adds the layout as a new tab to the
  *current* session instead of creating `<name>`. Clear `ZELLIJ`, `ZELLIJ_SESSION_NAME` and
  `ZELLIJ_PANE_ID` first.
- Wire Zed's terminal to the `agent-hub` layout.
- A read-only "summarize everything" command over the same state files.
- A custom plugin for clickable segments or a live sidebar, and pushing to zjstatus via `zellij pipe`
  instead of polling.
