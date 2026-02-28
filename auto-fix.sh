#!/bin/bash
# ~/.openclaw/auto-fix.sh - OpenClaw 自愈修复脚本

LOG_FILE="$HOME/.openclaw/logs/auto-fix.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "========== 开始自愈修复 =========="

# 1. 收集错误日志
log "收集最近错误日志..."
if [ -f "$HOME/.openclaw/logs/gateway.stderr.log" ]; then
  tail -50 "$HOME/.openclaw/logs/gateway.stderr.log" >> "$LOG_FILE" 2>&1
fi

# 2. 检查 openclaw CLI
if ! command -v openclaw &> /dev/null; then
  log "❌ openclaw CLI 未找到"
  exit 1
fi

# 3. 尝试 Claude Code 修复 (如果可用, 30秒超时)
if command -v claude &> /dev/null; then
  log "调用 Claude Code 进行诊断..."
  # 只做简单诊断，不做自动修复（太危险）
  DIAG_RESULT=$(timeout 30 claude -p "OpenClaw Gateway 启动失败，请给出3个最可能的原因和修复步骤:" --max-turns 1 2>&1 | head -20)
  log "诊断结果: $DIAG_RESULT"
fi

# 4. 强制杀死可能残留的进程
log "清理残留进程..."
pkill -f "openclaw-gateway" 2>/dev/null || true
sleep 2

# 5. 重启 Gateway
log "重启 Gateway..."
openclaw gateway start
sleep 5

# 6. 验证
if pgrep -f "openclaw-gateway" > /dev/null 2>&1; then
  log "✅ 自愈成功"
  
  # 可选: 发送通知
  if [ -n "$OPENCLAW_FIX_NOTIFY" ]; then
    log "发送通知到: $OPENCLAW_FIX_NOTIFY"
  fi
else
  log "❌ 自愈失败，请人工介入"
  
  # 输出完整日志供调试
  log "--- 完整日志 ---"
  cat "$HOME/.openclaw/logs/gateway.stderr.log" >> "$LOG_FILE" 2>&1 || true
  cat "$HOME/.openclaw/logs/gateway.stdout.log" >> "$LOG_FILE" 2>&1 || true
fi

log "========== 自愈修复结束 =========="
