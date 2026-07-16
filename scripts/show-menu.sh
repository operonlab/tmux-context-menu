#!/usr/bin/env bash
# shellcheck shell=bash
#
# tmux-context-menu — assemble and show the context menu.
#
# Bound (via run-shell) to the mouse right-click and the keyboard hotkey, so it
# runs once per menu open. Building the menu here — instead of baking one fixed
# list at load time — lets it react to what is true *right now*:
#
#   * version gate — items that need a newer tmux than is running are dropped,
#     so an old tmux gets a shorter menu instead of a click that errors;
#   * live state  — an item appears only when it applies to the pane the menu
#     was opened over (Unzoom vs Zoom, Swap-with-marked, Respawn a dead pane).
#
# Modes (first argument):
#   mouse    show the menu at the mouse pointer   (-x M -y M)
#   key      show the menu near the status line   (-x W -y S)   [default]
#   --print  print the assembled menu, one field per line, and exit — used by
#            the test suite to inspect the built menu without an attached client.
#
# No `set -e` / `set -u`: runs from tmux run-shell context and must fail quietly
# rather than abort tmux.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/helpers.sh
. "$CURRENT_DIR/helpers.sh"

mode="${1:-key}"

MENU_TITLE='#[align=centre]#{window_index}:#{window_name}'

# --- live state (one query) --------------------------------------------------
# A single display-message round-trip, evaluated against the active pane (the
# one the menu was opened over), parsed into shell flags.
state="$(tmux display-message -p '#{window_zoomed_flag} #{pane_dead} #{pane_marked_set}' 2>/dev/null)"
st_zoomed="${state%% *}"
state_rest="${state#* }"
st_dead="${state_rest%% *}"
st_marked="${state_rest##* }"
[ -z "$st_zoomed" ] && st_zoomed=0
[ -z "$st_dead" ] && st_dead=0
[ -z "$st_marked" ] && st_marked=0

# --- running tmux version ----------------------------------------------------
# CONTEXT_MENU_FORCE_VERSION overrides the detected version; it exists only so
# the test suite can exercise the "too old" path on a modern tmux binary.
ver="${CONTEXT_MENU_FORCE_VERSION:-$(tmux_version)}"

# --- options -----------------------------------------------------------------
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
# Live: only when a pane is marked somewhere on the server. `swap-pane` with no
# source/target swaps the active pane with the marked one.
if [ "$st_marked" = "1" ]; then
	menu+=( "Swap with marked pane" S "swap-pane" )
fi
# Live: show the zoom action that applies to the current state, not both.
if [ "$st_zoomed" = "1" ]; then
	menu+=( "Unzoom" z "resize-pane -Z" )
else
	menu+=( "Zoom" z "resize-pane -Z" )
fi

menu+=( "" )
menu+=( "Kill Pane"   x "kill-pane" )
menu+=( "Kill Window" X "kill-window" )
# Live: respawning only makes sense once the pane's process has exited (dead).
if [ "$st_dead" = "1" ]; then
	menu+=( "Respawn Pane" r "respawn-pane -k" )
fi

menu+=( "" )
menu+=( "New Window"     n "new-window" )
menu+=( "Rename Window"  R "command-prompt -F -I '#W' { rename-window -t '#{window_id}' '%%' }" )
menu+=( "Choose Session" s "choose-tree -Zs" )
# Version gate: customize-mode was introduced in tmux 3.2; on anything older it
# is an unknown command, so drop the item rather than offer a dead click.
if version_ge "$ver" 3.2; then
	menu+=( "Customize Options" c "customize-mode -Z" )
fi

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

# --- render ------------------------------------------------------------------
case "$mode" in
	--print)
		for el in "${menu[@]}"; do
			printf '%s\n' "$el"
		done
		;;
	mouse)
		tmux display-menu -T "$MENU_TITLE" -x M -y M "${menu[@]}"
		;;
	*)
		tmux display-menu -T "$MENU_TITLE" -x W -y S "${menu[@]}"
		;;
esac

exit 0
