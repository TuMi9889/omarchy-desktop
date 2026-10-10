-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
hl.unbind("SUPER + SHIFT + S")
o.bind("SUPER + SHIFT + S", "Screenshot", "omarchy-capture-screenshot")

-- Win11-style snapping on Super+Arrow (was: move focus in that direction).
-- Halves, quarters, maximize, restore and minimize: see scripts/snap.sh.
for _, key in ipairs({ "LEFT", "RIGHT", "UP", "DOWN" }) do
  hl.unbind("SUPER + " .. key)
end
local snap = os.getenv("HOME") .. "/.config/hypr/scripts/snap.sh "
o.bind("SUPER + LEFT", "Snap window left (Win11-style)", snap .. "left")
o.bind("SUPER + RIGHT", "Snap window right (Win11-style)", snap .. "right")
o.bind("SUPER + UP", "Snap up: maximize / top quarter", snap .. "up")
o.bind("SUPER + DOWN", "Snap down: restore / minimize / bottom quarter", snap .. "down")

-- Close window on SUPER+Q; SUPER+W toggles floating/tiling (was: close window).
hl.unbind("SUPER + W")
o.bind("SUPER + Q", "Close window", hl.dsp.window.close())
o.bind("SUPER + W", "Toggle window floating/tiling", hl.dsp.window.float({ action = "toggle" }))

-- Alt+Tab window switcher (omarchy plugin vbrosseau.alttab); SUPER+TAB kept as Omarchy default.
-- Keep the "Alt-Tab switcher" description: the plugin uses it to detect the binding.
hl.unbind("ALT + TAB")
o.bind("ALT + TAB", "Alt-Tab switcher", hl.dsp.global("omarchy-alttab:next"), { repeating = true })
hl.layer_rule({ match = { namespace = "omarchy-alttab" }, no_anim = true })

-- Super+Space 切换输入法（英文 ↔ Rime）；Omarchy 选单改成单按 Super（放开时触发）。
hl.unbind("SUPER + SPACE")
o.bind("SUPER + SPACE", "Toggle input method", "fcitx5-remote -t")

-- 单按 Super 开选单。不用 release 绑定：Hyprland 的 release 绑定在 Super+空格 等组合键
-- 放开时也会触发。改为监听按键事件：按住 Super 期间若按过其他键就视为组合键，不开选单。
-- 133/134 = Super_L/Super_R 的 xkb keycode（事件参数：keycode, ?, 按下=1/放开=0）。
do
  local SUPER = { [133] = true, [134] = true }
  local held, combo = false, false
  _G.omarchy_super_tap = function(code, _, pressed)
    if SUPER[code] then
      if pressed == 1 then
        held, combo = true, false
      elseif held then
        held = false
        if not combo then
          hl.exec_cmd("omarchy-menu toggle")
        end
      end
    elseif held and pressed == 1 then
      combo = true
    end
  end
  hl.on("input.keyboard.key", _G.omarchy_super_tap)
end
