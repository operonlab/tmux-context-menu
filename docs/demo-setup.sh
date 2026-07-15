#!/bin/bash
# demo-setup.sh — self-contained stage for docs/demo.tape. Builds everything the
# recording needs and starts an ISOLATED tmux server (socket: cm-demo, own
# config) — your real tmux server and config are never touched.
#
# Anonymous by construction: a byte-exact Starship-clone prompt (user = "dev"),
# a staged sample project (so the prompt shows …/demo-app  main), and a cockpit
# theme that OWNS both status rows so nothing leaks the machine's hostname.
#
# FAMILY-CONSISTENT: the same two-row pill cockpit as the rest of the plugin
# family (catppuccin mocha, half-circle end-caps). Row 1 = session / window /
# cluster / weather-clock chrome; Row 2 left = staged CLAUDE/CODEX/GEMINI quota
# pills (demo chrome), Row 2 right = the NET/CPU/MEM/DISK capsule (demo chrome —
# context-menu has no continuous reader; its REAL behaviour, the on-demand menu,
# is shown live in the recording via the Ctrl+g stand-in below).
#
# vhs cannot synthesize a real mouse right-click or a Meta keypress, so the setup
# binds the SAME menu to Ctrl+g (@context-menu-key, a documented option); the menu
# contents are byte-identical to the default Alt+q / right-click entry points.
set -u
unset TMUX TMUX_PANE
SOCK=cm-demo
WORK=/tmp/vhs-context-menu-demo
PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMUX_BIN="${TMUX_BIN:-tmux}"

mkdir -p "$WORK"

# ── glyphs (byte escapes) + mocha palette ──
CAPL=$(printf '\xee\x82\xb6'); CAPR=$(printf '\xee\x82\xb4'); SEP=$(printf '\xee\x82\xb0')
I_TERM=$(printf '\xee\x9e\x95');   I_ROBOT=$(printf '\xf3\xb0\x9a\xa9')
I_PLAY=$(printf '\xef\x81\x8b');   I_PAUSE=$(printf '\xef\x81\x8c')
I_FLEET=$(printf '\xef\x84\x88');  I_CAL=$(printf '\xef\x86\xae')
I_THERMO=$(printf '\xef\x8b\x89'); I_CLOCK=$(printf '\xef\x80\x97')
I_NET=$(printf '\xef\x83\xac');    I_CPU=$(printf '\xf3\xb0\x93\x85')
I_MEM=$(printf '\xf3\xb0\x8d\x9b');I_DISK=$(printf '\xef\x82\xa0')
I_CLAUDE=$(printf '\xef\x81\xa9'); I_CODEX=$(printf '\xef\x84\xa1'); I_GEMINI=$(printf '\xef\x86\xa0')
BG='#1E1E1E'; CRUST='#11111b'; FG='#cdd6f4'; SURF='#313244'
PEACH='#fab387'; YELLOW='#f9e2af'; MAROON='#eba0ac'; LAVENDER='#b4befe'
MAUVE='#cba6f7'; PINK='#f5c2e7'; BLUE='#89b4fa'; SKY='#89dceb'
SAPPHIRE='#74c7ec'; TEAL='#94e2d5'; GREEN='#a6e3a1'; RED='#f38ba8'

p_open()  { printf '#[fg=%s,bg=%s]%s#[fg=%s,bg=%s]%s  ' "$1" "$BG" "$CAPL" "$CRUST" "$1" "$2"; }
p_text()  { printf '#[fg=%s,bg=%s] %s ' "$FG" "$SURF" "$1"; }
p_badge() { printf '#[fg=%s,bg=%s]%s#[fg=%s,bg=%s]%s ' "$1" "$SURF" "$CAPL" "$CRUST" "$1" "$2"; }
p_ibadge(){ printf '#[fg=%s,bg=%s]%s#[fg=%s,bg=%s]%s  ' "$1" "$SURF" "$CAPL" "$CRUST" "$1" "$2"; }
p_close() { printf '#[fg=%s,bg=%s]%s ' "$SURF" "$BG" "$CAPR"; }

# ── Row 1 pieces: session pill · window chips · cluster capsule · right pill ──
LEFT_R1="#[fg=$GREEN,bg=$BG]${CAPL}#[fg=$CRUST,bg=$GREEN]${I_TERM}  #[fg=$FG,bg=$SURF] #S #[fg=$SURF,bg=$BG]${CAPR} "
WINF="#[fg=$CRUST,bg=#9399b2]#[fg=$BG,reverse]${CAPL}#[none]#I #[fg=$FG,bg=$SURF] #W "
WINCUR="#[fg=$CRUST,bg=$PEACH]#[fg=$BG,reverse]${CAPL}#[none]#I #[fg=$FG,bg=#45475a] #W "
CLUSTER="#[fg=$MAUVE,bg=$BG]${CAPL}#[fg=$CRUST,bg=$MAUVE]${I_ROBOT}  #[fg=$FG,bg=$SURF] ${I_PLAY} 1  ${I_PAUSE} 8 #[fg=$SAPPHIRE,bg=$SURF]${CAPL}#[fg=$CRUST,bg=$SAPPHIRE]${I_FLEET}  #[fg=$FG,bg=$SURF] #[fg=$GREEN,bg=$SURF]M #[fg=$GREEN,bg=$SURF]W #[fg=$RED,bg=$SURF]A #[fg=$SURF,bg=$BG]${CAPR}"
RIGHT_R1="#[fg=$PINK,bg=$BG]${CAPL}#[fg=$CRUST,bg=$PINK]${I_CAL}  #[fg=$FG,bg=$SURF] #W #[fg=$SKY,bg=$SURF]${CAPL}#[fg=$CRUST,bg=$SKY]${I_THERMO}  #[fg=$FG,bg=$SURF] 🌤️ 29°C #[fg=$SAPPHIRE,bg=$SURF]${CAPL}#[fg=$CRUST,bg=$SAPPHIRE]${I_CLOCK}  #[fg=$FG,bg=$SURF] %Y/%m/%d %H:%M #[fg=$SURF,bg=$BG]${CAPR}"
FMT0="#[align=left bg=$BG]${LEFT_R1}#[list=on]#{W:#{T:@pw-fmt},#{T:@pw-cur}}#[nolist align=right]${RIGHT_R1}#[align=absolute-centre]${CLUSTER}"

# ── Row 2: quota trio (left) · net/cpu/mem/disk capsule (right), demo values ──
ROW2_L="$(p_open "$PEACH" "$I_CLAUDE")$(p_text CLAUDE)$(p_badge "$YELLOW" 5H)$(p_text 40%%)$(p_badge "$MAROON" 7D)$(p_text 61%%)$(p_close)$(p_open "$LAVENDER" "$I_CODEX")$(p_text CODEX)$(p_badge "$MAUVE" 5H)$(p_text 65%%)$(p_badge "$PINK" 7D)$(p_text 12%%)$(p_close)$(p_open "$BLUE" "$I_GEMINI")$(p_text GEMINI)$(p_badge "$SKY" 5H)$(p_text 8%%)$(p_badge "$SAPPHIRE" 7D)$(p_text 3%%)$(p_close)"
ROW2_R="$(p_open "$TEAL" "$I_NET")$(p_text '↓ 17K/s ↑ 30K/s')$(p_ibadge "$GREEN" "$I_CPU")$(p_text 34%%)$(p_ibadge "$YELLOW" "$I_MEM")$(p_text '16.7/24G 70%%')$(p_ibadge "$PEACH" "$I_DISK")$(p_text '261/460G 57%%')$(p_close)"
FMT1="#[align=left bg=$BG]${ROW2_L}#[align=right]${ROW2_R}"

# ── pane shell: byte-exact Starship clone (catppuccin_mocha), user = "dev" —
#    same segmented prompt as the rest of the plugin family ──
cat > "$WORK/rc.sh" <<'RC'
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export LANG=en_US.UTF-8
_SEP=$(printf '\xee\x82\xb0'); _CAPL=$(printf '\xee\x82\xb6'); _CAPR=$(printf '\xee\x82\xb4')
_APPLE=$(printf '\xef\x85\xb9'); _BRANCH=$(printf '\xef\x90\x98')
_CLOCKG=$(printf '\xef\x90\xba'); _ARROW=$(printf '\xef\x90\xb2')
_SURF0='49;50;68'; _PEACH='250;179;135'; _GREEN='166;227;161'; _TEAL='148;226;213'
_BLUE='137;180;250'; _PINK='245;194;231'; _TEXT='205;214;244'; _MANTLE='24;24;37'; _BASE='30;30;46'
_p10line() {
  local b git=""
  if b=$(git branch --show-current 2>/dev/null) && [ -n "$b" ]; then
    git=$(printf '\033[38;2;%s;48;2;%sm %s %s ' "$_BASE" "$_GREEN" "$_BRANCH" "$b")
  fi
  printf '\033[38;2;%sm%s\033[38;2;%s;48;2;%sm%s dev \033[38;2;%s;48;2;%sm%s\033[38;2;%s;48;2;%sm …/%s \033[38;2;%s;48;2;%sm%s%s\033[38;2;%s;48;2;%sm%s\033[38;2;%s;48;2;%sm%s\033[38;2;%s;48;2;%sm%s\033[38;2;%s;48;2;%sm %s %s \033[0m\033[38;2;%sm%s\033[0m \n' \
    "$_SURF0" "$_CAPL" "$_TEXT" "$_SURF0" "$_APPLE" "$_SURF0" "$_PEACH" "$_SEP" \
    "$_MANTLE" "$_PEACH" "${PWD##*/}" "$_PEACH" "$_GREEN" "$_SEP" "$git" \
    "$_GREEN" "$_TEAL" "$_SEP" "$_TEAL" "$_BLUE" "$_SEP" "$_BLUE" "$_PINK" "$_SEP" \
    "$_MANTLE" "$_PINK" "$_CLOCKG" "$(date '+%I:%M %p')" "$_PINK" "$_CAPR"
}
PROMPT_COMMAND=_p10line
PS1='\[\033[1;38;2;166;227;161m\]'"$_ARROW"'\[\033[0m\] '
RC

# ── staged sample project so the Starship prompt shows a …/path + branch pill ──
APP="$WORK/demo-app"
rm -rf "$APP"; mkdir -p "$APP/src"
printf '# demo-app\n\nA tiny sample project.\n' > "$APP/README.md"
printf 'flask\npytest\n' > "$APP/requirements.txt"
printf '"""demo-app."""\n' > "$APP/src/app.py"
git -C "$APP" init -q -b main
git -C "$APP" -c user.name=dev -c user.email=dev@example.com add -A
git -C "$APP" -c user.name=dev -c user.email=dev@example.com commit -qm "initial commit"

# ── base theme (static parts; the format rows are set after server start) ──
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
set -g status-left-length 30
set -g status-right-length 200
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

# ── isolated server: a single working pane in the sample project. window 0 runs
#    the clean shell EXPLICITLY (a session's first window is created before
#    default-command applies — classic prompt leak) ──
"$TMUX_BIN" -L "$SOCK" kill-server 2>/dev/null
sleep 0.3
"$TMUX_BIN" -L "$SOCK" -f "$WORK/theme.conf" new-session -d -s demo -x 118 -y 30 -n main -c "$APP" "bash --rcfile $WORK/rc.sh -i"
"$TMUX_BIN" -L "$SOCK" set -g default-command "bash --rcfile $WORK/rc.sh -i"

# cockpit rows (composed above with byte-escape glyphs)
"$TMUX_BIN" -L "$SOCK" set -g @pw-fmt "$WINF"
"$TMUX_BIN" -L "$SOCK" set -g @pw-cur "$WINCUR"
"$TMUX_BIN" -L "$SOCK" set -g 'status-format[0]' "$FMT0"
"$TMUX_BIN" -L "$SOCK" set -g 'status-format[1]' "$FMT1"

# ── vhs stand-in trigger: bind the SAME menu to Ctrl+g (documented option) ──
"$TMUX_BIN" -L "$SOCK" set -g @context-menu-key C-g

# ── load the plugin (binds right-click + Ctrl+g to the menu) ──
"$TMUX_BIN" -L "$SOCK" run-shell "$PLUGIN/context-menu.tmux"
