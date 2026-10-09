# 修改记录

每项修改记录：**做了什么、为什么、改了哪些文件、怎么验证、要注意什么**。
以后改设置时，在最上面新增一节；顺序是新的在上。

环境基准：Omarchy（Hyprland 0.56.2，Lua 配置）、Quickshell 版 Omarchy Shell、Shibumi 顶栏。

---

## 2026-10-10 鼠标移过窗口不再自动聚焦

- **问题**：鼠标移到某些窗口上就会直接聚焦，不像 Win11 那样要点击或 Alt+Tab。
- **原因**：`follow_mouse = 2`（点击才聚焦）本来就开着，但 Hyprland 另有 `float_switch_override_focus`，
  默认值 1：鼠标在**浮动**与**平铺**窗口之间移动时会自动换焦点。大部分窗口是浮动的，只要有一个平铺窗口
  （例如按过 `Super+W` 的 Chromium），鼠标经过就会抢焦点。
- **修改**：`hypr/input.lua` 加上 `float_switch_override_focus = 0`。
- **验证**：两个浮动测试窗口加一个平铺窗口，鼠标依序移过三者，焦点始终停在原窗口。
  （点击聚焦无法用脚本模拟，靠手动确认。）

## 2026-10-10 打包成仓库、拆出本机专属设置

- **做了什么**：建立本仓库，`install.sh` 一键还原、`sync.sh` 收集本机设置，同步清单在 `manifest.sh`。
- **拆出 `~/.config/hypr/local.lua`（不入库）**，原本混在共用设置里的机器专属内容移到这里：
  - GIGABYTE AERO 15：`Super+Ctrl+code:202` 触控板开关（原在 `bindings.lua`）
  - GIGABYTE AERO 15：`aero-fnkeys` 开机启动，Fn+F3/F4 亮度、Fn+ESC 游戏模式（原在 `autostart.lua`）
  - `LIBVA_DRIVER_NAME=iHD`：Intel 内显解码影片（原在 `hyprland.lua`）

  `hyprland.lua` 在 `default.hypr.toggles` 之后用 `dofile` 载入它，文件不存在时自动略过。
- **刻意不入库**：`monitors.lua`、`hyprmoncfg-monitors.lua`（显示器跟机器走）、`local.lua`、`*.bak*`、`*.save*`。
- **验证**：把 `install.sh` 装到临时的 `XDG_CONFIG_HOME`，与本机逐档比对：hypr 7 档、omarchy 4 档、
  插件 39 个全部一致，Dock patch 也有套上。hyprbars 安装段（要 sudo）未实测。

## 2026-10-10 Dock：一律隐藏，鼠标靠近才显示

- **需求**：Dock 平时隐藏，鼠标移到屏幕底边才弹出；不论窗口什么状态都一样；底部不预留空间。
- **修改**：
  - `omarchy/dock-settings.json`：`visibilityMode: "hover"`、`overlayMode: true`（浮在窗口上，不占底部空间）。
  - **插件修改** `rosakodu.dock/DockSettings.js`（`shouldSlideOut`）：原版 hover 模式在
    「工作区没有窗口」时会一直显示 Dock，没有设定可关，改成只看鼠标是否在 Dock 上。
    存成 `plugins/patches/rosakodu.dock.patch`。
- **注意**：
  - 改了插件里的 `.pragma library` JS，`omarchy plugin disable/enable` **不会**重新载入，
    要 `omarchy-restart-shell` 才生效（曾因此误以为修改无效）。
  - `omarchy plugin update` 会把修改洗掉 → 执行 `./install.sh` 重新套用。
- **验证**：有窗口的工作区、空工作区都隐藏；鼠标到底边显示；离开约 1.5 秒后隐藏。

## 2026-10-10 最小化区（special:minimized）的两个 bug

- **现象**：Dock 一直不隐藏；窗口看得到，但切换工作区后就消失。
- **原因**：最小化 = 把窗口移到 `special:minimized` 工作区。
  1. Hyprland 把窗口移进 special 工作区时会**顺便打开它**（像一层盖在画面上）。
     `snap.sh` 最小化后没有关回去 → 之后的窗口都「住」在打开的最小化区里，真正的工作区是空的。
  2. Hyprland 0.56 的 `hl.dsp.workspace.toggle_special(...)` **必须传字符串**：`toggle_special("minimized")`。
     传表格 `toggle_special({ workspace = "minimized" })` 参数会被忽略，变成打开默认的空 `special:special`，
     新窗口也会开进去。Dock 插件原版就是这样写的。
- **修改**：
  - `hypr/scripts/snap.sh`：最小化后把打开的 special 工作区关回去（用字符串参数）。
  - **插件修改** `rosakodu.dock/scripts/dock-minimize.py` 的 `close_any_special`：改用字符串参数。
    （与上面的 Dock 修改同在 `plugins/patches/rosakodu.dock.patch`）
- **验证**：`Win+↓` 最小化、Dock 点击还原、Dock 右键最小化三条路径，事后 special 都是关着的。
- **未解**：窗口偶尔仍会停在「打开的最小化区」里，成因还没查明。排查方法：用 Hyprland 的
  `.socket2.sock` 事件记录 `movewindow` / `activespecial` 的时间点，对照当时的操作。

## 2026-10-10 Win11 风格标题栏（hyprbars）

- **需求**：每个窗口有标题栏，右侧是 最小化 / 最大化-还原 / 关闭。
- **安装**：Hyprland 官方插件 `hyprbars`，由 `hyprpm` 编译（需要 `cmake meson ninja` 与 sudo）。
  记录在 `hyprpm.tsv`，`install.sh` 会自动装。
- **修改**：`hypr/titlebars.lua`（由 `hyprland.lua` 载入）
  - 设定时直接 `hl.plugin.load` hyprpm 编译好的 `.so`，所以开机不用另外跑 `hyprpm reload`；
    没装或版本不符时整段略过，不影响其他设定。
  - Lua 接口：`hl.plugin.hyprbars.add_button({ bg_color, fg_color, size, icon, action })`，
    `action` 是 shell 指令；**先加入的按钮排在最右边**。
  - 按钮动作：关闭 = `hl.dsp.window.close()`；最大化 = `snap.sh toggle-max`；最小化 = `snap.sh minimize`。
  - 双击标题栏 = 最大化/还原（`on_double_click`）。
- **注意**：Hyprland 更新后标题栏消失 → `hyprpm update` 重新编译。

## 2026-10-10 标题栏不压到 Shibumi 顶栏

- **原因**：hyprbars 标题栏画在窗口**外面上方**，不算在窗口尺寸里；`snap.sh` 只把窗口内容对齐到
  顶栏保留区下方，标题栏（30px）就压到 Shibumi 上。
- **修改**：`snap.sh` 读取 `plugin:hyprbars:bar_height`，贴靠位置往下移、高度减少同样的值
  （没装插件时为 0）。上下两格 1/4 之间也会留出下面那格的标题栏。
- **未处理**：用鼠标把窗口拖到最上缘时，标题栏仍可能被盖住。

## 2026-10-10 新窗口默认浮动、焦点窗口提到最上层

- **修改**：`hypr/hyprland.lua`
  - `o.window(".*", { float = true })`：所有新窗口默认浮动（`Super+W` 切回平铺）。
  - `hl.on("window.active", ...)`：窗口取得焦点时 `alter_zorder top`。
    Alt+Tab、点击、Dock 还原都会把窗口提到最上层（原本 Alt+Tab 切到被盖住的窗口，它仍在下面）。
- **验证**：两个窗口交替聚焦，`hl.get_windows()` 的顺序跟着翻转。

## 2026-10-10 Win+方向键贴靠（半屏、1/4 屏、最大化、还原、最小化）

- **修改**：`hypr/scripts/snap.sh`（`bindings.lua` 绑在 `Super+方向键`）

  | 目前状态 | ← | → | ↑ | ↓ |
  |---|---|---|---|---|
  | 普通窗口 | 左半 | 右半 | 最大化 | 最小化到 Dock |
  | 左半 | — | 还原 | 左上 1/4 | 左下 1/4 |
  | 右半 | 还原 | — | 右上 1/4 | 右下 1/4 |
  | 左上 1/4 | — | 右上 1/4 | — | 左半 |
  | 右上 1/4 | 左上 1/4 | — | — | 右半 |
  | 左下 1/4 | — | 右下 1/4 | 左半 | — |
  | 右下 1/4 | 左下 1/4 | — | 右半 | — |
  | 最大化 | 左半 | 右半 | — | 还原 |

  - 「还原」回到贴靠前的位置与大小（记录在 `$XDG_RUNTIME_DIR/hypr-snap/<窗口地址>`），没有记录时置中 60%×70%。
  - 目前状态靠「窗口位置与各贴靠位置相差 ≤ 8px」判断。
  - 另有给标题栏用的 `toggle-max`、`minimize`。
- **待确认**：左上 1/4 按 ↓ 回左半（Win11 实际行为未查证，依使用习惯可改 `case` 表）。
- **原本的「同方向按两次变回平铺」已拿掉**（默认浮动后用不到）。

## 2026-10-10 之前就有的自订（打包时一并收录）

- `bindings.lua`：`Super+Q` 关闭窗口、`Super+W` 浮动/平铺切换、`Super+Shift+S` 截图、
  `Alt+Tab` 用 `vbrosseau.alttab` 插件。
- `input.lua`：`compose:caps`、`follow_mouse = 2`（点击才聚焦）。
- `looknfeel.lua`：透明度 0.9、圆角 15、非焦点变暗、间距等外观。
- `hyprland.lua`：VRChat 全屏规则、Omaland 管理的不透明度区块。

---

## 维护须知

- **改完设置**：`./sync.sh` 看变动 → 在本文件最上面补一节 → `./sync.sh --push`。
- **新增要同步的文件**：加进 `manifest.sh`。机器专属的东西写进 `~/.config/hypr/local.lua`，不要进仓库。
- **改第三方插件**：直接改插件目录里的文件，`sync.sh` 会自动存成 `plugins/patches/<id>.patch`。
  在本文件写清楚改了什么、为什么，上游更新后 patch 套不上时才知道怎么重做。
- **测试 install.sh 不想动到本机**：
  `XDG_CONFIG_HOME=/tmp/x/config XDG_STATE_HOME=/tmp/x/state ./install.sh --no-hyprbars`
  （会重启 shell；可在 PATH 前面放一个空的 `omarchy-restart-shell` 挡掉），再与本机 `diff -r`。
- **备份**：`install.sh` 覆盖前的旧档在 `~/.local/state/omarchy-desktop/backup-<时间>/`。
