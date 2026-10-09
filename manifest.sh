# 要收进仓库的文件清单（sync.sh 与 install.sh 共用）。
# 路径相对于 ~/.config/hypr 与 ~/.config/omarchy。
# 刻意不收：monitors.lua、hyprmoncfg-monitors.lua（显示器跟机器走）、
#           local.lua（本机硬件专属设置）、*.bak*、*.save*。

HYPR_FILES=(
  hyprland.lua
  bindings.lua
  input.lua
  looknfeel.lua
  autostart.lua
  titlebars.lua
  scripts/snap.sh
)

OMARCHY_FILES=(
  shell.json
  shell.toml
  dock-settings.json
  extensions/omarchy-menu.jsonc
)

HYPRPM_REPO="https://github.com/hyprwm/hyprland-plugins"
