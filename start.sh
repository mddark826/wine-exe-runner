#!/bin/bash
# Startup: virtual display -> VNC -> Wine app -> noVNC web client on $PORT
set -e

export DISPLAY=:99
export WINEPREFIX=/home/wineuser/.wine

mkdir -p /app

# Fetch the .exe at runtime if APP_URL is set and no app.exe exists yet.
# Non-fatal: a failed download must never kill the container (would cause a crash loop).
if [ ! -f /app/app.exe ] && [ -n "$APP_URL" ]; then
  echo "Downloading app.exe from APP_URL..."
  if curl -L --fail --retry 3 --max-time 900 -o /app/app.exe "$APP_URL"; then
    echo "Download complete."
  else
    echo "WARNING: app.exe download failed; continuing without it."
    rm -f /app/app.exe
  fi
fi

# Initialize the Wine prefix on first run
if [ ! -f "$WINEPREFIX/system.reg" ]; then
  echo "First run: initializing Wine prefix (about a minute)..."
  wineboot --init >/tmp/wineboot.log 2>&1 || true
fi

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

if [ -f /app/app.exe ]; then
  echo "Launching app.exe under Wine..."
  # shellcheck disable=SC2086
  ( wine /app/app.exe $APP_ARGS 2>&1 | tee /tmp/app.log; echo "WINELAUNCH: wine exited with code ${PIPESTATUS[0]}" ) &
else
  echo "No app.exe found: opening Wine Explorer. Set the APP_URL variable or bake app.exe into the image and redeploy."
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
