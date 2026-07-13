#!/bin/bash
# demo-setup.sh — self-contained stage for docs/demo.tape. Builds everything the
# recording needs and starts an ISOLATED tmux server (socket: cm-demo, own
# config) — your real tmux server and config are never touched.
# Anonymous by construction: staged sample project, identity-free prompt, no
# hostname in the status line or pane borders.
#
# vhs cannot synthesize a real mouse right-click or a Meta keypress, so the setup
# binds the SAME menu to Ctrl+g (@context-menu-key, a documented option); the menu
# contents are byte-identical to the default Alt+q / right-click entry points.
set -u
SOCK=cm-demo
WORK=/tmp/vhs-context-menu-demo
APP=/tmp/demo-app
PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMUX_BIN="${TMUX_BIN:-tmux}"

mkdir -p "$WORK"

# ── clean, anonymous shell for every pane ──
cat > "$WORK/rc.sh" <<'RC'
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export LANG=en_US.UTF-8
PS1='\[\e[38;2;166;227;161m\] dev \[\e[38;2;137;180;250m\]\W\[\e[0m\] ❯ '
PROMPT_COMMAND=
RC

# ── the intro banner painted in the working pane ──
cat > "$WORK/scene.sh" <<'SCENE'
export PATH="/opt/homebrew/bin:/usr/bin:/bin"
clear
printf '\n   \033[38;2;203;166;247mtmux-context-menu\033[0m\n\n'
printf '   Right-click any pane — or press  \033[1mAlt+q\033[0m  — and a menu pops up\n'
printf '   right where you are.\n\n'
printf '   \033[2mSplit · zoom · kill · rename · jump between sessions.  No prefix keys.\033[0m\n\n'
SCENE

# ── staged sample project (so the prompt sits in a real project dir) ──
rm -rf "$APP"; mkdir -p "$APP/src"
printf '# demo-app\n\nA tiny sample project.\n' > "$APP/README.md"
printf '"""demo-app."""\n' > "$APP/src/app.py"
git -C "$APP" init -q -b main
git -C "$APP" -c user.name=dev -c user.email=dev@example.com add -A
git -C "$APP" -c user.name=dev -c user.email=dev@example.com commit -qm "initial commit"

# ── cockpit-style theme (catppuccin mocha, hardcoded, portable) ──
cat > "$WORK/theme.conf" <<'CONF'
set -g default-terminal "tmux-256color"
set -as terminal-overrides ",xterm-256color:Tc"
set -g mouse on
setw -g mode-keys vi
setw -g automatic-rename off
set -g escape-time 0
set -g status 2
set -g status-interval 2
set -g status-style "bg=#1E1E1E,fg=#cdd6f4"
set -g status-left '#[fg=#a6e3a1,bg=#1E1E1E]#[fg=#11111b,bg=#a6e3a1]  #[fg=#cdd6f4,bg=#313244] #S #[fg=#313244,bg=#1E1E1E] '
set -g status-left-length 30
set -g status-right '#[fg=#f5c2e7,bg=#1E1E1E]#[fg=#11111b,bg=#f5c2e7]  #[fg=#cdd6f4,bg=#313244] #W #[fg=#89dceb,bg=#313244]#[fg=#11111b,bg=#89dceb]  #[fg=#cdd6f4,bg=#313244] %H:%M #[fg=#313244,bg=#1E1E1E]'
set -g status-right-length 120
set -g 'status-format[1]' '#[align=left]#(cat /tmp/vhs-demo-row2-left 2>/dev/null)#[align=right]#(cat /tmp/vhs-demo-row2-right 2>/dev/null)'
set -g window-status-format '#[fg=#6c7086] #I:#W '
set -g window-status-current-format '#[fg=#89b4fa,bold] #I:#W '
set -g window-status-separator ''
set -g pane-border-status top
set -g pane-border-format '#[align=centre]#{?pane_active,#[reverse],} #{pane_index}: #{pane_current_command} #[default]'
set -g pane-border-style 'fg=#45475a'
set -g pane-active-border-style 'fg=#fab387,bold'
set -g message-style 'bg=#f9e2af,fg=#11111b,bold'
set -g menu-style 'bg=#313244,fg=#cdd6f4'
set -g menu-selected-style 'bg=#89b4fa,fg=#11111b,bold'
set -g menu-border-style 'fg=#89b4fa'
CONF

# ── ambient row-2 pills (static demo values, honest set dressing) ──
pill() { printf '#[fg=%s,bg=#1E1E1E]\xee\x82\xb6#[fg=#11111b,bg=%s]%s #[fg=#cdd6f4,bg=#313244] %s #[fg=#313244,bg=#1E1E1E]\xee\x82\xb4 ' "$1" "$1" "$2" "$3"; }
{ pill '#f5c2e7' '' 'AI 5H 40%'; pill '#89b4fa' '' 'CX 5H 65%'; } > /tmp/vhs-demo-row2-left
{ pill '#a6e3a1' '' 'CPU 34%'; pill '#f9e2af' '' 'MEM 16.7/24G'; pill '#94e2d5' '' '↓17K ↑30K'; } > /tmp/vhs-demo-row2-right

# ── isolated server: a single working pane in the sample project ──
"$TMUX_BIN" -L "$SOCK" kill-server 2>/dev/null
sleep 0.3
"$TMUX_BIN" -L "$SOCK" -f "$WORK/theme.conf" new-session -d -s demo -x 118 -y 30 -n main -c "$APP" "bash --rcfile $WORK/rc.sh -i"
"$TMUX_BIN" -L "$SOCK" set -g default-command "bash --rcfile $WORK/rc.sh -i"

# ── vhs stand-in trigger: bind the SAME menu to Ctrl+g (documented option) ──
"$TMUX_BIN" -L "$SOCK" set -g @context-menu-key C-g

# ── load the plugin (binds right-click + Ctrl+g to the menu) ──
"$TMUX_BIN" -L "$SOCK" run-shell "$PLUGIN/context-menu.tmux"

# ── paint the intro banner ──
"$TMUX_BIN" -L "$SOCK" send-keys -t demo:main "bash $WORK/scene.sh" Enter
