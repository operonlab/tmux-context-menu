# tmux-context-menu demo — a right-click (or Alt+q) context menu at your cursor:
# split, zoom, kill, rename, jump sessions, plus Lazygit / Yazi popups when
# installed — no prefix keys to memorize.
# Fully self-contained: docs/demo-setup.sh stages a sample project and a
# cockpit-style themed ISOLATED tmux server (socket cm-demo). vhs can synthesize
# neither a real right-click nor a Meta keypress, so the setup binds the SAME
# menu to Ctrl+g (@context-menu-key) — identical contents. Re-record from the
# repo root with:  vhs docs/demo.tape
Output "docs/demo.gif"
Require tmux

Set Shell "bash"
Set FontFamily "MesloLGS Nerd Font Mono"
Set FontSize 20
Set Width 2392
Set Height 900
Set Padding 20
Set TypingSpeed 35ms

Hide
Type "bash docs/demo-setup.sh"
Enter
Sleep 3s
Type "clear; tmux -L cm-demo attach -t demo"
Enter
Sleep 1500ms
Show

# the cockpit: a working pane, waiting for the menu
Sleep 1500ms

# open the menu at the cursor (stand-in for right-click / Alt+q)
Ctrl+G
Sleep 2000ms

# walk down a few entries to show the menu is live
Down
Sleep 500ms
Down
Sleep 500ms
Down
Sleep 1200ms

# pick "Vertical Split" — the menu actually runs the command
Type "v"
Sleep 2500ms

# open the menu again, this time on the freshly split pane
Ctrl+G
Sleep 2500ms

# close it without running anything
Escape
Sleep 1200ms

Hide
Escape
Ctrl+B
Type "d"
Sleep 500ms
Type "tmux -L cm-demo kill-server"
Enter
Sleep 500ms
