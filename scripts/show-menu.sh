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
#   mouse [x y pane]  show the menu at the mouse pointer. x/y/pane are the
#            #{mouse_x} #{mouse_y} #{pane_id} the BINDING expanded while the
#            mouse event still existed — display-menu runs after a run-shell
#            hop with no mouse context, so a bare `-x M -y M` here resolves to
#            0,0 (top-left). Falls back to M/M when the args are missing.
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

# Mouse-event context forwarded by the binding (empty when absent/legacy).
mouse_x="${2:-}"
mouse_y="${3:-}"
mouse_pane="${4:-}"
# Target args for display-menu AND the live-state query: the clicked pane, so
# state flags and menu commands apply to the pane under the pointer, not the
# focused one. Only trusted when it looks like a real pane id.
target=()
case "$mouse_pane" in
	%[0-9]*) target=(-t "$mouse_pane") ;;
esac

MENU_TITLE='#[align=centre]#{window_index}:#{window_name}'

# --- running tmux version ----------------------------------------------------
# CONTEXT_MENU_FORCE_VERSION overrides the detected version; it exists only so
# the test suite can exercise the "too old" path on a modern tmux binary.
# Needed by the minver gate in both the source and the built-in path.
ver="${CONTEXT_MENU_FORCE_VERSION:-$(tmux_version)}"

# --- options -----------------------------------------------------------------
opt_extra="$(get_tmux_option @context-menu-extra "")"
# @context-menu-source: a single file that, when set and readable, supplies the
# *entire* core menu body (replacing the built-in list below). It is read here
# per open — never by build-menu.sh — so edits take effect on the next menu open
# without a plugin reload.
#
# SECURITY: when set, this file is EXECUTED to produce the menu records, and any
# per-item `when` condition runs via `sh -c`. Same trust model as
# @context-menu-extra: only ever point it at a file you wrote and trust.
opt_source="$(get_tmux_option @context-menu-source "")"
# Defensive ~ expansion: a leading "~/" is expanded to $HOME (tmux stores the
# option value literally and does not expand tildes for us). The "~/" here is a
# literal case pattern we match against, not something we want tmux/bash to
# expand — hence the disable.
# shellcheck disable=SC2088
case "$opt_source" in "~/"*) opt_source="$HOME/${opt_source#\~/}";; esac

# --- assemble the menu body --------------------------------------------------
# Each visible row is a (label, key, command) triple; a lone "" is a separator.
menu=()
if [ -n "$opt_source" ] && [ -r "$opt_source" ]; then
	# Single-source mode: run the file, parse its 0x1F-separated records, and
	# use them as the whole core menu. Fields per `item` record (exactly 7):
	#   type␟label␟key␟command␟when␟minver␟desc   (␟ = 0x1F Unit Separator)
	# 0x1F is used (not TAB/space) because `read`/IFS collapse whitespace runs
	# and drop empty interior fields — with an empty when+minver, desc would
	# slide into when. 0x1F is non-whitespace, so empty interior fields are
	# preserved positionally, and it can never occur in a label/command/desc.
	if [ -x "$opt_source" ]; then
		src_raw="$("$opt_source" 2>/dev/null)"
	else
		src_raw="$(bash "$opt_source" 2>/dev/null)"
	fi
	# `desc` (7th field) must be read to isolate `minver` — otherwise minver
	# would swallow the trailing desc — but the menu itself never uses it.
	# shellcheck disable=SC2034
	while IFS=$'\037' read -r rtype label key command when minver desc || [ -n "$rtype" ]; do
		# Guards: skip blank / comment / empty-type lines; `sep` -> divider.
		case "$rtype" in
			''|'#'*) continue ;;
			sep) menu+=( "" ); continue ;;
			item) ;;
			*) continue ;;
		esac
		[ -z "$label" ] && continue
		[ -z "$key" ] && continue
		# Build-time removal: a non-empty `when` that exits non-zero drops the
		# item; a `minver` newer than the running tmux drops it too. (Explicit
		# if/fi form on purpose — an &&-chain loop body breaks the read loop.)
		if [ -n "$when" ]; then sh -c "$when" >/dev/null 2>&1 || continue; fi
		if [ -n "$minver" ]; then version_ge "$ver" "$minver" || continue; fi
		# desc is intentionally unused here: it is consumed by the cheatsheet
		# surface, never by display-menu.
		menu+=( "$label" "$key" "$command" )
	done <<< "$src_raw"
else
	# --- live state (one query) ----------------------------------------------
	# A single display-message round-trip, evaluated against the active pane (the
	# one the menu was opened over), parsed into shell flags. Only needed by the
	# built-in list, so it lives here rather than at the top of the script.
	state="$(tmux display-message "${target[@]}" -p '#{window_zoomed_flag} #{pane_dead} #{pane_marked_set}' 2>/dev/null)"
	st_zoomed="${state%% *}"
	state_rest="${state#* }"
	st_dead="${state_rest%% *}"
	st_marked="${state_rest##* }"
	[ -z "$st_zoomed" ] && st_zoomed=0
	[ -z "$st_dead" ] && st_dead=0
	[ -z "$st_marked" ] && st_marked=0

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
fi

# --- user-provided extra items ----------------------------------------------
# SECURITY: the command field is handed straight to tmux and runs on click.
# Only ever set @context-menu-extra from a tmux config you trust.
# Format: "label|key|command", multiple items separated by ";".
#
# This runs AFTER the core body in BOTH modes: @context-menu-source REPLACES the
# core list, while @context-menu-extra always APPENDS to whatever the core body
# ended up being.
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
		# A menu opened via run-shell has no originating mouse event, so tmux
		# flags it MENU_NOMOUSE — and under NOMOUSE any non-left-button mouse
		# event closes the menu, INCLUDING bare motion (which the mouse protocol
		# encodes with the release bits): hovering instantly dismissed it.
		# `display-menu -M` (tmux 3.5+) exists exactly for this — force mouse
		# handling on. Older tmux degrades to keyboard-only, same as before.
		mflag=()
		if version_ge "$ver" 3.5; then mflag=(-M); fi
		case "$mouse_x$mouse_y" in
			*[!0-9]* | '')
				# Coordinates missing/garbled (legacy binding) — degrade to M/M,
				# which needs a live mouse event and may land top-left.
				tmux display-menu "${mflag[@]}" "${target[@]}" -T "$MENU_TITLE" -x M -y M "${menu[@]}"
				;;
			*)
				# #{mouse_x}/#{mouse_y} are PANE-RELATIVE (format_cb_mouse_x →
				# cmd_mouse_at strips the pane offset), while a numeric -x/-y is
				# CLIENT-ABSOLUTE — translate back by the clicked pane's offsets,
				# plus the status area when it sits at the TOP (cmd_mouse_at
				# subtracts those lines too; with status at the bottom, zero).
				offs="$(tmux display-message "${target[@]}" -p '#{pane_left} #{pane_top}' 2>/dev/null)"
				pane_left="${offs%% *}"
				pane_top="${offs##* }"
				case "$pane_left$pane_top" in *[!0-9]* | '') pane_left=0 pane_top=0 ;; esac
				status_rows=0
				if [ "$(tmux show -gv status-position 2>/dev/null)" = "top" ]; then
					case "$(tmux show -gv status 2>/dev/null)" in
						on) status_rows=1 ;;
						[2-5]) status_rows="$(tmux show -gv status)" ;;
					esac
				fi
				tmux display-menu "${mflag[@]}" "${target[@]}" -T "$MENU_TITLE" \
					-x "$(( mouse_x + pane_left ))" \
					-y "$(( mouse_y + pane_top + status_rows ))" "${menu[@]}"
				;;
		esac
		;;
	*)
		tmux display-menu -T "$MENU_TITLE" -x W -y S "${menu[@]}"
		;;
esac

exit 0
