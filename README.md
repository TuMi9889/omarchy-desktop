# omarchy-desktop

我的 Omarchy 桌面设置：Win11 风格的窗口操作、快捷键、Omarchy 插件、Dock、标题栏。
换电脑时一键还原。

## 新电脑还原

前提：新电脑已经装好 Omarchy，并且登录进 Hyprland 桌面。

```bash
git clone https://github.com/TuMi9889/omarchy-desktop.git ~/omarchy-desktop
cd ~/omarchy-desktop && ./install.sh
```

仓库是公开的，下载不需要登录；只有之后要用 `./sync.sh --push` 上传修改时才需要 `gh auth login`。

- 会问一次 sudo 密码（安装编译标题栏插件用的 cmake/meson/ninja）。
- 不想装标题栏：`./install.sh --no-hyprbars`。
- 被覆盖的旧文件会备份在 `~/.local/state/omarchy-desktop/backup-<时间>/`。

## 修改记录

所有修改的内容、原因、验证方式与注意事项：[`docs/CHANGES.md`](docs/CHANGES.md)。

## 平时维护

改过桌面设置、装或删了插件之后：

```bash
cd ~/omarchy-desktop
./sync.sh          # 收集目前设置，看有哪些变动
./sync.sh --push   # 确认后 commit 并上传
```

上传前在 `docs/CHANGES.md` 最上面补一节，写下改了什么、为什么。

## 内容

| 位置 | 内容 |
|---|---|
| `hypr/` | Hyprland 设置：默认浮动、焦点提到最上层、快捷键、标题栏（`titlebars.lua`）、Win+方向键贴靠（`scripts/snap.sh`） |
| `omarchy/` | `shell.json`（插件启用状态与 Shibumi 设置）、`dock-settings.json`、选单扩展 |
| `plugins/plugins.tsv` | git 安装的插件：来源与版本（commit） |
| `plugins/patches/` | 对第三方插件做的本机修改（安装时自动套用） |
| `plugins/vendored/` | 不是从 git 安装的插件（Shibumi 套件），整份收录 |
| `hyprpm.tsv` | hyprpm 插件（hyprbars） |
| `manifest.sh` | 要同步哪些文件的清单 |

**刻意不收录**（跟机器走）：`monitors.lua`、`hyprmoncfg-monitors.lua`、`local.lua`（GIGABYTE AERO 15 的 Fn 键、触控板、显卡设置）。

## 对第三方插件的修改

`plugins/patches/rosakodu.dock.patch`：
1. `DockSettings.js`：hover 模式下 Dock 一律隐藏，只在鼠标靠近时显示（原版在空工作区会一直显示）。
2. `scripts/dock-minimize.py`：`toggle_special` 改传字符串；原版传表格会被 Hyprland 0.56 忽略，打开空的 `special:special`。

`omarchy plugin update` 会把插件更新成上游版本，这些修改会消失。更新后执行 `./install.sh` 会重新套用；
若上游代码变动太大导致 patch 失败，安装时会出现警告。

## 已知注意事项

- Hyprland 更新后标题栏消失：执行 `hyprpm update` 重新编译。
- 改了插件里的 `.pragma library` JS 文件，要 `omarchy-restart-shell` 才会生效。
