# tmux-context-menu — HERO screenshot.
# A high-clarity still of the plugin's context menu popped open on a pane:
# split / zoom / kill / rename / jump-sessions, plus the conditional Lazygit &
# Yazi popup entries (shown only when those tools are installed) — all framed by
# the family two-row pill cockpit + Starship prompt.
#
# Fully self-contained: docs/demo-setup.sh stages a sample project and a
# cockpit-style themed ISOLATED tmux server (socket cm-demo) — the user's real
# tmux server and config are never touched. vhs can synthesize neither a real
# right-click nor a Meta keypress, so the setup binds the SAME menu to Ctrl+g
# (@context-menu-key, a documented option); the menu contents are byte-identical
# to the default Alt+q / right-click entry points. Re-record from the repo root
# with:  vhs docs/screenshot.tape
Output "docs/screenshot-raw.gif"
Require tmux

Set Shell "bash"
Set FontFamily "MesloLGS Nerd Font Mono"
Set FontSize 20
Set Width 2392
Set Height 900
Set Padding 20

# ---- hidden setup ----
Hide
Type "bash docs/demo-setup.sh"
Enter
Sleep 3s
Type "clear; tmux -L cm-demo attach -t demo"
Enter
Sleep 1500ms
Show

# ---- the shot: pop the menu open and freeze on it ----
Sleep 1200ms
Ctrl+G
Sleep 2000ms
Screenshot docs/screenshot.png
Sleep 400ms

# ---- hidden teardown ----
Hide
Escape
Ctrl+B
Type "d"
Sleep 500ms
Type "tmux -L cm-demo kill-server"
Enter
Sleep 600ms
