# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.1.0]: https://github.com/operonlab/tmux-context-menu/releases/tag/v0.1.0
