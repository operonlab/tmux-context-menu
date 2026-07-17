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
# Private scratch dir for the @context-menu-source fixture; removed on exit.
FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ctxmenu-fixture-XXXXXX")"

cleanup() {
	tmux -L "$SOCK" kill-server 2>/dev/null || true
	rm -rf "$FIXTURE_DIR" 2>/dev/null || true
}
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

# ---------------------------------------------------------------------------
# @context-menu-source — the single-file menu body (0x1F records).
# ---------------------------------------------------------------------------
FIXTURE="$FIXTURE_DIR/menu-items.sh"

# write_fixture <when-condition>
#   Regenerates the fixture. <when-condition> is the shell condition for the
#   one when-gated item ("" = always include, "false" = drop, "true" = keep).
#   Emits, via the spec's US-helpers: a plain item, a `sep`, a
#   conditional-label item (passthrough), a minver-gated item (3.2), an item
#   whose desc must never leak, and — to prove the separator choice is
#   load-bearing — one record whose fields are joined by SPACE instead of 0x1F.
write_fixture() {
	local when_val="$1"
	cat > "$FIXTURE" <<'HDR'
US=$(printf '\037')
item() { printf '%s%s%s%s%s%s%s%s%s%s%s%s%s\n' item "$US" "$1" "$US" "$2" "$US" "$3" "$US" "${4-}" "$US" "${5-}" "$US" "${6-}"; }
sep()  { printf 'sep\n'; }
HDR
	{
		echo "item 'Fixture Plain' p 'display-message Plain' '' '' 'plain cheatsheet'"
		echo "sep"
		echo "item '#{?window_zoomed_flag,Unzoom,Zoom}' z 'resize-pane -Z' '' '' '縮放 / 取消縮放'"
		echo "item 'Minver Gated' V 'customize-mode -Z' '' '3.2' 'needs tmux 3.2'"
		echo "item 'Has Desc' D 'display-message HasDesc' '' '' 'human readable desc'"
		# Space-joined (not 0x1F): with the real separator this whole line lands
		# in rtype, matches no case arm, and is dropped. If IFS ever collapsed
		# on whitespace it would parse into a clean row — which the test forbids.
		echo "printf '%s\\n' 'item BrokenSpaceRow b broken-cmd'"
		printf "item 'When Gated' w 'display-message Gated' '%s' '' 'gated by when'\n" "$when_val"
	} >> "$FIXTURE"
}

# sep_after_plain <menu-text>  — true when an empty menu line (the rendered
# `sep`) immediately follows the plain item's three fields.
sep_after_plain() {
	awk '
		p3=="Fixture Plain" && p2=="p" && p1=="display-message Plain" && $0=="" {ok=1}
		{p3=p2; p2=p1; p1=$0}
		END{exit(ok?0:1)}
	' <<<"$1"
}

echo "== @context-menu-source: replace semantics + record parsing =="
write_fixture ""
tmux -L "$SOCK" set -g @context-menu-source "$FIXTURE"
menu="$(build)"
assert_false "built-in dropped in source mode"       grep -qx "Horizontal Split" <<<"$menu"
assert_true  "plain source item present"             grep -qx "Fixture Plain" <<<"$menu"
assert_true  "separator (empty line) after the plain item" sep_after_plain "$menu"
assert_true  "conditional label passed through verbatim" \
	grep -qxF '#{?window_zoomed_flag,Unzoom,Zoom}' <<<"$menu"
assert_true  "item with a desc still renders"        grep -qx "Has Desc" <<<"$menu"
assert_false "desc text never leaks into the menu"   grep -qx "human readable desc" <<<"$menu"
assert_false "space-joined record is not a clean row" grep -qx "BrokenSpaceRow" <<<"$menu"

echo "== @context-menu-source: when-gate condition inversion =="
write_fixture false
menu="$(build)"
assert_false "when=false drops the item"             grep -qx "When Gated" <<<"$menu"
write_fixture true
menu="$(build)"
assert_true  "when=true keeps the item"              grep -qx "When Gated" <<<"$menu"

echo "== @context-menu-source: minver gate flip =="
tmux -L "$SOCK" set-environment -g CONTEXT_MENU_FORCE_VERSION 3.1
menu="$(build)"
assert_false "minver 3.2 item dropped on forced tmux 3.1" grep -qx "Minver Gated" <<<"$menu"
tmux -L "$SOCK" set-environment -g CONTEXT_MENU_FORCE_VERSION 3.3
menu="$(build)"
assert_true  "minver 3.2 item present on forced tmux 3.3"  grep -qx "Minver Gated" <<<"$menu"
tmux -L "$SOCK" set-environment -gu CONTEXT_MENU_FORCE_VERSION

echo "== @context-menu-source: @context-menu-extra still appends =="
tmux -L "$SOCK" set -g @context-menu-extra "Reload|Q|source-file ~/.tmux.conf"
menu="$(build)"
assert_true  "extra appends in source mode"          grep -qx "Reload" <<<"$menu"
assert_false "core stays replaced when extra appends" grep -qx "Horizontal Split" <<<"$menu"
tmux -L "$SOCK" set -gu @context-menu-extra
tmux -L "$SOCK" set -gu @context-menu-source

echo "== load binds entry points to the dynamic builder; teardown removes them =="
tmux -L "$SOCK" set -g @context-menu-mouse on
tmux -L "$SOCK" set -g @context-menu-key M-q
tmux -L "$SOCK" set -g @context-menu-mouse-copy on
tmux -L "$SOCK" run-shell "$REPO/context-menu.tmux"
sleep 0.2
assert_true  "MouseDown3Pane -> run-shell show-menu" \
	bash -c 'tmux -L "$0" list-keys -T root | grep -F MouseDown3Pane | grep -q "show-menu.sh"' "$SOCK"
assert_true  "M-q -> run-shell show-menu" \
	bash -c 'tmux -L "$0" list-keys | grep -F "M-q" | grep -q "show-menu.sh"' "$SOCK"
assert_true  "copy module root double-click bound" \
	bash -c 'tmux -L "$0" list-keys -T root | grep -qE "DoubleClick1Pane[[:space:]]+select-pane -t ="' "$SOCK"
tmux -L "$SOCK" run-shell "$REPO/scripts/teardown.sh"
sleep 0.2
assert_false "MouseDown3Pane removed after teardown" \
	bash -c 'tmux -L "$0" list-keys -T root | grep -qE "^bind-key +-T root +MouseDown3Pane "' "$SOCK"

echo "== mouse position: binding forwards event coords; display-menu uses them =="
# The mouse binding must expand #{mouse_x}/#{mouse_y}/#{pane_id} at event time —
# after the run-shell hop display-menu has no mouse context, so `-x M -y M`
# lands the menu at 0,0 (the 2026-07-17 top-left regression).
tmux -L "$SOCK" run-shell "$REPO/context-menu.tmux"
sleep 0.2
assert_true  "mouse binding forwards mouse_x/mouse_y/pane_id" \
	bash -c 'tmux -L "$0" list-keys -T root | grep -F MouseDown3Pane | grep -q "mouse_x" && tmux -L "$0" list-keys -T root | grep -F MouseDown3Pane | grep -q "pane_id"' "$SOCK"

# Capture the display-menu argv through a PATH shim: display-menu calls are
# logged, everything else is delegated to the real test server so the builder's
# option/state queries still work. TMUX stays unset (never the live server).
SHIMD="$FIXTURE_DIR/shim"; CAP="$FIXTURE_DIR/display-args"; mkdir -p "$SHIMD"
REAL_TMUX="$(command -v tmux)"
cat > "$SHIMD/tmux" <<SHIM
#!/usr/bin/env bash
if [ "\$1" = "display-menu" ]; then printf '%s\n' "\$@" > "$CAP"; exit 0; fi
exec "$REAL_TMUX" -L "$SOCK" "\$@"
SHIM
chmod +x "$SHIMD/tmux"

PATH="$SHIMD:$PATH" bash "$SHOW" mouse 12 34 %0 >/dev/null 2>&1
assert_true  "explicit coords reach display-menu (-x 12 -y 34)" \
	bash -c 'grep -qx -- "-x" "$0" && grep -qx "12" "$0" && grep -qx "34" "$0"' "$CAP"
assert_true  "clicked pane reaches display-menu (-t %0)" \
	bash -c 'grep -qx -- "-t" "$0" && grep -qx "%0" "$0"' "$CAP"

rm -f "$CAP"
PATH="$SHIMD:$PATH" bash "$SHOW" mouse >/dev/null 2>&1
assert_true  "missing coords degrade to -x M -y M (legacy fallback)" \
	bash -c 'grep -qx "M" "$0"' "$CAP"

# #{mouse_x}/#{mouse_y} are pane-relative; the final -x/-y must be translated
# back to client-absolute by the clicked pane's offsets (+ top status rows).
# A right-hand pane has pane_left > 0 — the discriminating case.
tmux -L "$SOCK" split-window -h
rp="$(tmux -L "$SOCK" list-panes -F '#{pane_left} #{pane_id}' | sort -rn | head -1)"
rp_left="${rp%% *}"; rp_id="${rp##* }"
rm -f "$CAP"
PATH="$SHIMD:$PATH" bash "$SHOW" mouse 12 34 "$rp_id" >/dev/null 2>&1
assert_true  "pane-relative x translated by pane_left (right pane)" \
	bash -c 'grep -qx "$1" "$0"' "$CAP" "$(( 12 + rp_left ))"
assert_true  "y unchanged with bottom status (pane_top 0)" \
	bash -c 'grep -qx "34" "$0"' "$CAP"

# Status at the TOP shifts the whole window down — y must gain the status rows.
tmux -L "$SOCK" set -g status-position top
rm -f "$CAP"
PATH="$SHIMD:$PATH" bash "$SHOW" mouse 12 34 "$rp_id" >/dev/null 2>&1
assert_true  "top status adds its rows to y (34 -> 35)" \
	bash -c 'grep -qx "35" "$0"' "$CAP"
tmux -L "$SOCK" set -g status-position bottom
tmux -L "$SOCK" kill-pane -t "$rp_id" 2>/dev/null

# Without an originating mouse event tmux flags the menu MENU_NOMOUSE and bare
# hover-motion (release-encoded) instantly closes it — `-M` (tmux 3.5+) forces
# mouse handling back on. Version-gated: a forced 3.4 must NOT emit -M.
rm -f "$CAP"
PATH="$SHIMD:$PATH" bash "$SHOW" mouse 12 34 %0 >/dev/null 2>&1
assert_true  "-M forced on (hover must not dismiss; tmux >= 3.5)" \
	bash -c 'grep -qx -- "-M" "$0"' "$CAP"
rm -f "$CAP"
CONTEXT_MENU_FORCE_VERSION=3.4 PATH="$SHIMD:$PATH" bash "$SHOW" mouse 12 34 %0 >/dev/null 2>&1
assert_false "-M omitted on tmux 3.4 (flag needs 3.5)" \
	bash -c 'grep -qx -- "-M" "$0"' "$CAP"

echo
if [ "$fail" -eq 0 ]; then
	echo "ALL TESTS PASSED"
else
	echo "SOME TESTS FAILED"
fi
exit "$fail"
