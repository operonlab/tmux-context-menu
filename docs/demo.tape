# tmux-context-menu demo — a right-click (or Alt+q) context menu at your cursor:
# split, zoom, kill, rename, jump sessions, with no prefix keys to memorize.
#
# Recorded against an isolated tmux server (socket: vhsdemo-context-menu,
# -f /dev/null), never the user's live server. vhs can synthesize neither a real
# mouse right-click nor a Meta keypress, so the setup binds the SAME menu to a
# key vhs can send (Ctrl+g) and this tape triggers that; the menu contents are
# identical to the default Alt+q / right-click entry points shown in the banner.
Output docs/demo.gif
Require tmux

Set Shell "bash"
Set Width 1200
Set Height 660
Set FontSize 15
Set Padding 12
Set TypingSpeed 55ms

# ---- hidden setup ----
Hide
Type "bash /private/tmp/claude-501/-Users-joneshong/aaff1254-ec36-4c2f-98bf-76d62cc8b483/scratchpad/vhs-visual/setup-context-menu.sh"
Enter
Sleep 1s
Type "clear; tmux -L vhsdemo-context-menu attach -t demo"
Enter
Sleep 1500ms
Show

# ---- visible demo ----
Sleep 1500ms

# open the menu with the keyboard hotkey
Ctrl+G
Sleep 2500ms

# walk down a few entries to show the menu is live
Down
Sleep 500ms
Down
Sleep 500ms
Down
Sleep 500ms
Down
Sleep 1500ms

# close it without running anything
Escape
Sleep 1500ms

# ---- hidden teardown ----
Hide
Escape
Ctrl+C
Type "tmux -L vhsdemo-context-menu kill-server"
Enter
Sleep 500ms
