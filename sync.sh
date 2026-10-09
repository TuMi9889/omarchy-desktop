#!/usr/bin/env bash
# 把这台电脑目前的桌面设置收进仓库（维护用）。
#   ./sync.sh          收集并显示有哪些变动
#   ./sync.sh --push   收集后自动 commit 并 push
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYPR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
OMARCHY="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy"
PLUGINS="$OMARCHY/plugins"

# shellcheck source=manifest.sh
source "$REPO/manifest.sh"

echo "==> Hyprland 设置"
rm -rf "$REPO/hypr"
mkdir -p "$REPO/hypr"
for f in "${HYPR_FILES[@]}"; do
  if [[ -e $HYPR/$f ]]; then
    mkdir -p "$REPO/hypr/$(dirname "$f")"
    cp -a "$HYPR/$f" "$REPO/hypr/$f"
  else
    echo "    （跳过，不存在）$f"
  fi
done

echo "==> Omarchy 设置"
rm -rf "$REPO/omarchy"
mkdir -p "$REPO/omarchy"
for f in "${OMARCHY_FILES[@]}"; do
  if [[ -e $OMARCHY/$f ]]; then
    mkdir -p "$REPO/omarchy/$(dirname "$f")"
    cp -a "$OMARCHY/$f" "$REPO/omarchy/$f"
  fi
done

echo "==> Omarchy 插件"
rm -rf "$REPO/plugins"
mkdir -p "$REPO/plugins/patches" "$REPO/plugins/vendored"
list="$REPO/plugins/plugins.tsv"
printf '# id\tgit-url\tcommit\n' >"$list"
for dir in "$PLUGINS"/*/; do
  dir=${dir%/}
  id=$(basename "$dir")
  if [[ -d $dir/.git ]]; then
    url=$(git -C "$dir" remote get-url origin)
    commit=$(git -C "$dir" rev-parse HEAD)
    printf '%s\t%s\t%s\n' "$id" "$url" "$commit" >>"$list"
    # 本机对插件做过的修改，存成 patch，安装时自动套用
    if ! git -C "$dir" diff --quiet HEAD; then
      git -C "$dir" diff HEAD >"$REPO/plugins/patches/$id.patch"
      echo "    $id：有本机修改 → patches/$id.patch"
    fi
    if [[ -n $(git -C "$dir" ls-files --others --exclude-standard) ]]; then
      echo "    警告：$id 有未追踪的新文件，没有收进仓库：" >&2
      git -C "$dir" ls-files --others --exclude-standard | sed 's/^/      /' >&2
    fi
  else
    # 不是 git 安装的插件（例如 Shibumi 套件），整个复制进来
    cp -a "$dir" "$REPO/plugins/vendored/$id"
    rm -rf "$REPO/plugins/vendored/$id/__pycache__"
  fi
done
echo "    git 插件 $(($(wc -l <"$list") - 1)) 个，内含插件 $(find "$REPO/plugins/vendored" -mindepth 1 -maxdepth 1 | wc -l) 个"

echo "==> hyprpm 插件"
{
  echo "# repo-url<TAB>启用的插件（空格分隔）"
  printf '%s\t%s\n' "$HYPRPM_REPO" "$(hyprpm list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | awk '/Plugin /{p=$NF} /enabled: true/{print p}' | xargs)"
} >"$REPO/hyprpm.tsv"
cat "$REPO/hyprpm.tsv" | tail -1 | sed 's/^/    /'

cd "$REPO"
echo
if [[ -z $(git status --porcelain) ]]; then
  echo "没有变动。"
  exit 0
fi
git status --short | head -40

if [[ ${1:-} == --push ]]; then
  git add -A
  git commit -q -m "sync: $(date '+%Y-%m-%d %H:%M') 桌面设置更新"
  git push -q
  echo "已 commit 并 push。"
else
  echo
  echo "确认无误后执行：./sync.sh --push"
fi
