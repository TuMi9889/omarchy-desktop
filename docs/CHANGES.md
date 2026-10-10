# 修改记录

每项修改记录：**做了什么、为什么、改了哪些文件、怎么验证、要注意什么**。
以后改设置时，在最上面新增一节；顺序是新的在上。

环境基准：Omarchy（Hyprland 0.56.2，Lua 配置）、Quickshell 版 Omarchy Shell、Shibumi 顶栏。

---

## 2026-10-10 修复：重开机登入后黑屏（hyprbars 载入造成无限重载）

- **问题**：重开机输入密码后整个画面黑屏、没有游标，只能进 TTY。
- **原因**：`titlebars.lua` 在配置里直接 `hl.plugin.load` hyprbars。冷启动时载入插件会触发配置重载，
  重载时插件还没挂上又再载入 → `reload()`↔`handlePluginLoads()` 无限递归（gdb 主线程栈实测），
  Hyprland 卡死、CPU 满载，30 秒后被 uwsm/systemd 超时杀掉。执行中 reload 不会触发，所以之前没发现。
- **修改**：改成启动完成后才载入：`o.exec_on_start("hyprctl plugin load <so> && hyprctl reload")`。
- **文件**：`hypr/titlebars.lua`
- **验证**：TTY 下实际启动 Hyprland：`hyprctl monitors` 正常、`hyprctl plugin list` 有 hyprbars、`configerrors` 为空。
- **注意**：不要在 Lua 配置里直接 `hl.plugin.load`。

---

## 2026-10-10 单按 Super 开选单：排除 Super+鼠标操作

- **问题**：Super+左键拖动窗口、Super+右键调整大小后，放开 Super 会打开选单。
- **原因**：判断只看键盘事件；Hyprland 0.56 的 Lua **没有鼠标按键事件**（只有 `input.keyboard.key`），
  鼠标操作不会被标记为组合键。
- **修改**：`hypr/bindings.lua` 另绑 `SUPER + mouse:272`、`SUPER + mouse:273`，回调为 Lua 函数、
  `{ non_consuming = true }`：只在 Super 按住期间做「组合」标记，点击照常交给 Omarchy 原本的
  拖动（`hl.dsp.window.drag`）/调整大小（`hl.dsp.window.resize`）绑定。
- **曾试过、被使用者否决**：以「按住 Super 期间鼠标移动 > 8px」判断。太粗糙——边移动鼠标边点 Super 会开不了选单。
- **验证**：逻辑以 `_G.omarchy_super_tap` / `_G.omarchy_super_mouse` 喂序列测试（5 种情况正确）；
  使用者以真实鼠标确认：拖动、调整大小正常且放开不开选单，单按与边移动边点 Super 都会开选单。
- **测试陷阱**：`wtype` 送出的按键**不会触发 Hyprland 绑定**（之前 `Super+空格` 看似成功，是 fcitx5 自己处理的），
  无法用来测快捷键；Hyprland 也没有模拟鼠标点击的方法。

## 2026-10-10 新增插件 fred.keyboard（使用者自行安装）

- 由 `sync.sh` 收录到 `plugins/plugins.tsv`（固定 commit），`install.sh` 会一并安装。

## 2026-10-10 本机：远程桌面改用 Sunshine + Moonlight（不入库，仅记录）

**现行设定**（`~/.config/sunshine/sunshine.conf`，含配对凭证，不入库）：

```
capture = kms
encoder = nvenc
origin_web_ui_allowed = pc
```

- 套件：Omarchy 软件库的 `sunshine`（2026.516，**非 CUDA 版**）。开机自启：
  `systemctl --user enable --now app-dev.lizardbyte.app.Sunshine.service`。
- 防火墙（只开局域网）：TCP 47984,47989,48010；UDP 47998:48000,48002,48010。管理网页 47990 只限本机。
- 键鼠：套件的 udev 规则让使用者可写 `/dev/uinput`，不需额外设定。
- 客户端：Windows 上的 Moonlight，配对时到 https://localhost:47990 输入 PIN。
- **实测效能**：串流 1080p 约 28 fps、网络延迟 1 ms、零丢包；sunshine 约 180% CPU。

**为什么只有 ~28 fps（双显卡笔电的硬件限制）**：笔电屏幕由 Intel 内显驱动，画面在内显上；
NVENC 在 RTX 3060。非 CUDA 版会走「内显 → 内存 → 3060」，4K 截屏后在 CPU 缩放与转色，因此卡在约 30 fps。

**试过但失败的路（不要再重试）**：

| 尝试 | 结果 |
|---|---|
| hypr-rdp（RDP） | 可用但只能 VAAPI；NVIDIA 的 VAAPI 驱动不能编码；内显 4K H.264 约 30 fps。已弃用并移除 |
| 官方 CUDA 版 `sunshine-bin` + `cuda` + NVENC + KMS | 3060 无法汇入内显的 dmabuf：`Couldn't import RGB Image: 00003004`，黑画面后在 libcuda 崩溃 |
| 同上 + `capture = wlr` | 同样的汇入错误，黑画面 |
| `sunshine-bin` + VAAPI（Intel，`adapter_name` 指定 iGPU） | 画面异常、无输入、SIGABRT 崩溃 |
| Omarchy 版 + VAAPI（Intel） | 同样无法使用 |

**仍可能改善的方向（未试）**：外接一台接在 NVIDIA 输出口的屏幕并串流那台（画面直接在 3060 上，免搬运）；
或 BIOS/厂商工具若有独显直连（MUX）模式。

**换电脑时**：装 `sunshine`、写上面的 conf、enable 服务、开防火墙、重新配对。

## 2026-10-10 Alt+Tab 切到的窗口一律到最上层（平铺窗口自动改浮动）

- **问题**：Alt+Tab（或点击）切到某些窗口，窗口取得焦点却没到最上层。
- **原因**：被切到的是**平铺**窗口（例如按过 `Super+W` 的 Chromium）。Hyprland 固定规则：浮动窗口永远在
  平铺窗口之上，`alter_zorder` 对平铺窗口无效，也没有设定可改。
- **修改**：`hypr/hyprland.lua` 的 `window.active` 处理：聚焦到平铺窗口时先
  `hl.dsp.window.float({ action = "enable" })` 再提到最上层；全屏窗口（`w.fullscreen ~= 0`）不动。
  使用者选择此方案：代价是平铺窗口一被聚焦就变浮动，平铺实际上留不住。
- **验证**：A 设平铺并压在 B 下，聚焦 A → A 变浮动且在 B 之上。

## 2026-10-10 聚焦已最小化的窗口会还原（修正「窗口被关在最小化区」）

- **问题**：窗口看得到却在 `special:minimized` 里，切工作区就消失；新开窗口也掉进最小化区；Dock 不隐藏。
- **原因**（以 `.socket2.sock` 事件记录查出）：Alt+Tab 等动作**聚焦一个已最小化的窗口**时，Hyprland
  会把整个最小化区打开而不是还原窗口；之后新窗口都开在打开着的最小化区里。
- **修改**：
  - `hypr/hyprland.lua` 的 `window.active`：被聚焦的窗口若在 `special:minimized`，移回目前工作区、
    关掉最小化区、重新聚焦（同 Win11 的 Alt+Tab 还原）。
  - 最小化改用 `hl.dsp.window.move({ ..., workspace = "special:minimized", follow = false })`：
    不打开最小化区、不聚焦窗口，否则上面的处理会马上把刚最小化的窗口还原回来（测试时实际发生过）。
    改在 `hypr/scripts/snap.sh` 与 Dock 的 `scripts/dock-minimize.py`（patch 已更新）。
- **验证**：`Win+↓` 最小化、聚焦它（模拟 Alt+Tab）、Dock 最小化、Dock 还原，四条路径结果正确，
  最小化区始终关闭。
- 上一节「未解」的成因即此，已解决。

## 2026-10-10 Super+空格 切换输入法；单按 Super 开 Omarchy 选单

- **修改**：`hypr/bindings.lua`
  - `hl.unbind("SUPER + SPACE")`（原为 Omarchy 选单），改绑 `fcitx5-remote -t`（英文 ↔ Rime）。
  - 单按 Super 开选单：**不用** `{ release = true }` 绑定——实测 Hyprland 的 release 绑定在 `Super+空格`
    这类组合键放开时也会触发。改为 `hl.on("input.keyboard.key", ...)` 自行判断：按住 Super
    期间有按过其他键就视为组合键，不开选单。
- **Hyprland 0.56 键盘事件**：回调参数 `(keycode, ?, pressed)`，keycode 为 xkb 码，Super_L=133、Super_R=134，
  pressed 按下=1／放开=0。`hl.is_key_down()` 在事件当下回报的是**处理该事件之前**的状态，不能拿来判断放开。
- **测试陷阱**：`wtype` 用自己的临时键盘配置，keycode 与真实键盘不同，且送 Super 组合键会让选单
  莫名打开（无绑定的 `Super+F12` 也会）——用 wtype 测 Super 相关行为**不可信**，要真实键盘确认。
  判断逻辑另以 `_G.omarchy_super_tap(code, 0, pressed)` 直接喂序列测试（6 种序列皆正确）。
- **验证**：使用者以真实键盘确认 `Super+空格` 切换正常、单按 Super 会开选单；诊断记录显示每次按一次只触发一次。
- **注意**：fcitx5 默认**每个窗口各自**记输入法状态（Win11 默认全域共用）；可改 fcitx5 `ShareInputState`，尚未改。

## 2026-10-10 本机：hypr-rdp 远程桌面（已弃用，改 Sunshine，见上方）

- 写在 `~/.config/hypr/local.lua`（`o.launch_on_start("hypr-rdp")`），设定 `~/.config/hypr-rdp/config.toml`
  含明文密码，**刻意不入库**，权限 600。
- `bind = "0.0.0.0:3389"`（原写死 IP，DHCP 换 IP 会起不来）、`output = "eDP-1"`（远程看笔电本身屏幕，不另开虚拟屏幕）。
- 防火墙：Omarchy 默认开 ufw，需 `sudo ufw allow from 192.168.2.0/24 to any port 3389 proto tcp`。
- 新电脑要用 RDP：装 `hypr-rdp`、建 config、在该机 `local.lua` 加自动启动、开防火墙。
- **验证**：使用者开放防火墙后，从局域网其他电脑连线成功。

## 2026-10-10 Shibumi 顶栏排列（使用者在顶栏内调整）

- `omarchy/shell.json` 的 Shibumi 区块变动（栏位排列、显示项目），由 sync.sh 收录。

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
- **（已解决，见上方「聚焦已最小化的窗口会还原」）** 窗口偶尔停在「打开的最小化区」里。排查方法：用 Hyprland 的
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
