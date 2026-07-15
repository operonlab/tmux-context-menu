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

# tmux_version  ->  the running tmux's version as MAJOR.MINOR (e.g. "3.7").
#
# Any trailing letter suffix is dropped (3.3a -> 3.3); a "next-*" master build
# string yields the numeric part it carries. Empty on failure.
tmux_version() {
	tmux -V 2>/dev/null | sed -n 's/^tmux[^0-9]*\([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p'
}

# version_ge <have> <need>  ->  succeeds (exit 0) when version HAVE >= NEED.
#
# Both are dotted MAJOR.MINOR; trailing non-digits are ignored so "3.3a"
# compares as "3.3" and a missing minor counts as 0. Used to gate menu items
# that need a newer tmux than may be running — an unmet gate drops the item so
# a click can never hit a command the running tmux doesn't understand.
version_ge() {
	local have="$1" need="$2"
	local h_maj="${have%%.*}" n_maj="${need%%.*}"
	local h_min="${have#*.}" n_min="${need#*.}"
	# A value with no "." leaves minor == whole string; treat that as 0.
	[ "$h_min" = "$have" ] && h_min=0
	[ "$n_min" = "$need" ] && n_min=0
	# Keep only the leading digits of each field (3 <- "3", 3 <- "3a").
	h_maj="${h_maj%%[!0-9]*}"; n_maj="${n_maj%%[!0-9]*}"
	h_min="${h_min%%[!0-9]*}"; n_min="${n_min%%[!0-9]*}"
	[ -z "$h_maj" ] && h_maj=0; [ -z "$n_maj" ] && n_maj=0
	[ -z "$h_min" ] && h_min=0; [ -z "$n_min" ] && n_min=0
	if [ "$h_maj" -ne "$n_maj" ]; then
		[ "$h_maj" -gt "$n_maj" ]
	else
		[ "$h_min" -ge "$n_min" ]
	fi
}
