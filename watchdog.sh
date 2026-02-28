#!/bin/bash
# ~/.openclaw/watchdog.sh - OpenClaw macOS 看门狗

LOG_FILE="$HOME/.openclaw/logs/watchdog.log"
MAX_FAILURES=3
FAILURE_WINDOW=300  # 5分钟
CHECK_INTERVAL=60   # 每60秒检查一次

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_gateway() {
  if pgrep -f "openclaw-gateway" > /dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

record_failure() {
  echo "$(date +%s)" >> "$HOME/.openclaw/logs/failures.tmp"
}

get_recent_failures() {
  local now=$(date +%s)
  local cutoff=$((now - FAILURE_WINDOW))
  
  # 清理过期记录
  if [ -f "$HOME/.openclaw/logs/failures.tmp" ]; then
    awk -v cutoff="$cutoff" '$1 > cutoff' "$HOME/.openclaw/logs/failures.tmp" > "$HOME/.openclaw/logs/failures.tmp.new"
    mv "$HOME/.openclaw/logs/failures.tmp.new" "$HOME/.openclaw/logs/failures.tmp"
    wc -l < "$HOME/.openclaw/logs/failures.tmp"
  else
    echo "0"
  fi
}

trigger_fix() {
  log "⚠️ 连续失败 $MAX_FAILURES 次，触发 auto-fix..."
  bash "$HOME/.openclaw/auto-fix.sh" 2>&1 | tee -a "$HOME/.openclaw/logs/auto-fix.log"
}

fix_and_restart() {
  log "Gateway 未运行，尝试重启..."
  openclaw gateway start
  sleep 5
  
  if check_gateway; then
    log "✅ 重启成功"
    > "$HOME/.openclaw/logs/failures.tmp"  # 清空失败记录
  else
    log "❌ 重启失败"
    record_failure
    
    local failures=$(get_recent_failures)
    if [ "$failures" -ge "$MAX_FAILURES" ]; then
      trigger_fix
    fi
  fi
}

# 主逻辑
main() {
  log "==== 检查开始 ===="
  
  if check_gateway; then
    log "✅ Gateway 运行正常"
    [ -f "$HOME/.openclaw/logs/failures.tmp" ] && > "$HOME/.openclaw/logs/failures.tmp"
  else
    fix_and_restart
  fi
  
  log "==== 检查结束 ===="
}

main
