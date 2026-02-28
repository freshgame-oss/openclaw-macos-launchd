# OpenClaw macOS Launchd 部署方案

> OpenClaw Gateway macOS 开机自启 + 崩溃自愈部署方案

## 特性

- ✅ 开机自启 (launchd RunAtLoad)
- ✅ 进程保活 (KeepAlive)
- ✅ 崩溃自动重启
- ✅ 连续失败触发自愈修复 (watchdog + auto-fix)
- ✅ Claude Code 诊断集成 (可选)

## 架构

```
┌─────────────────────────────────────┐
│         launchd                     │
│  (KeepAlive = true)                │
│  进程退出自动重启                   │
└─────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────┐
│      openclaw-gateway               │
│      OpenClaw 网关进程              │
└─────────────────────────────────────┘
                │
                ▼ (连续失败 3 次)
┌─────────────────────────────────────┐
│   watchdog.sh + auto-fix.sh        │
│        二级自愈修复                 │
└─────────────────────────────────────┘
```

## 快速开始

### 1. 安装 launchd

```bash
# 复制 plist
cp launchd/com.openclaw.gateway.plist ~/Library/LaunchAgents/

# 加载并启动
launchctl load ~/Library/LaunchAgents/com.openclaw.gateway.plist
launchctl start com.openclaw.gateway

# 验证
launchctl list | grep openclaw
ps aux | grep openclaw-gateway
```

### 2. 安装 watchdog (可选)

```bash
# 复制脚本
cp watchdog.sh ~/.openclaw/
cp auto-fix.sh ~/.openclaw/
chmod +x ~/.openclaw/watchdog.sh ~/.openclaw/auto-fix.sh

# 设置定时任务 (每分钟检查)
crontab -e
* * * * * /Users/minibot/.openclaw/watchdog.sh
```

### 3. 验证

```bash
# 查看进程
ps aux | grep openclaw-gateway

# 查看日志
tail -f ~/.openclaw/logs/gateway.stdout.log
tail -f ~/.openclaw/logs/gateway.stderr.log
tail -f ~/.openclaw/logs/watchdog.log
```

## 文件说明

| 文件 | 说明 |
|------|------|
| `launchd/com.openclaw.gateway.plist` | launchd 配置文件 |
| `watchdog.sh` | 看门狗脚本 (检测 + 触发修复) |
| `auto-fix.sh` | 自愈修复脚本 |
| `skills/openclaw-launchd/` | 打包好的 skill |

## 配置

### 日志位置

- Gateway stdout: `~/.openclaw/logs/gateway.stdout.log`
- Gateway stderr: `~/.openclaw/logs/gateway.stderr.log`
- Watchdog: `~/.openclaw/logs/watchdog.log`
- Auto-fix: `~/.openclaw/logs/auto-fix.log`

### 环境变量

| 变量 | 说明 |
|------|------|
| `OPENCLAW_FIX_NOTIFY` | 修复完成后通知目标 |

## 卸载

```bash
# 停止并卸载
launchctl stop com.openclaw.gateway
launchctl unload ~/Library/LaunchAgents/com.openclaw.gateway.plist

# 删除文件
rm ~/Library/LaunchAgents/com.openclaw.gateway.plist
rm -rf ~/.openclaw/watchdog.sh ~/.openclaw/auto-fix.sh
```

## 依赖

- macOS (使用 launchd)
- OpenClaw 已安装 (`openclaw` CLI)
- 可选: Claude Code (`claude` CLI) 用于诊断

## License

MIT
