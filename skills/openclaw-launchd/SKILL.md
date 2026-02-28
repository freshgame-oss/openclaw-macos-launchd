---
name: openclaw-launchd
version: 1.0.0
description: |
  OpenClaw Gateway macOS launchd 部署与自愈方案。使用 launchd KeepAlive 保活，
  配合 watchdog + auto-fix 脚本实现二级防护。适用于 Mac Mini/Mac 等 macOS 设备。
allowed-tools:
  - Read
  - Write
  - Edit
  - Exec
  - AskUserQuestion
---

# OpenClaw macOS Launchd 部署方案

## 概述

本方案将 OpenClaw Gateway 部署为 macOS launchd 用户服务，实现：
- 开机自启
- 进程保活 (KeepAlive)
- 崩溃自动重启
- 连续失败触发自愈修复

## 架构

```
┌─────────────────────────────────────────────────────┐
│                   launchd                            │
│  (KeepAlive = true, 自动重启崩溃进程)                │
└─────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│               openclaw-gateway                       │
│               (OpenClaw 网关进程)                     │
└─────────────────────────────────────────────────────┘
                         │
                         ▼ (连续失败 3 次)
┌─────────────────────────────────────────────────────┐
│              watchdog.sh + auto-fix.sh               │
│              (二级自愈修复)                           │
└─────────────────────────────────────────────────────┘
```

## 组件

### 1. LaunchAgent Plist

负责基础保活：
- `KeepAlive`: true — 进程退出后自动重启
- `RunAtLoad`: true — 开机自启
- `ThrottleInterval`: 10 — 失败后 10 秒内不再重试

### 2. watchdog.sh

定时检查脚本（建议 cron 每分钟执行）：
- 检测 Gateway 进程状态
- 记录失败次数
- 连续失败 3 次触发 auto-fix.sh

### 3. auto-fix.sh

自愈修复脚本：
- 收集错误日志
- 调用 Claude Code 诊断（可选）
- 清理残留进程
- 重启 Gateway

## 部署步骤

### Step 1: 安装 LaunchAgent

```bash
# 复制 plist 到 LaunchAgents 目录
cp launchd/com.openclaw.gateway.plist ~/Library/LaunchAgents/

# 加载服务
launchctl load ~/Library/LaunchAgents/com.openclaw.gateway.plist

# 启动服务
launchctl start com.openclaw.gateway

# 验证状态
launchctl list | grep openclaw
```

### Step 2: 安装 watchdog（可选）

```bash
# 复制脚本
cp watchdog.sh ~/.openclaw/
cp auto-fix.sh ~/.openclaw/
chmod +x ~/.openclaw/watchdog.sh ~/.openclaw/auto-fix.sh

# 设置定时任务（每分钟检查）
crontab -e
* * * * * /Users/minibot/.openclaw/watchdog.sh
```

### Step 3: 验证

```bash
# 查看进程
ps aux | grep openclaw-gateway

# 查看日志
tail -f ~/.openclaw/logs/gateway.stdout.log
tail -f ~/.openclaw/logs/gateway.stderr.log
```

## 配置

### 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `OPENCLAW_FIX_NOTIFY` | 修复完成后通知目标 | - |

### 日志位置

- Gateway stdout: `~/.openclaw/logs/gateway.stdout.log`
- Gateway stderr: `~/.openclaw/logs/gateway.stderr.log`
- Watchdog: `~/.openclaw/logs/watchdog.log`
- Auto-fix: `~/.openclaw/logs/auto-fix.log`

## 注意事项

1. **路径硬编码**: plist 中的路径 `/opt/homebrew/bin/openclaw` 需根据实际调整
2. **ThrottleInterval**: 设为 10 秒防止频繁重启
3. **watchdog 冗余**: launchd 本身已足够，watchdog 是额外保险
4. **权限**: 脚本需有执行权限 `chmod +x`

## 卸载

```bash
# 停止并卸载 LaunchAgent
launchctl stop com.openclaw.gateway
launchctl unload ~/Library/LaunchAgents/com.openclaw.gateway.plist

# 删除文件
rm ~/Library/LaunchAgents/com.openclaw.gateway.plist
rm -rf ~/.openclaw/watchdog.sh ~/.openclaw/auto-fix.sh
rm -rf ~/.openclaw/logs/
```

## 文件清单

```
openclaw-macos-bundle/
├── SKILL.md                    # 本文档
├── launchd/
│   └── com.openclaw.gateway.plist
├── watchdog.sh
└── auto-fix.sh
```
