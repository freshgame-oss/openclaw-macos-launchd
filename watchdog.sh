#!/bin/bash
# ~/.openclaw/watchdog.sh - launchd-backed gateway health check

set -u

MAX_FAILURES=3
FAILURE_WINDOW=300  # 5分钟窗口

LOG_FILE="$HOME/.openclaw/logs/watchdog.log"
FAILURE_FILE="$HOME/.openclaw/logs/failure-count"
LABEL="${OPENCLAW_LAUNCHD_LABEL:-ai.openclaw.gateway}"
DOMAIN="gui/$(id -u)"
SERVICE_TARGET="$DOMAIN/$LABEL"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

service_running() {
  launchctl print "$SERVICE_TARGET" 2>/dev/null | rg -q "state = running"
}

check_gateway() {
  if service_running; then
    return 0
  fi

  if curl -s --max-time 3 http://127.0.0.1:18789/health >/dev/null 2>&1; then
    return 0
  fi

  return 1
}

get_failure_count() {
  if [ -f "$FAILURE_FILE" ]; then
    local last_time
    last_time=$(head -1 "$FAILURE_FILE")
    local now
    now=$(date +%s)
    if [ $((now - last_time)) -gt $FAILURE_WINDOW ]; then
      echo "0"
    else
      tail -1 "$FAILURE_FILE"
    fi
  else
    echo "0"
  fi
}

record_failure() {
  local now
  now=$(date +%s)
  local count
  count=$(get_failure_count)
  {
    echo "$now"
    echo "$((count + 1))"
  } > "$FAILURE_FILE"
}

trigger_fix() {
  log "⚠️ 连续失败 $MAX_FAILURES 次，触发 auto-fix..."
  if [ -f "$HOME/.openclaw/scripts/auto-fix.sh" ]; then
    bash "$HOME/.openclaw/scripts/auto-fix.sh" 2>&1 | tee -a "$HOME/.openclaw/logs/auto-fix.log"
  else
    log "❌ auto-fix.sh 不存在，跳过"
  fi
}

recover_via_launchd() {
  log "⚠️ 检测到 gateway 异常，交由 launchd 接管恢复"
  if launchctl kickstart -k "$SERVICE_TARGET" >/dev/null 2>&1; then
    sleep 3
    if service_running; then
      log "✅ launchd 恢复成功"
      return 0
    fi
  fi

  log "❌ launchd 恢复失败，请查看 ~/.openclaw/logs/gateway.err.log"
  return 1
}

main() {
  log "==== 检查开始 ===="

  if check_gateway; then
    log "✅ Gateway 运行正常"
    [ -f "$FAILURE_FILE" ] && rm -f "$FAILURE_FILE"
    log "==== 检查结束 ===="
    exit 0
  fi

  record_failure
  local failures
  failures=$(get_failure_count)
  log "⚠️ Gateway 检查失败 (连续失败: $failures 次)"

  if recover_via_launchd; then
    rm -f "$FAILURE_FILE"
    log "==== 检查结束 ===="
    exit 0
  fi

  if [ "$failures" -ge "$MAX_FAILURES" ]; then
    trigger_fix
    rm -f "$FAILURE_FILE"
  else
    log "⏳ 等待下次检查... ($failures/$MAX_FAILURES)"
  fi

  log "==== 检查结束 ===="
  exit 1
}

main
