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
