-- Win11 风格标题栏（hyprbars 插件）：右侧依序为 最小化 / 最大化-还原 / 关闭。
-- 插件由 hyprpm 编译；Hyprland 更新后若标题栏消失，执行 `hyprpm update` 重新编译。
-- 载入失败（未安装、版本不符）时整段跳过，不影响其他配置。
--
-- 不可在配置里直接 hl.plugin.load：冷启动时载入插件会触发配置重载，重载时插件尚未挂上
-- 又再载入一次 → reload/handlePluginLoads 无限递归，Hyprland 卡死、登入后黑屏（2026-10-10 实测）。
-- 改为启动完成后用 hyprctl 载入，再 reload 让下面的按钮设置生效。

if not (hl.plugin.hyprbars and hl.plugin.hyprbars.add_button) then
  local so = "/var/cache/hyprpm/" .. (os.getenv("USER") or "") .. "/hyprland-plugins/hyprbars.so"
  local f = io.open(so, "r")
  if f then
    f:close()
    o.exec_on_start("hyprctl plugin load '" .. so .. "' && hyprctl reload")
  end
  return
end

local snap = os.getenv("HOME") .. "/.config/hypr/scripts/snap.sh "

hl.config({
  plugin = {
    hyprbars = {
      bar_height = 30,
      bar_color = "rgba(202020ff)",
      ["col.text"] = "rgba(e6e6e6ff)",
      bar_text_size = 11,
      bar_text_font = "JetBrainsMono Nerd Font",
      bar_text_align = "left",
      bar_padding = 12,
      bar_button_padding = 14,
      bar_buttons_alignment = "right",
      bar_precedence_over_border = true,
      bar_part_of_window = true,
      icon_on_hover = false,
      on_double_click = snap .. "toggle-max",
    },
  },
})

-- 先加入的按钮排在最右边，所以顺序是 关闭 → 最大化 → 最小化。
local fg = "rgba(e6e6e6ff)"
hl.plugin.hyprbars.add_button({ bg_color = "rgba(c42b1cff)", fg_color = fg, size = 16, icon = "󰖭", action = "hyprctl dispatch 'hl.dsp.window.close()'" })
hl.plugin.hyprbars.add_button({ bg_color = "rgba(3a3a3aff)", fg_color = fg, size = 16, icon = "󰖯", action = snap .. "toggle-max" })
hl.plugin.hyprbars.add_button({ bg_color = "rgba(3a3a3aff)", fg_color = fg, size = 16, icon = "󰖰", action = snap .. "minimize" })
