# Migrating manual binaries to `mise`

**Status:** analysis only — not yet migrated (deferred).
**Investigated:** 2026-07-01. Host: Tuxedo/Ubuntu-based, x86_64.

Goal: manage the currently hand-installed CLI tools with [`mise`](https://mise.jdx.dev)
so updating them becomes one command (`mise upgrade`) instead of manual re-downloads.

---

## TL;DR

- `mise` is **already installed** (`~/.local/bin/mise`, v2026.5.1) and already manages **node + ruby**.
- Most manual tools **can** move to mise. Updating afterward: `mise upgrade` / `mise up`.
- You **do not** prefix commands with `mise` — tools go on `PATH` and run directly (`zellij`, `lazygit`, …).
- **One real blocker for `zellij` specifically:** mise is wired via `mise activate` (interactive-shell
  only), but Zed's `terminal.shell` runs a *non-interactive, non-login* `bash -c`, which never activates
  mise. Today that works only because `zellij` lives in `/usr/local/bin` (always on `PATH`). See
  [The Zed gotcha](#the-zed-terminalshell-gotcha-important).

---

## Current manual-install inventory

| Tool | Location | apt/dpkg? | cargo? |
|---|---|---|---|
| zellij | `/usr/local/bin/zellij` | no | no (static musl binary, downloaded release) |
| lazygit | `/usr/local/bin/lazygit` | no | — |
| lokalise2 | `/usr/local/bin/lokalise2` | no | — |
| starship | `/usr/local/bin/starship` | no | — |
| typst | `/usr/local/bin/typst` | no | — |
| mdev | `/usr/local/bin/mdev` | no | — (internal/custom tool) |
| spacetime | `~/.local/bin/spacetime` | no | — (has its own updater) |

Other `~/.local/bin` binaries (`claude`, `zed`, `mise`) have their own update mechanisms — out of scope.

Notes:
- `/usr/local/bin` is `root:root` and **not** writable without `sudo` — replacing/removing anything
  there needs `sudo`.
- No packages are currently cargo-installed (`cargo install --list` is empty; no `~/.cargo/bin`).
  System `cargo` is `/usr/bin/cargo` (apt, Rust 1.75.0 — old; may fail to build newer crates).

---

## mise availability per tool

Checked against the live `mise registry` on this machine. All required backends are present
(`aqua asdf cargo core github ubi …`).

| Tool | mise support | Command to adopt |
|---|---|---|
| zellij | ✅ registry | `mise use -g zellij@latest` |
| lazygit | ✅ registry | `mise use -g lazygit@latest` |
| starship | ✅ registry | `mise use -g starship@latest` |
| typst | ✅ registry | `mise use -g typst@latest` |
| lokalise2 | ✅ via `ubi` (not in registry) | `mise use -g "ubi:lokalise/lokalise-cli-2-go[exe=lokalise2]"` |
| spacetime | ⚠️ self-updates | leave as-is (`spacetime version upgrade`); or `ubi:clockworklabs/SpacetimeDB` |
| mdev | ❌ not public | keep manual |

Details:
- **lokalise2**: real repo is `lokalise/lokalise-cli-2-go` (the obvious `lokalise-cli-2` name 404s).
  It publishes assets like `lokalise2_linux_x86_64.tar.gz`, so `ubi` works. The extracted binary is
  named `lokalise2`, hence the `exe=lokalise2` hint. Installed version was 3.1.4.
- **spacetime**: SpacetimeDB CLI; prints `spacetime version upgrade` prompts itself, so mise adds little.

---

## Current mise wiring (verified)

```
~/.bashrc:134:  eval "$(/home/daniel/.local/bin/mise activate bash)"
```

- Uses **`mise activate`** (dynamic PATH injection through a shell hook), **not** shims-on-PATH.
- The shims dir exists (`~/.local/share/mise/shims`) but is **not** on `PATH` by default.
- `mise activate` lives in `.bashrc` → only applies to **interactive** shells.
- Layered managers already in play: `node` resolves to `~/.volta/bin/node` (**Volta**, not mise),
  so mise's node is shadowed. Worth untangling if consolidating.

### Do you need to type `mise <tool>`? — No.
With `mise activate`, adopted tools are on `PATH` in interactive shells; you run them directly.
`mise <tool>` is not a thing; the explicit escape hatch is `mise exec -- <tool>` (rarely needed).

---

## The Zed `terminal.shell` gotcha (IMPORTANT)

Zed launches the terminal via (see `zed/.config/zed/settings.json`):

```
bash -c 'if [ -z "$ZELLIJ" ]; then … exec zellij --layout zed attach --create "…"; else exec bash -l; fi'
```

That `bash -c` is **neither interactive nor login**, so it sources **neither `.bashrc` nor `.profile`**,
so **`mise activate` never runs there**. Consequences:

- **`zellij`** is invoked by this non-interactive launcher. If zellij becomes mise-managed (removed from
  `/usr/local/bin`), the launcher will **not find it** → the Zed layout terminal breaks.
- The **other tools** (lazygit, lokalise2, starship, typst) are invoked *inside* zellij panes, which run
  interactive shells (→ `.bashrc` → mise active), so they'd work fine with no prefix.

So: only **zellij** has the PATH problem.

### Options to fix zellij-under-mise (pick one at migration time)
1. **Keep `zellij` in `/usr/local/bin`** (don't migrate this one). Simplest; zero risk to Zed.
2. **Put mise shims on PATH for non-interactive shells** — e.g. prepend `~/.local/share/mise/shims`
   to `PATH` inside the Zed `terminal.shell` command, or export it from a login-level profile
   (`~/.profile`) that Zed's env capture reads.
3. **Reference the mise shim path explicitly** in the Zed command
   (e.g. `~/.local/share/mise/shims/zellij`).

**Open question to answer first:** does Zed's terminal env-capture (it runs a login shell in the project
root) actually surface any mise paths? If `.profile`/`.bash_profile` don't invoke mise, it won't — verify
before removing `/usr/local/bin/zellij`.

---

## Suggested migration order (when ready)

1. Verify how Zed's terminal picks up `PATH` / whether mise reaches non-interactive shells.
2. Decide zellij strategy (option 1–3 above).
3. `mise use -g` the four registry tools + the lokalise `ubi` entry.
4. Confirm each resolves to the mise version (`mise which <tool>` / `command -v <tool>`).
5. Remove the now-duplicate `/usr/local/bin` copies (`sudo`) to avoid running stale versions.
   - Skip `mdev` (keep) and `zellij` (per chosen strategy).
6. Restart zellij sessions after upgrading its binary (client/server version mismatch otherwise:
   `zellij kill-all-sessions && zellij delete-all-sessions --force`).
7. Updates from then on: `mise upgrade`.

## Caveats checklist
- [ ] `/usr/local/bin` removals need `sudo`.
- [ ] Duplicate binaries: ensure PATH order or removal so mise versions win.
- [ ] zellij + non-interactive Zed launcher (the main blocker above).
- [ ] Volta already owns `node`; mise's node is shadowed — reconcile if consolidating.
- [ ] `lokalise2` needs the `exe=lokalise2` hint with `ubi`.
- [ ] Running zellij sessions must be restarted after a version change.
