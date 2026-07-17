# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-07-17

### Changed (breaking)
- **The menu is now COMPILED into direct `display-menu` bindings at plugin
  load** instead of being assembled per open through `run-shell`. A run-shell
  hop strips the originating mouse event, after which tmux can neither position
  the menu (`-x M` resolves to nothing — it opened at the top-left), keep it
  open past the button release (you had to hold the right button), nor track
  hover (`MENU_NOMOUSE` dismissed it on the first motion event). Direct
  bindings keep the event, so position / press / hover / click behave exactly
  like tmux's own built-in menus — which are constructed the same way.
- `show-menu.sh` is now the compile step only (`--print`); its per-open
  `mouse` / `key` display modes are removed. Anything binding those modes
  directly should rebind to the plugin-managed entry points.
- `@context-menu-source` and its `when` / `minver` gates are evaluated at
  **load time**; edits apply on the next plugin reload, not the next open.
- Built-in live-state items are now display-time `#{...}` conditionals:
  `Zoom`/`Unzoom` is one conditional label, and `Swap with marked pane` /
  `Respawn Pane` grey out (leading `-`) until they apply, instead of appearing
  and disappearing.

## [0.2.0] - 2026-07-16

### Added
- `@context-menu-source <path>` (default `''`): point it at a file that prints
  the whole menu as `0x1F`-separated records and it **replaces** the built-in
  core list. Read — and executed — per menu open by `show-menu.sh` (never by
  `build-menu.sh`), so edits take effect on the next open without a plugin
  reload. Each `item` record carries label / key / command plus optional
  build-time gates: `when` (run via `sh -c`, non-zero exit drops the item) and
  `minver` (`version_ge`, an older tmux drops the item), with an ignored `desc`
  cheatsheet field; a lone `sep` renders a divider. Labels pass through verbatim
  so tmux `#{...}` format conditionals still render live. `@context-menu-extra`
  still appends after the sourced core. Documented as executing the file — same
  trust model as `@context-menu-extra`; only point it at a file you trust.

### Notes
- Off by default: with `@context-menu-source` unset, the built menu is
  byte-identical to 0.1.0 across the plain / zoomed / marked / version-gated /
  extra state matrix.

## [0.1.0] - 2026-07-11

### Added
- Mouse right-click context menu bound to `MouseDown3Pane`, popped up at the
  pointer (`-x M -y M`).
- Keyboard entry point to the same menu (`@context-menu-key`, default `M-q`).
- Native menu items only: Horizontal/Vertical Split, Swap Up/Down,
  Zoom/Unzoom (format-conditional), Kill Pane/Window, Respawn Pane, New Window,
  Rename Window, Choose Session, Mark/Unmark, Mouse ON/OFF.
- Auto-detected popup providers: Lazygit and Yazi entries appear only when the
  respective command is found on `PATH` at load time.
- `@context-menu-extra` for user-defined items (`label|key|command`, `;`
  separated). Documented as executing user-supplied commands.
- `@context-menu-mouse` to toggle the mouse binding (default `on`).
- `@context-menu-disable-status-clicks` to unbind status-bar right-clicks and
  avoid mis-taps (default `on`).
- Opt-in copy module (`@context-menu-mouse-copy`, default `off`): double-click
  selects a word, triple-click selects a line, drag-selects copy — without
  scrolling the pane. Uses tmux's internal `copy-selection-no-clear` by default;
  `@context-menu-copy-command` optionally pipes to a system clipboard command.
- `scripts/teardown.sh` for clean removal of all bindings and runtime options.
- TPM entry point (`context-menu.tmux`) and a no-TPM `run-shell` install path.
- MIT license, English README, Traditional Chinese docs, CI (shellcheck + an
  isolated-socket smoke test).

[0.2.0]: https://github.com/operonlab/tmux-context-menu/releases/tag/v0.2.0
[0.1.0]: https://github.com/operonlab/tmux-context-menu/releases/tag/v0.1.0
