#!/usr/bin/env bash
# shellcheck shell=bash
#
# tmux-context-menu — assemble the context menu (the single compile step).
#
# 0.3.0: this script is a COMPILER, not a display path. build-menu.sh runs it
# once at plugin load (--print) and bakes the output into DIRECT display-menu
# bindings. A menu opened via run-shell carries no mouse event, and tmux can
# then neither position it (`-x M` resolves to nothing → 0,0), keep it open
# past the button release, nor track hover (MENU_NOMOUSE, menu.c:332) — the
# per-open mouse/key display modes were unfixable by construction and are gone.
# Live-state dynamics live in #{...} format conditionals expanded by
# display-menu at open time, exactly like tmux's own built-in menus.
#
# Modes (first argument):
#   --print  print the assembled menu, one field per line  [default]
#
# No `set -e` / `set -u`: runs from tmux run-shell context and must fail quietly
# rather than abort tmux.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/helpers.sh
. "$CURRENT_DIR/helpers.sh"

mode="${1:---print}"


# --- running tmux version ----------------------------------------------------
# CONTEXT_MENU_FORCE_VERSION overrides the detected version; it exists only so
# the test suite can exercise the "too old" path on a modern tmux binary.
# Needed by the minver gate in both the source and the built-in path.
ver="${CONTEXT_MENU_FORCE_VERSION:-$(tmux_version)}"

# --- options -----------------------------------------------------------------
opt_extra="$(get_tmux_option @context-menu-extra "")"
# @context-menu-source: a single file that, when set and readable, supplies the
# *entire* core menu body (replacing the built-in list below). Since 0.3.0 it is
# read ONCE at plugin load (build-menu.sh compiles the output into the bindings)
# — edits take effect on the next plugin reload (prefix+r), not per open.
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
	# Built-in list. State-dependent items use #{...} format conditionals —
	# expanded by display-menu at OPEN time — never a shell-time state query:
	# the compiled binding must stay correct for every future open.
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
	# A leading `-` in the expanded label greys the item out (tmux native
	# convention, same as the built-in M-MouseDown3Pane menu): swap needs a
	# marked pane, respawn needs a dead one.
	menu+=( "#{?pane_marked_set,,-}Swap with marked pane" S "swap-pane" )
	menu+=( "#{?window_zoomed_flag,Unzoom,Zoom}" z "resize-pane -Z" )

	menu+=( "" )
	menu+=( "Kill Pane"   x "kill-pane" )
	menu+=( "Kill Window" X "kill-window" )
	menu+=( "#{?pane_dead,,-}Respawn Pane" r "respawn-pane -k" )

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
	*)
		# 0.3.0 removed the per-open mouse/key display modes: run-shell loses
		# the mouse event, and display-menu can then neither position at the
		# pointer nor keep native press/hover/click handling. The menu is now
		# compiled into a direct binding by build-menu.sh at plugin load.
		tmux display-message "context-menu: '$mode' mode removed in 0.3.0 — reload the plugin to rebuild the bindings" 2>/dev/null
		;;
esac

exit 0
