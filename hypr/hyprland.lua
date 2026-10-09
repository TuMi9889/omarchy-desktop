-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Disable all Omarchy default bindings. Add your own in hypr/bindings.lua.
-- omarchy_default_bindings = false
--
-- Or disable only bindings for Omarchy's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- omarchy_preinstalled_bindings = false

-- Load Omarchy defaults.
require("default.hypr.omarchy")

-- Put your personal overrides in these files. They're loaded after Omarchy's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- 本机专属设置（硬件、显卡、显示器相关），不纳入 omarchy-desktop 仓库。
do local path = os.getenv("HOME") .. "/.config/hypr/local.lua"; local file = io.open(path, "r"); if file then file:close(); dofile(path) end end

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })

-- Open every window floating by default (Super+W toggles back to tiling).
o.window(".*", { float = true })

-- Win11 风格：窗口获得焦点（Alt+Tab、点击、Dock 还原）时提到最上层。
hl.on("window.active", function(w)
  if w and w.floating and w.address then
    hl.dispatch(hl.dsp.window.alter_zorder({ window = "address:" .. w.address, mode = "top" }))
  end
end)

-- Win11 风格标题栏（hyprbars）。
require("hypr.titlebars")

-- VRChat (Steam/Proton) opens fullscreen.
o.window({ class = "^(steam_app_438100|VRChat|vrchat\\.exe)$" }, { fullscreen = true, idle_inhibit = "fullscreen" })


-- >>> omaland managed block >>>
-- Written by Omaland. Safe to hand-edit: Omaland re-reads this block
-- every time it opens, and only ever rewrites what's between the fences.
o.window(".*", { opacity = "1 1" })
-- <<< omaland managed block <<<

-- Added by hyprmoncfg: its generated monitor rules load last, so nothing before this can override the applied layout.
do local path = os.getenv("HOME") .. "/.config/hypr/hyprmoncfg-monitors.lua"; local file = io.open(path, "r"); if file then file:close(); dofile(path) end end
