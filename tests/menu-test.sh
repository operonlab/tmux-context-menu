#!/usr/bin/env bash
# shellcheck shell=bash
#
# tmux-context-menu — menu-builder test.
#
# Drives the real menu-building code and asserts that:
#   * the version comparator (version_ge) orders versions correctly;
#   * a version-gated item is OMITTED when the running tmux is too old, and
#     present when it is new enough;
#   * live-state items appear / disappear with the pane state they depend on
#     (Unzoom vs Zoom, Swap-with-marked, Respawn a dead pane);
#   * the entry points load and tear down cleanly.
#
# Everything that touches tmux runs on a private `tmux -L <socket>` server with
# TMUX unset, so it can never reach the caller's live session. The server is
# killed in an EXIT trap.
#
# No `set -e`: assertions are tallied into `fail` and the script exits non-zero
# if any tripped, matching the plugin's smoke-test style.
set -u

unset TMUX
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHOW="$REPO/scripts/show-menu.sh"
SOCK="ctxmenu-test-$$-${RANDOM}"

cleanup() { tmux -L "$SOCK" kill-server 2>/dev/null || true; }
trap cleanup EXIT

fail=0
ok()   { echo "ok: $1"; }
bad()  { echo "FAIL: $1"; fail=1; }

# assert_true "<desc>" <cmd...>   — passes when <cmd> exits 0.
assert_true()  { local d="$1"; shift; if "$@"; then ok "$d"; else bad "$d"; fi; }
# assert_false "<desc>" <cmd...>  — passes when <cmd> exits non-zero.
assert_false() { local d="$1"; shift; if "$@"; then bad "$d"; else ok "$d"; fi; }

# build   — the assembled menu, one field per line, built the way production
#           builds it (run-shell on the private server, so #{...} state queries
#           and the forced-version env var resolve exactly as they do live).
build() { tmux -L "$SOCK" run-shell "'$SHOW' --print"; }

# ---------------------------------------------------------------------------
# 1. version_ge — pure comparator (no tmux needed)
# ---------------------------------------------------------------------------
# shellcheck source=scripts/helpers.sh
. "$REPO/scripts/helpers.sh"

echo "== version_ge =="
assert_true  "3.3 >= 3.2"          version_ge 3.3 3.2
assert_true  "3.2 >= 3.2 (equal)"  version_ge 3.2 3.2
assert_true  "3.10 >= 3.2"         version_ge 3.10 3.2
assert_true  "3.3a >= 3.2 (letter suffix ignored)" version_ge 3.3a 3.2
assert_false "3.1 >= 3.2"          version_ge 3.1 3.2
assert_false "2.9 >= 3.2"          version_ge 2.9 3.2
assert_false "3.2 >= 3.10"         version_ge 3.2 3.10

# ---------------------------------------------------------------------------
# Private server for the state-driven checks.
# ---------------------------------------------------------------------------
tmux -L "$SOCK" -f /dev/null new-session -d -x 200 -y 50

echo "== live state: plain pane =="
menu="$(build)"
assert_true  "Zoom present when not zoomed"        grep -qx "Zoom" <<<"$menu"
assert_false "Unzoom absent when not zoomed"       grep -qx "Unzoom" <<<"$menu"
assert_false "Swap-with-marked absent, no mark"    grep -qx "Swap with marked pane" <<<"$menu"
assert_false "Respawn absent, pane alive"          grep -qx "Respawn Pane" <<<"$menu"

echo "== live state: zoomed window (needs 2 panes) =="
tmux -L "$SOCK" split-window -h
tmux -L "$SOCK" resize-pane -Z
menu="$(build)"
assert_true  "Unzoom present when zoomed"          grep -qx "Unzoom" <<<"$menu"
assert_false "Zoom absent when zoomed"             grep -qx "Zoom" <<<"$menu"
tmux -L "$SOCK" resize-pane -Z   # back to unzoomed

echo "== live state: a pane is marked =="
tmux -L "$SOCK" select-pane -m
menu="$(build)"
assert_true  "Swap-with-marked present when a pane is marked" grep -qx "Swap with marked pane" <<<"$menu"
tmux -L "$SOCK" select-pane -M   # unmark
menu="$(build)"
assert_false "Swap-with-marked gone after unmark"  grep -qx "Swap with marked pane" <<<"$menu"

echo "== live state: dead pane =="
tmux -L "$SOCK" set -g remain-on-exit on
tmux -L "$SOCK" split-window -h
sleep 0.2
tmux -L "$SOCK" send-keys 'exit' Enter   # the active (new) pane exits -> dead
sleep 0.4
dead="$(tmux -L "$SOCK" list-panes -F '#{pane_dead} #{pane_id}' | awk '$1==1{print $2; exit}')"
tmux -L "$SOCK" select-pane -t "$dead"
menu="$(build)"
assert_true  "Respawn present for a dead pane"     grep -qx "Respawn Pane" <<<"$menu"
tmux -L "$SOCK" kill-pane -t "$dead" 2>/dev/null

echo "== version gate: Customize Options =="
tmux -L "$SOCK" set-environment -g CONTEXT_MENU_FORCE_VERSION 3.1
menu="$(build)"
assert_false "Customize Options OMITTED on tmux 3.1 (needs 3.2)" grep -qx "Customize Options" <<<"$menu"
tmux -L "$SOCK" set-environment -g CONTEXT_MENU_FORCE_VERSION 3.3
menu="$(build)"
assert_true  "Customize Options present on tmux 3.3"            grep -qx "Customize Options" <<<"$menu"
tmux -L "$SOCK" set-environment -gu CONTEXT_MENU_FORCE_VERSION

echo "== @context-menu-extra flows into the built menu =="
tmux -L "$SOCK" set -g @context-menu-extra "Reload|Q|source-file ~/.tmux.conf"
menu="$(build)"
assert_true  "extra item present in built menu"    grep -qx "Reload" <<<"$menu"
tmux -L "$SOCK" set -gu @context-menu-extra

echo "== load binds entry points to the dynamic builder; teardown removes them =="
tmux -L "$SOCK" set -g @context-menu-mouse on
tmux -L "$SOCK" set -g @context-menu-key M-q
tmux -L "$SOCK" run-shell "$REPO/context-menu.tmux"
sleep 0.2
assert_true  "MouseDown3Pane -> run-shell show-menu" \
	bash -c 'tmux -L "$0" list-keys -T root | grep -F MouseDown3Pane | grep -q "show-menu.sh"' "$SOCK"
assert_true  "M-q -> run-shell show-menu" \
	bash -c 'tmux -L "$0" list-keys | grep -F "M-q" | grep -q "show-menu.sh"' "$SOCK"
tmux -L "$SOCK" run-shell "$REPO/scripts/teardown.sh"
sleep 0.2
assert_false "MouseDown3Pane removed after teardown" \
	bash -c 'tmux -L "$0" list-keys -T root | grep -qE "^bind-key +-T root +MouseDown3Pane "' "$SOCK"

echo
if [ "$fail" -eq 0 ]; then
	echo "ALL TESTS PASSED"
else
	echo "SOME TESTS FAILED"
fi
exit "$fail"
