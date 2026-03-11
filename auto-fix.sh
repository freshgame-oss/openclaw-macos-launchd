#!/bin/bash
# ~/.openclaw/auto-fix.sh - manual recovery helper for launchd-managed gateway

set -u

LOG_FILE="$HOME/.openclaw/logs/auto-fix.log"
ERR_LOG="$HOME/.openclaw/logs/gateway.err.log"
OUT_LOG="$HOME/.openclaw/logs/gateway.log"
LEGACY_ERR_LOG="$HOME/.openclaw/logs/gateway.stderr.log"
LEGACY_OUT_LOG="$HOME/.openclaw/logs/gateway.stdout.log"
LABEL="${OPENCLAW_LAUNCHD_LABEL:-ai.openclaw.gateway}"
DOMAIN="gui/$(id -u)"
SERVICE_TARGET="$DOMAIN/$LABEL"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "========== 开始诊断与恢复 =========="

if ! command -v openclaw >/dev/null 2>&1; then
  log "❌ openclaw CLI 未找到"
  exit 1
fi

log "检查 launchd 服务状态..."
launchctl print "$SERVICE_TARGET" >> "$LOG_FILE" 2>&1 || log "⚠️ 无法读取 $SERVICE_TARGET 状态"

log "收集最近错误日志..."
[ -f "$ERR_LOG" ] && tail -50 "$ERR_LOG" >> "$LOG_FILE" 2>&1
[ -f "$OUT_LOG" ] && tail -50 "$OUT_LOG" >> "$LOG_FILE" 2>&1
[ -f "$LEGACY_ERR_LOG" ] && tail -50 "$LEGACY_ERR_LOG" >> "$LOG_FILE" 2>&1
[ -f "$LEGACY_OUT_LOG" ] && tail -50 "$LEGACY_OUT_LOG" >> "$LOG_FILE" 2>&1

log "运行 doctor 修复配置..."
openclaw doctor --fix >> "$LOG_FILE" 2>&1 || true

log "通过 launchd 执行重启..."
if launchctl kickstart -k "$SERVICE_TARGET" >> "$LOG_FILE" 2>&1; then
  sleep 3
else
  log "❌ launchctl kickstart 执行失败"
  exit 1
fi

if launchctl print "$SERVICE_TARGET" 2>/dev/null | rg -q "state = running"; then
  log "✅ 恢复成功，launchd 服务已运行"
else
  log "❌ 恢复失败，请查看日志输出"
  exit 1
fi

log "========== 诊断与恢复结束 =========="
