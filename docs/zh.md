# tmux-context-menu（繁體中文說明）

**在 tmux 的畫面上按滑鼠右鍵，就會在游標位置跳出一個小選單** —— 分割、放大、
關閉、改名、切換 session，全部一鍵完成。不用背任何快捷鍵組合。習慣用鍵盤的人，
同一份選單也可以用熱鍵打開（預設 `Alt+q`）。

![tmux-context-menu 在畫面上彈出的右鍵選單：水平／垂直分割、放大、關閉 pane／window、改名、切換 session，以及偵測到才出現的 Lazygit、Yazi 彈窗項目](docs/screenshot.png)

*一個按鍵（或右鍵）就叫得出來：整份選單就在你操作的位置彈出，不用背 prefix。*

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
| `@context-menu-source` | `''`（空） | 指向一個「印出整份選單」的檔案（每列一筆記錄），用它**取代**內建清單（`@context-menu-extra` 仍會接在後面附加）。插件載入時讀取並**執行**一次，編譯進綁定——改檔後 `prefix`+`r` 重載生效。詳見下方「單一來源選單項目」，包含 ⚠️ 警告：這個選項會**執行該檔案**。 |

### 自訂選單項目（`@context-menu-extra`）

> ⚠️ **這個選項會執行你填入的指令。** 只在你自己掌控、信任的 `~/.tmux.conf`
> 裡設定。不要貼上來路不明的內容 —— 你寫的東西會在點選單項目時被 tmux 執行。

格式：`標籤|按鍵|指令`，多個項目用 `;` 分隔。

```tmux
set -g @context-menu-extra "Htop|H|display-popup -E htop ; 重新載入|Q|source-file ~/.tmux.conf"
```

這會在選單底部多出兩列：一列用彈出視窗開 `htop`（按 `H`），一列重新載入
tmux 設定（按 `Q`）。

### 單一來源選單項目（`@context-menu-source`）

`@context-menu-extra` 只是**附加**幾列；`@context-menu-source` 更進一步，讓
**一個檔案定義整份核心選單**，取代內建清單。把選項指到那個檔案：

```tmux
set -g @context-menu-source '~/.tmux/menu-items.sh'
```

> ⚠️ **這個選項會執行該檔案。** 插件載入時會執行這個檔案並解析它的
> 輸出；每一項的 `when` 條件（見下）會透過 `sh -c` 執行。信任模型與
> `@context-menu-extra` 相同 —— 只指向你自己撰寫、掌控的檔案，絕不要用來路
> 不明的檔案。

**取代 vs 附加。** 當 `@context-menu-source` 有設定且檔案可讀時，它的記錄會成為
整份核心選單（內建的 分割／放大／關閉／… 清單就不再使用）。`@context-menu-extra`
仍會在之後執行，所以它的項目會附加在你來源清單的最下方。不設定
`@context-menu-source` 就什麼都不變，內建選單行為完全一如既往。

**記錄格式。** 檔案每列印出一筆記錄，欄位以 ASCII **單元分隔符** 位元組 `0x1F`
串接 —— **不是** tab 或空白。這很關鍵：tab 與空白都是空白字元，shell 的 `read`
會把連續空白摺疊、並丟掉中間的空欄位，於是空的 `when`／`minver` 會讓 `desc`
滑到錯誤的欄位。`0x1F` 是非空白字元、也不會出現在真實文字裡，所以空欄位能保住
位置。檔案維持以換行結尾、方便 `grep`。

一筆 **item** 記錄剛好有七個欄位：

```
type␟label␟key␟command␟when␟minver␟desc        （␟ = 0x1F 位元組）
```

| 欄位 | 意義 |
|---|---|
| `type` | 固定字串 `item`。 |
| `label` | 選單標籤。可含 tmux `#{...}` 格式條件式 —— 原封不動交給 `display-menu`，由 tmux 在繪製當下即時求值。 |
| `key` | 助憶鍵（單一字元或按鍵字串）。 |
| `command` | 點選時執行的 tmux 指令，就照 `display-menu` 需要的樣子（用一般的單引號 shell 引用撰寫）。 |
| `when` | *（選用）* shell 條件，透過 `sh -c` 執行。非零結束 → 建立選單時略過該項。留空 → 一律納入。 |
| `minver` | *（選用）* 最低 tmux `主.次` 版本。執行中的 tmux 較舊就略過該項。留空 → 不做版本閘。 |
| `desc` | *（選用）* 人類看的速查文字；選單本身會忽略它。 |

只有一個欄位、內容為 `sep` 的列會繪成分隔線。空白列、以 `#` 開頭的列、以及
缺少 label 或 key 的項目都會被略過。

檔案開頭放兩個小工具最好寫：

```sh
US=$(printf '\037')
item() { printf '%s%s%s%s%s%s%s%s%s%s%s%s%s\n' item "$US" "$1" "$US" "$2" "$US" "$3" "$US" "${4-}" "$US" "${5-}" "$US" "${6-}"; }
sep()  { printf 'sep\n'; }

# 用法：item <label> <key> <command> [when] [minver] [desc] ; sep
item 'Kill Pane' x 'kill-pane' '' '' '關閉窗格'
item '#{?window_zoomed_flag,Unzoom,Zoom}' z 'resize-pane -Z' '' '' '縮放 / 取消縮放'
item 'Customize Options' c 'customize-mode -Z' '' '3.2' '需要 tmux 3.2'
sep
```

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

<!-- family-section -->
---

## [operonlab](https://github.com/operonlab) tmux 外掛家族

一組小而專注的外掛，能組合成同一個駕駛艙。上面是原生 tmux **之前**，下面是整個家族 **之後**：

![原生 tmux 對比 operonlab tmux 駕駛艙](family-before-after.gif)

想用哪個就裝哪個：

| 外掛 | 加了什麼 |
|------|----------|
| [tmux-workdesk](https://github.com/operonlab/tmux-workdesk) | 一鍵 IDE ＋ tile/main 窗格佈局 |
| [tmux-floatpane](https://github.com/operonlab/tmux-floatpane) | 彈出式浮動暫存終端機 |
| **tmux-context-menu　—— 你在這** | 右鍵／prefix 窗格動作選單 |
| [tmux-autosize](https://github.com/operonlab/tmux-autosize) | 背景視窗自動貼合用戶端尺寸 |
| [tmux-passthrough](https://github.com/operonlab/tmux-passthrough) | 把按鍵直接穿透給內層程式 |
| [tmux-sysmon](https://github.com/operonlab/tmux-sysmon) | 即時 CPU／MEM／DISK／NET 膠囊 |
| [tmux-llm-usage](https://github.com/operonlab/tmux-llm-usage) | LLM 配額／花費狀態膠囊 |
| [tmux-agent-status](https://github.com/operonlab/tmux-agent-status) | AI 窗格 busy／blocked／idle 膠囊 |
| [tmux-pillbar](https://github.com/operonlab/tmux-pillbar) | 打造第二列自訂 pill 狀態列 |
| [tmux-agent-resume](https://github.com/operonlab/tmux-agent-resume) | 崩潰後把每個 AI CLI 還原到原 session |
