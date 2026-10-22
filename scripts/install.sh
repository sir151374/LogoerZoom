#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
./scripts/build.sh
BASE="$HOME/Library/Application Support/Logoer-size-adjustment"
APP="$BASE/LogoerZoom.app"
LABEL="local.philip.LogoerZoom"
DOMAIN="gui/$(id -u)"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
if launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1; then
    launchctl bootout "$DOMAIN/$LABEL"
fi
for PID in $(pgrep -f "$APP/Contents/MacOS/LogoerZoom" || true); do
    kill -TERM "$PID"
done
if [[ -d "$APP" ]]; then
    BACKUP="$BASE/Backups/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP"
    ditto "$APP" "$BACKUP/LogoerZoom.app"
fi
mkdir -p "$BASE" "$HOME/Library/LaunchAgents"
ditto build/LogoerZoom.app "$APP"
python3 - "$APP" "$PLIST" "$LABEL" <<'PY'
import plistlib, sys
app, target, label = sys.argv[1:]
with open(target, 'wb') as file:
    plistlib.dump({
        'Label': label,
        'ProgramArguments': [app + '/Contents/MacOS/LogoerZoom'],
        'RunAtLoad': True,
        'KeepAlive': True,
        'ProcessType': 'Interactive',
    }, file)
PY
plutil -lint "$PLIST"
launchctl bootstrap "$DOMAIN" "$PLIST"
print '已安装并启用 LogoerZoom 登录启动。请在 Logoer 中启用华为图标。'
