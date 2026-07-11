# shellcheck shell=bash
# Shared helpers for tmux-context-menu.
# This file is *sourced*, never executed directly.
#
# No `set -e` / `set -u` here on purpose: these helpers run from tmux load and
# hook context, where a non-zero exit or unset var must stay quiet instead of
# aborting tmux. On failure we print an empty string and move on.

# get_tmux_option <option-name> <default-value>
#
# Prints the option's value when the option is *set* (even if it was set to an
# empty string), otherwise prints <default-value>.
#
# Distinguishing "unset" from "set-to-empty" is what lets a user disable the
# keyboard entry point with `set -g @context-menu-key ''` without silently
# falling back to the default binding.
get_tmux_option() {
	local option_name="$1"
	local default_value="$2"

	# `show-option -gq <name>` (without -v) prints the option line only when the
	# option is set; it prints nothing when unset. `grep -q .` tells the two
	# cases apart.
	if tmux show-option -gq "$option_name" 2>/dev/null | grep -q .; then
		tmux show-option -gqv "$option_name" 2>/dev/null
	else
		printf '%s' "$default_value"
	fi
}

# trim <string>  ->  string with leading/trailing whitespace removed.
trim() {
	local s="$1"
	s="${s#"${s%%[![:space:]]*}"}"
	s="${s%"${s##*[![:space:]]}"}"
	printf '%s' "$s"
}
