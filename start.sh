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

if [ -f /app/app.exe ]; then
  echo "Launching app.exe under Wine..."
  ( wine /app/app.exe 2>&1 | tee /tmp/app.log; echo "WINELAUNCH: wine exited with code ${PIPESTATUS[0]}" ) &
else
  echo "No app.exe found: opening Wine Explorer. Set the APP_URL variable or bake app.exe into the image and redeploy."
  ( wine explorer 2>&1 | tee /tmp/app.log ) &
fi

PORT=${PORT:-8080}
echo "Serving noVNC on port $PORT - open the Railway public domain in your browser."
exec websockify --web /usr/share/novnc "$PORT" localhost:5900
