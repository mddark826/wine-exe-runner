#!/bin/bash
# Startup: virtual display -> VNC -> Wine app -> noVNC web client on $PORT
set -e

export DISPLAY=:99
export WINEPREFIX=/home/wineuser/.wine

mkdir -p /app

# Resolve which exe to launch (override with APP_EXE).
# Default: baked full Traffic Spirit package if present, else /app/app.exe
# (used by the APP_URL download path and legacy single-exe bakes).
if [ -z "${APP_EXE:-}" ]; then
  if [ -f /app/ipts/ipts.exe ]; then
    APP_EXE=/app/ipts/ipts.exe
  else
    APP_EXE=/app/app.exe
  fi
fi

# Fetch the .exe at runtime if APP_URL is set and the target exe is missing.
# Non-fatal: a failed download must never kill the container (would cause a crash loop).
if [ ! -f "$APP_EXE" ] && [ -n "${APP_URL:-}" ]; then
  echo "Downloading $(basename "$APP_EXE") from APP_URL..."
  if curl -L --fail --retry 3 --max-time 900 -o "$APP_EXE" "$APP_URL"; then
    echo "Download complete."
  else
    echo "WARNING: download failed; continuing without it."
    rm -f "$APP_EXE"
  fi
fi

# Initialize the Wine prefix on first run
if [ ! -f "$WINEPREFIX/system.reg" ]; then
  echo "First run: initializing Wine prefix (about a minute)..."
  wineboot --init >/tmp/wineboot.log 2>&1 || true
fi

# Emulate Windows 10 (some apps crash on Wine's default Win7 mode)
wine reg add "HKEY_CURRENT_USER\\Software\\Wine" /v Version /t REG_SZ /d "win10" /f >/dev/null 2>&1 || true

echo "Starting virtual display..."
Xvfb :99 -screen 0 1280x800x24 >/tmp/xvfb.log 2>&1 &
sleep 2

echo "Starting VNC server..."
x11vnc -display :99 -nopw -listen localhost -forever -shared -rfbport 5900 -xkb -ncache 10 >/tmp/x11vnc.log 2>&1 &
sleep 2

# Extra command-line flags for the .exe. Override with the APP_ARGS variable.
# Defaults fix Chromium/Electron/CEF-based apps under Wine+Xvfb (no GPU here,
# and Chromium's sandbox fails under Wine -> black window or instant crash).
# Plain Windows apps simply ignore unknown flags, so these defaults are safe.
APP_ARGS=${APP_ARGS:---no-sandbox --disable-gpu --disable-dev-shm-usage}

if [ -f "$APP_EXE" ]; then
  echo "Launching $APP_EXE under Wine..."
  # shellcheck disable=SC2086
  ( cd "$(dirname "$APP_EXE")" && wine "$APP_EXE" $APP_ARGS 2>&1 | tee /tmp/app.log; echo "WINELAUNCH: wine exited with code ${PIPESTATUS[0]}" ) &
else
  echo "No exe found (tried $APP_EXE): opening Wine Explorer. Set APP_URL/APP_EXE or rebake the image."
  ( wine explorer 2>&1 | tee /tmp/app.log ) &
fi

# Diagnostic loop: every 60s log processes + X window tree (10 rounds).
# Shows in container logs; tells us if the app created any window at all.
( for i in $(seq 1 10); do
    sleep 60
    echo "=== DIAG $i ==="
    echo "--- wine processes ---"
    ps aux | grep -E "wine|app\.exe" | grep -v grep | awk '{print $2, $11, $12, $13}' | head -15
    echo "--- X windows on :99 ---"
    xwininfo -root -tree 2>&1 | grep -E "0x[0-9a-f]+" | head -25
  done ) &

PORT=${PORT:-8080}
echo "Serving noVNC on port $PORT - open the Railway public domain in your browser."
exec websockify --web /usr/share/novnc "$PORT" localhost:5900
