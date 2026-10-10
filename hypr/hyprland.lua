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

-- Win11 风格：窗口获得焦点（Alt+Tab、点击、Dock 还原）时提到最上层（平铺窗口会先改成浮动）。
-- 若被聚焦的是最小化的窗口（例如 Alt+Tab 选到它），Hyprland 默认会把整个最小化区打开，
-- 之后新窗口都会开进去；这里改成像 Win11 一样把它还原到目前的工作区。
hl.on("window.active", function(w)
  if not (w and w.address) then return end
  local win = "address:" .. w.address
  if w.workspace and w.workspace.name == "special:minimized" then
    local ws = hl.get_active_workspace()
    local target = ws and ws.name or "1"
    if target:sub(1, 8) == "special:" then target = "1" end
    hl.dispatch(hl.dsp.window.move({ window = win, workspace = target }))
    local sp = hl.get_active_special_workspace()
    if sp and sp.name == "special:minimized" then
      hl.dispatch(hl.dsp.workspace.toggle_special("minimized"))
    end
    hl.dispatch(hl.dsp.focus({ window = win }))
    return
  end
  -- 平铺窗口永远在浮动窗口下面（Hyprland 固定规则），所以聚焦到平铺窗口时先改成浮动，
  -- 才能像 Win11 一样提到最上层。全屏窗口不动。
  if not w.floating and (w.fullscreen or 0) == 0 then
    hl.dispatch(hl.dsp.window.float({ window = win, action = "enable" }))
  end
  hl.dispatch(hl.dsp.window.alter_zorder({ window = win, mode = "top" }))
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
