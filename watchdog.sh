#!/bin/bash
# ~/.openclaw/watchdog.sh - launchd-backed gateway health check

set -u

LOG_FILE="$HOME/.openclaw/logs/watchdog.log"
LABEL="${OPENCLAW_LAUNCHD_LABEL:-ai.openclaw.gateway}"
DOMAIN="gui/$(id -u)"
SERVICE_TARGET="$DOMAIN/$LABEL"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

service_running() {
  launchctl print "$SERVICE_TARGET" 2>/dev/null | rg -q "state = running"
}

main() {
  log "==== 检查开始 ===="

  if service_running; then
    log "✅ launchd 服务正常"
    log "==== 检查结束 ===="
    exit 0
  fi

  log "⚠️ 检测到 gateway 异常，交由 launchd 接管恢复"
  if launchctl kickstart -k "$SERVICE_TARGET" >/dev/null 2>&1; then
    sleep 3
    if service_running; then
      log "✅ launchd 恢复成功"
      log "==== 检查结束 ===="
      exit 0
    fi
  fi

  log "❌ launchd 恢复失败，请查看 ~/.openclaw/logs/gateway.err.log"
  log "==== 检查结束 ===="
  exit 1
}

main
