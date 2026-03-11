# Changelog

## 2026-03-11

- Simplified gateway self-healing to a single reliable path: `launchd`.
- Reworked `watchdog.sh` into a one-shot health check that inspects `launchctl` state and uses `launchctl kickstart -k` for recovery.
- Reworked `auto-fix.sh` into a manual recovery helper for a launchd-managed gateway.
- Fixed log collection to read the active gateway logs and kept compatibility with legacy `gateway.stdout.log` / `gateway.stderr.log`.
- Removed dependence on `pgrep -f openclaw-gateway`, which does not match the actual launchd-managed Node process shape used locally.
- Resulting operating model:
  - automatic recovery: `launchd`
  - manual health check: `watchdog.sh`
  - manual recovery: `auto-fix.sh`
