#!/usr/bin/env bash
# 在一台装好 Omarchy 的电脑上，一键还原这套桌面设置。
# 请在 Hyprland 桌面里的终端执行：
#   ./install.sh                 全部还原
#   ./install.sh --no-hyprbars   不装标题栏插件（不需要 sudo）
#
# 会被覆盖的文件，先备份到 ~/.local/state/omarchy-desktop/backup-<时间>/
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYPR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
OMARCHY="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy"
PLUGINS="$OMARCHY/plugins"
BACKUP="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-desktop/backup-$(date +%Y%m%d-%H%M%S)"

WITH_HYPRBARS=1
for arg in "$@"; do
  case $arg in
    --no-hyprbars) WITH_HYPRBARS=0 ;;
    -h | --help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "未知参数：$arg" >&2; exit 1 ;;
  esac
done

# shellcheck source=manifest.sh
source "$REPO/manifest.sh"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m警告：%s\033[0m\n' "$*" >&2; }

backup() { # backup <绝对路径>：存在就搬进备份目录（保留相对 $HOME 的结构）
  local src=$1
  [[ -e $src ]] || return 0
  local dst="$BACKUP/${src#"$HOME"/}"
  mkdir -p "$(dirname "$dst")"
  mv "$src" "$dst"
}

step "检查环境"
for cmd in omarchy hyprctl git jq; do
  command -v "$cmd" >/dev/null || { echo "找不到 $cmd。请先装好 Omarchy 再执行。" >&2; exit 1; }
done
hyprctl version >/dev/null 2>&1 || { echo "请在 Hyprland 桌面里的终端执行本脚本。" >&2; exit 1; }
echo "OK（备份目录：$BACKUP）"

step "Omarchy 插件"
mkdir -p "$PLUGINS"
while IFS=$'\t' read -r id url commit; do
  [[ -z $id || $id == \#* ]] && continue
  dir="$PLUGINS/$id"
  backup "$dir"
  if git clone -q "$url" "$dir" 2>/dev/null && git -C "$dir" reset -q --hard "$commit" 2>/dev/null; then
    patch="$REPO/plugins/patches/$id.patch"
    if [[ -f $patch ]]; then
      if git -C "$dir" apply "$patch"; then
        echo "  ✓ $id（已套用本机修改）"
      else
        warn "$id 的本机修改套用失败，插件维持原版"
      fi
    else
      echo "  ✓ $id"
    fi
  else
    warn "$id 下载失败（$url），跳过"
    rm -rf "$dir"
  fi
done <"$REPO/plugins/plugins.tsv"

for src in "$REPO"/plugins/vendored/*/; do
  [[ -d $src ]] || continue
  id=$(basename "$src")
  backup "$PLUGINS/$id"
  cp -a "${src%/}" "$PLUGINS/$id"
  echo "  ✓ $id（内含）"
done

step "Omarchy 设置（插件启用状态、Dock、选单）"
for f in "${OMARCHY_FILES[@]}"; do
  [[ -e $REPO/omarchy/$f ]] || continue
  backup "$OMARCHY/$f"
  mkdir -p "$(dirname "$OMARCHY/$f")"
  cp -a "$REPO/omarchy/$f" "$OMARCHY/$f"
  echo "  ✓ $f"
done

step "Hyprland 设置（快捷键、窗口行为、贴靠脚本、标题栏）"
for f in "${HYPR_FILES[@]}"; do
  [[ -e $REPO/hypr/$f ]] || continue
  backup "$HYPR/$f"
  mkdir -p "$(dirname "$HYPR/$f")"
  cp -a "$REPO/hypr/$f" "$HYPR/$f"
  echo "  ✓ $f"
done
chmod +x "$HYPR/scripts/"*.sh 2>/dev/null || true

if ((WITH_HYPRBARS)); then
  step "标题栏插件 hyprbars（需要 sudo 密码，编译要几分钟）"
  read -r repo_url enabled < <(grep -v '^#' "$REPO/hyprpm.tsv" | head -1 | tr '\t' ' ')
  sudo pacman -S --needed --noconfirm cmake meson ninja cpio git pkgconf
  hyprpm update
  if ! hyprpm list 2>/dev/null | grep -q 'hyprland-plugins'; then
    yes | hyprpm add "$repo_url"
  fi
  for p in $enabled; do
    hyprpm enable "$p" && echo "  ✓ $p"
  done
else
  echo
  echo "（已跳过标题栏插件；之后要装可执行：./install.sh 不加参数，或参考 README）"
fi

step "套用设置"
hyprctl reload >/dev/null
errors=$(hyprctl configerrors)
if [[ -n ${errors// /} && $errors != *"no errors"* ]]; then
  warn "Hyprland 配置有错误："
  echo "$errors"
fi
omarchy-restart-shell >/dev/null 2>&1 || true

cat <<EOF

完成！
- 被覆盖的旧文件在：$BACKUP
- 显示器设置（monitors.lua）没有覆盖，沿用这台电脑自己的。
- 本机硬件专属设置可以写在 ~/.config/hypr/local.lua（不会被同步）。
EOF
