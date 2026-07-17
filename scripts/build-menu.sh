#!/usr/bin/env bash
# shellcheck shell=bash
#
# tmux-context-menu — bind the right-click / keyboard context menu.
#
# Invoked once at plugin load (from context-menu.tmux) and safe to re-run at any
# time (bind-key overwrites, so rebuilding is idempotent).
#
# The menu body itself is assembled per open by scripts/show-menu.sh (bound via
# run-shell), so it can react to the running tmux version and to live pane state
# each time it opens. This file only reads the bind-time options and wires the
# entry points, the status-click guard and the optional copy module.
#
# No `set -e` / `set -u`: this runs from tmux load context and must fail quietly
# rather than abort tmux.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/helpers.sh
. "$CURRENT_DIR/helpers.sh"

PLUGIN="context-menu"
CACHE_DIR="${TMUX_TMPDIR:-/tmp}/${PLUGIN}-$(id -u)"
# Parent ($TMUX_TMPDIR or /tmp) always exists, so no -p.
mkdir -m 700 "$CACHE_DIR" 2>/dev/null
# Verify before chmod/use: a symlink pre-created at this predictable path
# would make `chmod`/writes follow it to an attacker-controlled target. If
# it's not a real directory, skip anything that needs the cache silently.
if [ -d "$CACHE_DIR" ] && [ ! -L "$CACHE_DIR" ]; then
	chmod 700 "$CACHE_DIR" 2>/dev/null
	cache_ok=1
else
	cache_ok=0
fi

# --- options -----------------------------------------------------------------
opt_mouse="$(get_tmux_option @context-menu-mouse on)"
opt_key="$(get_tmux_option @context-menu-key M-q)"
opt_status="$(get_tmux_option @context-menu-disable-status-clicks on)"
opt_copy="$(get_tmux_option @context-menu-mouse-copy off)"
opt_copy_cmd="$(get_tmux_option @context-menu-copy-command "")"

# --- bind the entry points ---------------------------------------------------
# Both entry points defer to show-menu.sh so the menu is (re)built at open time
# against the current tmux version and live pane state. show-menu.sh's argument
# selects where the menu pops up.
SHOW_MENU="$CURRENT_DIR/show-menu.sh"

# Mouse right-click, popped up at the pointer (show-menu.sh uses -x M -y M).
if [ "$opt_mouse" = "on" ]; then
	# The mouse coordinates and the clicked pane are expanded HERE, while the
	# mouse event still exists — after the run-shell hop, display-menu is a brand
	# new command with no mouse context, so `-x M -y M` inside show-menu.sh
	# resolves to nothing and the menu lands at 0,0 (top-left). #{mouse_x}/
	# #{mouse_y} carry the same client coordinates M would have used, and
	# #{pane_id} is the pane under the pointer (a mouse binding's default
	# target), so menu commands act on the clicked pane, not the focused one.
	tmux bind-key -T root MouseDown3Pane run-shell -b "'$SHOW_MENU' mouse '#{mouse_x}' '#{mouse_y}' '#{pane_id}'"
fi

# Keyboard entry, popped up near the window/status position (-x W -y S).
if [ -n "$opt_key" ]; then
	tmux bind-key -n "$opt_key" run-shell -b "'$SHOW_MENU' key"
fi

# --- disable status-bar right-clicks (avoid mis-taps) ------------------------
if [ "$opt_status" = "on" ]; then
	tmux unbind -T root MouseDown3Status 2>/dev/null
	tmux unbind -T root MouseDown3StatusLeft 2>/dev/null
	tmux unbind -T root M-MouseDown3Status 2>/dev/null
	tmux unbind -T root M-MouseDown3StatusLeft 2>/dev/null
fi

# --- optional copy module (opt-in) -------------------------------------------
# Double-click selects a word, triple-click selects a line, and a drag-select
# copies — all without scrolling the pane back to the bottom. This changes
# tmux's default click behavior, so it is off unless you turn it on.
if [ "$opt_copy" = "on" ] && [ "$cache_ok" = "1" ]; then
	if [ -n "$opt_copy_cmd" ]; then
		copy_action="send-keys -X copy-pipe-no-clear \"$opt_copy_cmd\""
	else
		copy_action="send-keys -X copy-selection-no-clear"
	fi

	copy_snippet="$CACHE_DIR/copy-bindings.tmux"
	cat > "$copy_snippet" 2>/dev/null <<EOF
bind-key -T copy-mode    MouseDragEnd1Pane $copy_action
bind-key -T copy-mode-vi MouseDragEnd1Pane $copy_action
bind-key -T copy-mode    DoubleClick1Pane select-pane \; send-keys -X select-word \; run-shell -d 0.3 \; $copy_action
bind-key -T copy-mode-vi DoubleClick1Pane select-pane \; send-keys -X select-word \; run-shell -d 0.3 \; $copy_action
bind-key -T copy-mode    TripleClick1Pane select-pane \; send-keys -X select-line \; run-shell -d 0.3 \; $copy_action
bind-key -T copy-mode-vi TripleClick1Pane select-pane \; send-keys -X select-line \; run-shell -d 0.3 \; $copy_action
bind-key -T root DoubleClick1Pane select-pane -t = \; if-shell -F "#{||:#{pane_in_mode},#{mouse_any_flag}}" { send-keys -M } { copy-mode -H ; send-keys -X select-word ; run-shell -d 0.3 ; $copy_action }
bind-key -T root TripleClick1Pane select-pane -t = \; if-shell -F "#{||:#{pane_in_mode},#{mouse_any_flag}}" { send-keys -M } { copy-mode -H ; send-keys -X select-line ; run-shell -d 0.3 ; $copy_action }
EOF
	tmux source-file "$copy_snippet" 2>/dev/null
fi

exit 0
