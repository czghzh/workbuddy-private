#!/usr/bin/env bash
# 收集 WorkBuddy 各级 MEMORY.md → 本仓库 → 推送。
#   ./sync.sh           # 收集 + 扫描 + 提交 + 推送
#   ./sync.sh --check   # 只收集 + 扫描，不提交不推送
#
# 只收 MEMORY.md（长期记忆），不收 memory/YYYY-MM-DD.md 日志——日志是草稿，
# 内容会过期，长期结论已经被蒸馏进 MEMORY.md 和技能里。

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$REPO/memory"
MANIFEST="$OUT/MANIFEST.tsv"
CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

mkdir -p "$OUT"

# ── 1. 收集 ──────────────────────────────────────────────────────
# 两列 manifest：<仓库内文件名>\t<恢复时的绝对路径>
# 恢复路径就是文件原本所在的位置，所以直接用源路径。
collect() {
  local src="$1" label
  [ -f "$src" ] || return 0
  if [ "$src" = "$HOME/.workbuddy/MEMORY.md" ]; then
    label="global"
  else
    local rel="${src%/.workbuddy/memory/MEMORY.md}"    # workspace 绝对路径
    rel="${rel#$HOME/}"                                 # 去 home 前缀
    label="$(printf '%s' "$rel" | tr '/' '-')"
  fi
  cp -f "$src" "$OUT/$label-MEMORY.md"
  printf '%s\t%s\n' "$label-MEMORY.md" "$src" >> "$MANIFEST"
}

: > "$MANIFEST"
collect "$HOME/.workbuddy/MEMORY.md"
# 项目级：workspace 根下的 .workbuddy/memory/MEMORY.md
# -L 必须加：workspace 可能是软链（515xg 就指向外接盘），find 默认不跟进。
# 515xg-src-old 是弃用旧树的残根，记忆是 515xg 的过期副本，跳过。
while IFS= read -r -d '' f; do
  case "$f" in *515xg-src-old/*) continue ;; esac
  collect "$f"
done < <(find -L "$HOME" -mindepth 2 -maxdepth 6 -type f -name MEMORY.md \
             -path '*/.workbuddy/memory/MEMORY.md' -print0 2>/dev/null \
             | sort -z)

# 清理已消失的条目（项目被删掉后）
find "$OUT" -name '*-MEMORY.md' -type f | while read -r f; do
  base="${f##*/}"
  grep -qF "$base" "$MANIFEST" || rm -f "$f"
done

echo "==> 收集到 $(wc -l < "$MANIFEST") 份 MEMORY.md"
sed 's/^/     /' "$MANIFEST"

# ── 2. 扫描门禁 ─────────────────────────────────────────────────
fail=0
scan_block() {
  local label="$1" pat="$2" hits
  # -e 明确指定正则，避免 pattern 被当成 grep 选项。
  # \x60/\x27/\x22 = 反引号/单引号/双引号，避开 shell 引号地狱。
  hits=$(grep -rnIP --exclude='sync.sh' --exclude='restore.sh' \
             --exclude-dir='.git' -e "$pat" . 2>/dev/null || true)
  if [ -n "$hits" ]; then
    echo "✗  阻断：$label"; echo "$hits" | sed 's/^/     /'; fail=1
  else
    echo "✓  $label"
  fi
}

echo
echo "==> 扫描门禁"
scan_block "私钥块"            'BEGIN (RSA|OPENSSH|EC|DSA|PGP|ENCRYPTED) PRIVATE KEY'
scan_block "密码写死在正文"     '密码[均为]*[[:space:]]*\x60|密码[均为]*[[:space:]]*[:：][[:space:]]*[\x60\x27\x22]'
scan_block "password 赋值"      'password[[:space:]]*[:=][[:space:]]*[\x60\x27\x22]'
scan_block "API token / secret" '(api[_-]?token|secret[_-]?key|access[_-]?token|apikey|enc_token|appkey)[[:space:]]*[:=][[:space:]]*[\x60\x27\x22]'
scan_block "Bearer 令牌"        'Bearer[[:space:]]+[A-Za-z0-9._~-]{16,}'

if [ "$fail" -ne 0 ]; then
  echo; echo "✗  扫描未通过，已停止。"; exit 1
fi

if [ "$CHECK_ONLY" -eq 1 ]; then
  echo; echo "==> --check：扫描通过，未提交未推送。"; exit 0
fi

# ── 3. 提交 + 推送 ──────────────────────────────────────────────
cd "$REPO"
git add -A
if git diff --cached --quiet; then
  echo; echo "==> 没有变更，无需提交。"; exit 0
fi
echo; echo "==> 本次变更"; git diff --cached --stat | sed 's/^/     /'
git commit -q -m "sync memory: $(date +%Y-%m-%d)"
git push origin main
echo; echo "✓  已推送。"
