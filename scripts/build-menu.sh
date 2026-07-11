#!/usr/bin/env bash
# shellcheck shell=bash
#
# tmux-context-menu — build and bind the right-click / keyboard context menu.
#
# Invoked once at plugin load (from context-menu.tmux) and safe to re-run at any
# time (bind-key overwrites, so rebuilding is idempotent).
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

MENU_TITLE='#[align=centre]#{window_index}:#{window_name}'

# --- options -----------------------------------------------------------------
opt_mouse="$(get_tmux_option @context-menu-mouse on)"
opt_key="$(get_tmux_option @context-menu-key M-q)"
opt_status="$(get_tmux_option @context-menu-disable-status-clicks on)"
opt_copy="$(get_tmux_option @context-menu-mouse-copy off)"
opt_copy_cmd="$(get_tmux_option @context-menu-copy-command "")"
opt_extra="$(get_tmux_option @context-menu-extra "")"

# --- assemble the menu body --------------------------------------------------
# Each visible row is a (label, key, command) triple; a lone "" is a separator.
menu=()
menu+=( "Horizontal Split" h "split-window -h -c '#{pane_current_path}'" )
menu+=( "Vertical Split"   v "split-window -v -c '#{pane_current_path}'" )

# Optional popup providers: only added when the tool is actually installed, so
# the menu never lists something that would error on click.
providers=()
if command -v lazygit >/dev/null 2>&1; then
	providers+=( "Lazygit (popup)" g "display-popup -E -xC -yC -w 90% -h 85% -d '#{pane_current_path}' -T ' lazygit ' lazygit" )
fi
if command -v yazi >/dev/null 2>&1; then
	providers+=( "Yazi (popup)" y "display-popup -E -xC -yC -w 90% -h 85% -d '#{pane_current_path}' -T ' yazi ' yazi" )
fi
if [ ${#providers[@]} -gt 0 ]; then
	menu+=( "" )
	menu+=( "${providers[@]}" )
fi

menu+=( "" )
menu+=( "Swap Up"   u "swap-pane -U" )
menu+=( "Swap Down" d "swap-pane -D" )
menu+=( "#{?window_zoomed_flag,Unzoom,Zoom}" z "resize-pane -Z" )
menu+=( "" )
menu+=( "Kill Pane"    x "kill-pane" )
menu+=( "Kill Window"  X "kill-window" )
menu+=( "Respawn Pane" r "respawn-pane -k" )
menu+=( "" )
menu+=( "New Window"     n "new-window" )
menu+=( "Rename Window"  R "command-prompt -F -I '#W' { rename-window -t '#{window_id}' '%%' }" )
menu+=( "Choose Session" s "choose-tree -Zs" )
menu+=( "" )
menu+=( "#{?pane_marked,Unmark,Mark}" m "select-pane -#{?pane_marked,M,m}" )
menu+=( "#{?mouse,Mouse OFF,Mouse ON}" M "set -g mouse #{?mouse,off,on}" )

# --- user-provided extra items ----------------------------------------------
# SECURITY: the command field is handed straight to tmux and runs on click.
# Only ever set @context-menu-extra from a tmux config you trust.
# Format: "label|key|command", multiple items separated by ";".
if [ -n "$opt_extra" ]; then
	menu+=( "" )
	old_ifs="$IFS"
	IFS=';'
	set -f
	# shellcheck disable=SC2086
	for raw in $opt_extra; do
		set +f
		[ -z "$raw" ] && { set -f; continue; }
		e_rest="${raw#*|}"
		[ "$e_rest" = "$raw" ] && { set -f; continue; }   # no "|" at all
		e_cmd="${e_rest#*|}"
		[ "$e_cmd" = "$e_rest" ] && { set -f; continue; }  # only two fields
		e_label="$(trim "${raw%%|*}")"
		e_key="$(trim "${e_rest%%|*}")"
		e_cmd="$(trim "$e_cmd")"
		[ -z "$e_label" ] && { set -f; continue; }
		[ -z "$e_key" ] && { set -f; continue; }
		menu+=( "$e_label" "$e_key" "$e_cmd" )
		set -f
	done
	set +f
	IFS="$old_ifs"
fi

# --- bind the entry points ---------------------------------------------------
# Mouse right-click, popped up at the pointer (-x M -y M).
if [ "$opt_mouse" = "on" ]; then
	tmux bind-key -T root MouseDown3Pane display-menu -T "$MENU_TITLE" -x M -y M "${menu[@]}"
fi

# Keyboard entry, popped up near the window/status position (-x W -y S).
if [ -n "$opt_key" ]; then
	tmux bind-key -n "$opt_key" display-menu -T "$MENU_TITLE" -x W -y S "${menu[@]}"
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
