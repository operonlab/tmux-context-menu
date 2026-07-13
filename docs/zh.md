# tmux-context-menu（繁體中文說明）

**在 tmux 的畫面上按滑鼠右鍵，就會在游標位置跳出一個小選單** —— 分割、放大、
關閉、改名、切換 session，全部一鍵完成。不用背任何快捷鍵組合。習慣用鍵盤的人，
同一份選單也可以用熱鍵打開（預設 `Alt+q`）。

---

## 這是什麼？

平常 tmux 的功能都藏在「prefix」按鍵組合後面，不好記。這個外掛把最常用的動作
搬到**滑鼠右鍵**：點一下、選一項、完成。選單會在你點擊的位置彈出，用起來就像
一般桌面軟體的右鍵選單一樣自然。

核心選單只使用 tmux 內建的指令；選配項目（lazygit/yazi 彈窗、`@context-menu-extra`
自訂項）則會執行外部程式。如果你剛好裝了
[lazygit](https://github.com/jesseduffield/lazygit) 或
[yazi](https://github.com/sxyazi/yazi)，選單會**自動**多出對應的彈出視窗項目
（偵測得到才會出現）。

---

## 快速安裝

你需要 tmux（3.3a 版或更新，用 `tmux -V` 查看）。

**第一步：打開 tmux 的滑鼠模式。** 正式發行的 tmux 預設是關閉的，滑鼠模式沒開，
右鍵就叫不出選單。在 `~/.tmux.conf` 加上這一行：

```tmux
set -g mouse on
```

（鍵盤熱鍵 —— 預設 `Alt+q` —— 沒開滑鼠模式也能用，但招牌的右鍵選單需要它。）

### 有用 TPM（tmux 外掛管理器）

還沒裝 TPM 的話，這一行就能裝好：

```sh
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

接著在 `~/.tmux.conf` 靠近底部加上這兩行（但 `run '~/.tmux/plugins/tpm/tpm'`
這行必須放在最後）：

```tmux
set -g @plugin 'operonlab/tmux-context-menu'
run '~/.tmux/plugins/tpm/tpm'
```

最後重新載入 tmux，按你的 prefix 鍵（通常是 `Ctrl+b`），再按大寫 `I` 安裝。
完成後，對著任何畫面按右鍵試試。

### 沒有用 TPM

把這個 repo clone 到任何地方，然後在 `~/.tmux.conf` 加**一行**：

```sh
git clone https://github.com/operonlab/tmux-context-menu ~/.tmux/plugins/tmux-context-menu
```

```tmux
run-shell '~/.tmux/plugins/tmux-context-menu/context-menu.tmux'
```

重新載入設定（`tmux source-file ~/.tmux.conf`），然後右鍵點畫面即可。

---

## 選項

在 `~/.tmux.conf` 裡、`run` / `run-shell` 那行的**上方**用 `set -g` 設定。全部
都可省略，預設值已經很合理。

| 選項 | 預設 | 白話說明 |
|---|---|---|
| `@context-menu-mouse` | `on` | 開關右鍵選單。設 `off` 只保留鍵盤熱鍵。 |
| `@context-menu-key` | `M-q` | 打開同一份選單的鍵盤快捷鍵。設成 `''`（空字串）可關掉熱鍵。例：`set -g @context-menu-key 'M-e'`。 |
| `@context-menu-disable-status-clicks` | `on` | 停用狀態列（底部彩色列）的右鍵選單，避免誤觸。 |
| `@context-menu-mouse-copy` | `off` | 加入「雙擊選字、三擊選行、複製且畫面不跳走」。因為會改變點擊行為，所以預設關閉。 |
| `@context-menu-copy-command` | `''`（空） | 只在 `@context-menu-mouse-copy` 為 `on` 時有用。留空＝複製到 tmux 自己的剪貼簿；填指令（例：macOS 用 `pbcopy`、Linux 用 `xclip -sel clip`）就會同時複製到系統剪貼簿。 |
| `@context-menu-extra` | `''`（空） | 自訂選單項目，請先看下面的警告。 |

### 自訂選單項目（`@context-menu-extra`）

> ⚠️ **這個選項會執行你填入的指令。** 只在你自己掌控、信任的 `~/.tmux.conf`
> 裡設定。不要貼上來路不明的內容 —— 你寫的東西會在點選單項目時被 tmux 執行。

格式：`標籤|按鍵|指令`，多個項目用 `;` 分隔。

```tmux
set -g @context-menu-extra "Htop|H|display-popup -E htop ; 重新載入|Q|source-file ~/.tmux.conf"
```

這會在選單底部多出兩列：一列用彈出視窗開 `htop`（按 `H`），一列重新載入
tmux 設定（按 `Q`）。

---

## 移除

從**執行中**的 tmux 移除這個外掛加入的所有綁定與選項（不用重開）：

```sh
tmux run-shell '~/.tmux/plugins/tmux-context-menu/scripts/teardown.sh'
```

然後把你加進 `~/.tmux.conf` 的那幾行刪掉（有用 TPM 的話也刪 `@plugin` 那行）。

---

## 常見問題

**右鍵沒反應？**
tmux 的滑鼠支援要先打開。在 `~/.tmux.conf` 加 `set -g mouse on` 再重新載入。
（也可以用鍵盤熱鍵打開選單，選「Mouse ON」。）

**`Alt+q` 熱鍵沒作用？**
有些終端機會把 `Alt` 當成「跳脫（escape）」前綴，或已經佔用 `Alt+q`。改用別的
鍵：`set -g @context-menu-key 'M-e'`，重新載入再試。設成 `''` 可完全關閉熱鍵。

**移除後，狀態列右鍵或拖曳複製怪怪的？**
`teardown.sh` 只會移除本外掛加入的東西，tmux 沒有「還原成上一個綁定」的功能。
凡是本外掛蓋掉的 tmux 內建行為（狀態列右鍵、複製模組開啟時的拖曳複製），移除後
不會自動還原。重新載入設定或重啟 tmux server（`tmux kill-server`）即可恢復
tmux 預設。

**Lazygit / Yazi 沒出現在選單裡？**
只有外掛載入時在 `PATH` 找得到 `lazygit` / `yazi` 指令，項目才會出現。裝好它們
（或修正 `PATH`）後重新載入 tmux。

**雙擊選字沒作用？**
那是可選的複製模組，預設關閉。用 `set -g @context-menu-mouse-copy on` 打開後
重新載入即可。
