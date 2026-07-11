#!/usr/bin/env bash
# shellcheck shell=bash
#
# tmux-context-menu — clean removal.
#
# Unbinds everything this plugin bound and clears the runtime options it read,
# so the plugin leaves no trace in the running server. Safe to run repeatedly.
#
# Note: tmux has no "restore previous binding" primitive. Where this plugin
# overrode a tmux built-in (status-bar right-clicks, drag-to-copy), teardown
# only removes the plugin's binding. Reload your tmux config or restart the
# server to bring the built-in defaults back.
#
# No `set -e` / `set -u`: must fail quietly.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/helpers.sh
. "$CURRENT_DIR/helpers.sh"

PLUGIN="context-menu"
CACHE_DIR="${TMUX_TMPDIR:-/tmp}/${PLUGIN}-$(id -u)"

# 1. Menu entry points ---------------------------------------------------------
tmux unbind -T root MouseDown3Pane 2>/dev/null

opt_key="$(get_tmux_option @context-menu-key M-q)"
[ -n "$opt_key" ] && tmux unbind -n "$opt_key" 2>/dev/null
# Also drop the default key, in case @context-menu-key was changed since load.
tmux unbind -n M-q 2>/dev/null

# 2. Copy module ---------------------------------------------------------------
# Unconditional: the currently-read @context-menu-mouse-copy option may no
# longer match what was actually bound (e.g. it was "on" at load time and
# changed since), so always try to unbind these. Unbinding a binding that was
# never installed is a harmless no-op.
for tbl in copy-mode copy-mode-vi; do
	tmux unbind -T "$tbl" MouseDragEnd1Pane 2>/dev/null
	tmux unbind -T "$tbl" DoubleClick1Pane 2>/dev/null
	tmux unbind -T "$tbl" TripleClick1Pane 2>/dev/null
done
tmux unbind -T root DoubleClick1Pane 2>/dev/null
tmux unbind -T root TripleClick1Pane 2>/dev/null

# 3. Runtime options -----------------------------------------------------------
for opt in \
	@context-menu-mouse \
	@context-menu-key \
	@context-menu-disable-status-clicks \
	@context-menu-mouse-copy \
	@context-menu-copy-command \
	@context-menu-extra; do
	tmux set -gu "$opt" 2>/dev/null
done

# 4. Cache ---------------------------------------------------------------------
case "$CACHE_DIR" in
	*/"${PLUGIN}"-*) rm -rf "$CACHE_DIR" 2>/dev/null ;;
esac

exit 0
