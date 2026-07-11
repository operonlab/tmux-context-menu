#!/usr/bin/env bash
# shellcheck shell=bash
#
# tmux-context-menu — TPM entry point.
#
# TPM (and the "no TPM" run-shell one-liner) execute this file on tmux start.
# It resolves its own location and hands off to the builder, which reads the
# @context-menu-* options and binds the menu.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$CURRENT_DIR/scripts/build-menu.sh"
