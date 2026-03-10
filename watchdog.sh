#!/bin/bash
# ~/.openclaw/scripts/monitor-gateway.sh - OpenClaw Gateway 监控脚本 (优化版)

MAX_FAILURES=3
FAILURE_WINDOW=300  # 5分钟窗口
CHECK_INTERVAL=60   # 每60秒检查一次

LOG_FILE="$HOME/.openclaw/logs/gateway-monitor.log"
FAILURE_FILE="$HOME/.openclaw/logs/failure-count"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_gateway() {
  # 方法1: 检查进程
  if pgrep -f "openclaw-gateway" > /dev/null 2>&1; then
    return 0
  fi
  
  # 方法2: 检查 API 响应 (更可靠)
  if curl -s --max-time 3 http://127.0.0.1:18789/health > /dev/null 2>&1; then
    return 0
  fi
  
  return 1
}

get_failure_count() {
  if [ -f "$FAILURE_FILE" ]; then
    local last_time=$(cat "$FAILURE_FILE" | head -1)
    local now=$(date +%s)
    # 超过窗口期，重置计数
    if [ $((now - last_time)) -gt $FAILURE_WINDOW ]; then
      echo "0"
    else
      cat "$FAILURE_FILE" | tail -1
    fi
  else
    echo "0"
  fi
}

record_failure() {
  local now=$(date +%s)
  echo "$now" > "$FAILURE_FILE"
  local count=$(get_failure_count)
  echo "$((count + 1))" >> "$FAILURE_FILE"
}

trigger_fix() {
  log "⚠️ 连续失败 $MAX_FAILURES 次，触发 auto-fix..."
  if [ -f "$HOME/.openclaw/scripts/auto-fix.sh" ]; then
    bash "$HOME/.openclaw/scripts/auto-fix.sh" 2>&1 | tee -a "$HOME/.openclaw/logs/auto-fix.log"
  else
    log "❌ auto-fix.sh 不存在，跳过"
  fi
}

fix_and_restart() {
  local failures=$(get_failure_count)
  log "⚠️ Gateway 检查失败 (连续失败: $failures 次)"
  
  if [ "$failures" -ge "2" ]; then
    log "🔧 尝试重启 Gateway..."
    openclaw gateway restart 2>&1 | tee -a "$LOG_FILE"
    sleep 8
  fi
  
  if check_gateway; then
    log "✅ Gateway 恢复运行"
    # 重置计数
    rm -f "$FAILURE_FILE"
  else
    record_failure
    local new_count=$(get_failure_count)
    
    if [ "$new_count" -ge "$MAX_FAILURES" ]; then
      trigger_fix
      rm -f "$FAILURE_FILE"  # 重置
    else
      log "⏳ 等待下次检查... ($new_count/$MAX_FAILURES)"
    fi
  fi
}

main() {
  log "==== 检查开始 ===="
  
  if check_gateway; then
    log "✅ Gateway 运行正常"
    # 正常时清理失败记录
    [ -f "$FAILURE_FILE" ] && rm -f "$FAILURE_FILE"
  else
    fix_and_restart
  fi
  
  log "==== 检查结束 ===="
}

main
