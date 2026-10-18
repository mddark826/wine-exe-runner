#!/bin/bash
# Startup: virtual display -> VNC -> Wine app -> noVNC web client on $PORT
# Works on Railway and Render (both inject $PORT).
set -e

export DISPLAY=:99
export WINEPREFIX=/home/wineuser/.wine

mkdir -p /app

# Which exe to run. Override with APP_EXE. Default: /app/app.exe
APP_EXE=${APP_EXE:-/app/app.exe}

# Fetch the .exe at runtime if APP_URL is set and the exe is missing.
# Non-fatal: a failed download must never kill the container.
if [ ! -f "$APP_EXE" ] && [ -n "${APP_URL:-}" ]; then
  echo "Downloading $(basename "$APP_EXE") from APP_URL..."
  if curl -L --fail --retry 3 --max-time 900 -o "$APP_EXE" "$APP_URL"; then
    echo "Download complete."
    chown "$(id -u):$(id -g)" "$APP_EXE" 2>/dev/null || true
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

echo "Starting virtual display..."
Xvfb :99 -screen 0 1280x800x24 >/tmp/xvfb.log 2>&1 &
sleep 2

echo "Starting VNC server..."
x11vnc -display :99 -nopw -listen localhost -forever -shared -rfbport 5900 -xkb -ncache 10 >/tmp/x11vnc.log 2>&1 &
sleep 2

# Extra flags for the exe (override with APP_ARGS).
# Defaults help Chromium/Electron apps under Wine+Xvfb; harmless for other apps
# (plain Win32 apps ignore unknown flags).
APP_ARGS=${APP_ARGS:---no-sandbox --disable-gpu --disable-dev-shm-usage}

if [ -f "$APP_EXE" ]; then
  echo "Launching $APP_EXE under Wine..."
  # shellcheck disable=SC2086
  ( cd "$(dirname "$APP_EXE")" && wine "$APP_EXE" $APP_ARGS >/tmp/app.log 2>&1 &
    echo "Wine started (pid $!); tail /tmp/app.log for output." )
else
  echo "No exe found at $APP_EXE."
  echo "Set APP_URL to a direct .exe download link (Variables tab), or bake the exe into the image."
  ( wine explorer >/tmp/app.log 2>&1 & )
fi

PORT=${PORT:-8080}
echo "Serving noVNC on port $PORT - open the public domain in your browser (append /vnc.html)."
exec websockify --web /usr/share/novnc "$PORT" localhost:5900
