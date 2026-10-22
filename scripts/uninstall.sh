#!/bin/zsh
set -euo pipefail
LABEL="local.philip.LogoerZoom"
DOMAIN="gui/$(id -u)"
BASE="$HOME/Library/Application Support/Logoer-size-adjustment"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
if launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1; then
    launchctl bootout "$DOMAIN/$LABEL"
fi
for PID in $(pgrep -f "$BASE/LogoerZoom.app/Contents/MacOS/LogoerZoom" || true); do
    kill -TERM "$PID"
done
if [[ -f "$PLIST" ]]; then
    BACKUP="$BASE/Backups/disabled-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP"
    mv "$PLIST" "$BACKUP/"
fi
print '已停止 LogoerZoom 并关闭登录启动。应用和备份保留，Logoer 恢复原图标大小。'
