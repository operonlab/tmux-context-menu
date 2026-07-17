#!/usr/bin/env bash
# shellcheck shell=bash
#
# tmux-context-menu — bind the right-click / keyboard context menu.
#
# Invoked once at plugin load (from context-menu.tmux) and safe to re-run at any
# time (bind-key overwrites, so rebuilding is idempotent).
#
# The menu body is compiled at load time by scripts/show-menu.sh (--print) and
# baked into DIRECT display-menu bindings — see the compile block below for why
# (run-shell strips the mouse event). This file wires the entry points, the
# status-click guard and the optional copy module.
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

# --- compile the menu ONCE, bind display-menu DIRECTLY ------------------------
# 0.3.0 root fix: the menu body is compiled here at load time and baked into
# direct display-menu bindings — never opened through run-shell. A run-shell hop
# strips the originating mouse event, after which tmux can neither position the
# menu (`-x M` resolves to nothing → 0,0), keep it open past the button release,
# nor track hover (MENU_NOMOUSE, menu.c). A DIRECT mouse binding keeps the event:
# -x M -y M positions at the pointer, the clicked pane is the native default
# target, and press/hover/release behave exactly like tmux's own built-in menus
# (which are built the same way: static args + #{...} display-time conditionals).
# Consequence: @context-menu-source edits and when/minver gates apply on plugin
# reload (prefix+r), not per open — live-state dynamics stay per-open via the
# #{...} conditionals in item labels.
SHOW_MENU="$CURRENT_DIR/show-menu.sh"
MENU_TITLE='#[align=centre]#{window_index}:#{window_name}'
ver="${CONTEXT_MENU_FORCE_VERSION:-$(tmux_version)}"

menu_args=()
while IFS= read -r line || [ -n "$line" ]; do
	menu_args+=( "$line" )
done < <("$SHOW_MENU" --print 2>/dev/null)

# Click-style interaction needs -O (tmux 3.2+, MENU_STAYOPEN): without it the
# menu is DRAG-style — the release of the very click that opened it counts as
# "released outside an item" and dismisses the menu instantly (menu.c). With
# -O the opening release is ignored, hover highlights, a click on an item
# selects, and a press outside closes. Known edge: when the menu flips to fit
# the screen edge the pointer can land ON an item, and the opening release
# then selects it — the standard trade-off of click-style tmux menus.
stay=()
if version_ge "$ver" 3.2; then stay=(-O); fi
# The keyboard menu has no originating mouse event, so tmux flags it
# MENU_NOMOUSE (hover would dismiss it); -M (tmux 3.5+) turns mouse handling
# on. The mouse menu carries its own event and never needs -M.
kmouse=()
if version_ge "$ver" 3.5; then kmouse=(-M); fi

# A menu needs at least one (label, key, command) triple; on a broken compile
# leave the previous bindings alone rather than bind an empty menu.
if [ ${#menu_args[@]} -ge 3 ]; then
	# Mouse right-click, popped up at the pointer.
	if [ "$opt_mouse" = "on" ]; then
		tmux bind-key -T root MouseDown3Pane display-menu "${stay[@]}" -T "$MENU_TITLE" -x M -y M "${menu_args[@]}"
	fi
	# Keyboard entry, popped up near the window/status position.
	if [ -n "$opt_key" ]; then
		tmux bind-key -n "$opt_key" display-menu "${stay[@]}" "${kmouse[@]}" -T "$MENU_TITLE" -x W -y S "${menu_args[@]}"
	fi
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
