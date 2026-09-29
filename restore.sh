#!/usr/bin/env bash
# 重装系统后：把本仓库的 MEMORY.md 恢复到原来的绝对路径。
#   ./restore.sh            # 真恢复
#   ./restore.sh --dry-run  # 只打印会做什么
#
# 依据 memory/MANIFEST.tsv（两列：仓库内文件名 \t 恢复目标绝对路径）。
# 只在目标文件不存在或已被显式确认时写入；默认备份已有文件为 .bak。

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$REPO/memory/MANIFEST.tsv"
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

[ -f "$MANIFEST" ] || { echo "✗  找不到 $MANIFEST"; exit 1; }

printf '%-34s -> %s\n' "仓库文件" "恢复目标"
while IFS=$'\t' read -r name dest; do
  [ -n "$name" ] || continue
  src="$REPO/memory/$name"
  [ -f "$src" ] || { echo "✗  源文件缺失：$src"; exit 1; }

  if [ -e "$dest" ]; then
    printf '%-34s -> %s   已存在，跳过（先 mv 到 .bak 再跑）\n' "$name" "$dest"
    continue
  fi

  dir="$(dirname "$dest")"
  if [ "$DRY" -eq 1 ]; then
    printf '%-34s -> %s   [dry-run]\n' "$name" "$dest"
  else
    mkdir -p "$dir"
    cp "$src" "$dest"
    printf '%-34s -> %s   ✓\n' "$name" "$dest"
  fi
done < "$MANIFEST"

echo
echo "完成。注意：项目级 MEMORY.md 所在 workspace 得先建好；"
echo "日志（memory/YYYY-MM-DD.md）不在本仓库里，不恢复。"
