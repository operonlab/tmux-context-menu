# tmux-context-menu — HERO screenshot.
# A high-clarity still of the plugin's context menu popped open on a pane:
# split / zoom / kill / rename / jump-sessions, plus the conditional Lazygit &
# Yazi popup entries (shown only when those tools are installed).
#
# Recorded against an isolated tmux server (socket: shot-context-menu, -f
# /dev/null) — never the user's live server. vhs cannot synthesize a real mouse
# right-click or a Meta keypress, so setup binds the SAME menu to Ctrl+g (a
# documented @context-menu-key option); the menu contents are byte-identical to
# the default Alt+q / right-click entry points.
Output "/private/tmp/claude-501/-Users-joneshong/aaff1254-ec36-4c2f-98bf-76d62cc8b483/scratchpad/hero-shots/context-menu/throwaway.gif"
Require tmux

Set Shell "bash"
Set FontSize 20
Set Width 1600
Set Height 900
Set Padding 20

# ---- hidden setup ----
Hide
Type "bash /private/tmp/claude-501/-Users-joneshong/aaff1254-ec36-4c2f-98bf-76d62cc8b483/scratchpad/hero-shots/context-menu/setup.sh"
Enter
Sleep 1500ms
Type "clear; tmux -L shot-context-menu attach -t hero"
Enter
Sleep 1500ms
Show

# ---- the shot: pop the menu open and freeze on it ----
Sleep 800ms
Ctrl+G
Sleep 1800ms
Screenshot docs/screenshot.png
Sleep 400ms

# ---- hidden teardown ----
Hide
Escape
Ctrl+C
Type "tmux -L shot-context-menu kill-server"
Enter
Sleep 600ms
