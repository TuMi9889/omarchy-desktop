#!/bin/bash

# Win11-style snapping for Super+Arrow.
#
#   从普通窗口：← 左半屏   → 右半屏   ↑ 最大化   ↓ 最小化（到 Dock）
#   左半屏：    ↑ 左上 1/4  ↓ 左下 1/4  → 还原
#   右半屏：    ↑ 右上 1/4  ↓ 右下 1/4  ← 还原
#   左上 1/4：  → 右上 1/4  ↓ 左半屏
#   右上 1/4：  ← 左上 1/4  ↓ 右半屏
#   左下 1/4：  → 右下 1/4  ↑ 左半屏
#   右下 1/4：  ← 左下 1/4  ↑ 右半屏
#   最大化：    ↓ 还原      ← 左半屏   → 右半屏
#
# "还原"回到贴靠前的位置与大小（记录在 $XDG_RUNTIME_DIR/hypr-snap/），
# 没有记录时改为置中 60%x70%。平铺窗口会先转为浮动再贴靠。
#
# 标题栏按钮用：toggle-max（最大化 <-> 还原）、minimize（最小化到 Dock）

dir=$1
tolerance=8
state_dir="${XDG_RUNTIME_DIR:-/tmp}/hypr-snap"

active=$(hyprctl activewindow -j)
addr=$(jq -r '.address // empty' <<<"$active")
[[ -z $addr ]] && exit 0
[[ $(jq '.fullscreen' <<<"$active") != 0 ]] && exit 0

window="address:$addr"
dispatch() { hyprctl dispatch "$1" >/dev/null; }

monitor=$(hyprctl monitors -j | jq --argjson id "$(jq '.monitor' <<<"$active")" '.[] | select(.id == $id)')
read -r mx my mw mh < <(jq -r '
  (.width / .scale | floor) as $w | (.height / .scale | floor) as $h
  | if (.transform % 2) == 1 then [$h, $w] else [$w, $h] end as [$w, $h]
  | "\(.x + .reserved[0]) \(.y + .reserved[1]) \($w - .reserved[0] - .reserved[2]) \($h - .reserved[1] - .reserved[3])"' <<<"$monitor")

border=$(hyprctl getoption general:border_size -j | jq '.int')
gap=$(hyprctl getoption general:gaps_out -j | jq -r '.css // .custom // .int' | awk '{print $1+0}')
inset=$((border + gap))
hw=$((mw / 2))
hh=$((mh / 2))

# hyprbars 标题栏画在窗口上方（不算在窗口尺寸内），贴靠时要让出它的高度，
# 否则标题栏会压到顶栏（Shibumi）或上方的窗口。没装插件时为 0。
bar=$(hyprctl getoption plugin:hyprbars:bar_height -j 2>/dev/null | jq '.int // 0' 2>/dev/null)
[[ $bar =~ ^[0-9]+$ ]] || bar=0

# 各贴靠位置的 "x y w h"（已扣掉标题栏）
rect() {
  local x y w h
  read -r x y w h < <(rect_raw "$1")
  echo "$x" $((y + bar)) "$w" $((h - bar))
}

rect_raw() {
  case $1 in
    left)  echo $((mx + inset)) $((my + inset)) $((hw - 2 * inset)) $((mh - 2 * inset)) ;;
    right) echo $((mx + hw + inset)) $((my + inset)) $((mw - hw - 2 * inset)) $((mh - 2 * inset)) ;;
    max)   echo $((mx + inset)) $((my + inset)) $((mw - 2 * inset)) $((mh - 2 * inset)) ;;
    tl)    echo $((mx + inset)) $((my + inset)) $((hw - 2 * inset)) $((hh - 2 * inset)) ;;
    tr)    echo $((mx + hw + inset)) $((my + inset)) $((mw - hw - 2 * inset)) $((hh - 2 * inset)) ;;
    bl)    echo $((mx + inset)) $((my + hh + inset)) $((hw - 2 * inset)) $((mh - hh - 2 * inset)) ;;
    br)    echo $((mx + hw + inset)) $((my + hh + inset)) $((mw - hw - 2 * inset)) $((mh - hh - 2 * inset)) ;;
  esac
}

floating=$(jq '.floating' <<<"$active")
read -r cx cy cw ch < <(jq -r '"\(.at[0]) \(.at[1]) \(.size[0]) \(.size[1])"' <<<"$active")

near() { (( ${1#-} <= tolerance )); }

# 判断窗口目前停在哪个贴靠位置
current=none
if [[ $floating == true ]]; then
  for pos in left right max tl tr bl br; do
    read -r x y w h < <(rect $pos)
    if near $((cx - x)) && near $((cy - y)) && near $((cw - w)) && near $((ch - h)); then
      current=$pos
      break
    fi
  done
fi

case "$current:$dir" in
  max:toggle-max)                      target=restore ;;
  *:toggle-max)                        target=max ;;
  *:minimize)                          target=minimize ;;
  none:left|max:left|tl:down|bl:up)    target=left ;;
  none:right|max:right|tr:down|br:up)  target=right ;;
  none:up)                             target=max ;;
  none:down)                           target=minimize ;;
  left:up|tr:left)                     target=tl ;;
  right:up|tl:right)                   target=tr ;;
  left:down|br:left)                   target=bl ;;
  right:down|bl:right)                 target=br ;;
  left:right|right:left|max:down)      target=restore ;;
  *)                                   exit 0 ;;
esac

state_file="$state_dir/$addr"

case $target in
  minimize)
    dispatch "hl.dsp.window.move({ window = \"$window\", workspace = \"special:minimized\" })"
    # 移进 special 工作区会顺带把它打开；跟 Dock 一样立刻关回去，
    # 否则最小化区会一直盖在画面上，Dock 也会以为工作区是空的而不隐藏。
    hyprctl monitors -j | jq -r '.[].specialWorkspace.name // empty' | while read -r sw; do
      [[ -n $sw ]] && dispatch "hl.dsp.workspace.toggle_special(\"${sw#special:}\")"
    done
    exit 0
    ;;
  restore)
    if [[ -r $state_file ]]; then
      read -r x y w h <"$state_file"
      rm -f -- "$state_file"
    else
      w=$((mw * 60 / 100)); h=$((mh * 70 / 100)); x=$((mx + (mw - w) / 2)); y=$((my + (mh - h) / 2))
    fi
    ;;
  *)
    # 第一次从普通窗口贴靠时，记下原本位置以便还原
    if [[ $current == none && $floating == true ]]; then
      mkdir -p -- "$state_dir"
      echo "$cx $cy $cw $ch" >"$state_file"
    fi
    read -r x y w h < <(rect $target)
    ;;
esac

if [[ $floating != true ]]; then
  dispatch "hl.dsp.window.float({ window = \"$window\", action = \"toggle\" })"
fi

# Resize before moving: resizing can shift the window's position.
dispatch "hl.dsp.window.resize({ window = \"$window\", x = $w, y = $h })"
dispatch "hl.dsp.window.move({ window = \"$window\", x = $x, y = $y })"
dispatch "hl.dsp.window.alter_zorder({ window = \"$window\", mode = \"top\" })"
