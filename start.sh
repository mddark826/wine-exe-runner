#!/bin/bash
# TEST: Traffic Spirit with winetricks vcrun2019 + corefonts
set -e

export DISPLAY=:99
export WINEPREFIX=/home/wineuser/.wine
export WINETRICKS_GUI=none

APP_EXE=/app/ipts/ipts.exe
APP_ARGS="--no-sandbox --disable-gpu --disable-dev-shm-usage"

# Initialize Wine prefix
if [ ! -f "$WINEPREFIX/system.reg" ]; then
  echo "First run: initializing Wine prefix..."
  wineboot --init >/tmp/wineboot.log 2>&1 || true
fi

# Winetricks: install vcrun2019 + corefonts (once)
if [ ! -f "$WINEPREFIX/.winetricks_done" ]; then
  echo "Installing winetricks components (vcrun2019, corefonts) - this takes a few minutes..."
  winetricks -q vcrun2019 corefonts >/tmp/winetricks.log 2>&1 || echo "WARNING: winetricks had errors, continuing"
  touch "$WINEPREFIX/.winetricks_done"
  echo "Winetricks done."
fi

# Windows 10 mode
wine reg add "HKCU\\Software\\Wine" /v Version /t REG_SZ /d win10 /f >/dev/null 2>&1 || true

echo "Starting virtual display..."
Xvfb :99 -screen 0 1280x800x24 >/tmp/xvfb.log 2>&1 &
sleep 2

echo "Starting VNC server..."
x11vnc -display :99 -nopw -listen localhost -forever -shared -rfbport 5900 -xkb -ncache 10 >/tmp/x11vnc.log 2>&1 &
sleep 2

if [ -f "$APP_EXE" ]; then
  echo "Launching $APP_EXE under Wine..."
  ( cd "$(dirname "$APP_EXE")" && wine "$APP_EXE" $APP_ARGS >/tmp/app.log 2>&1 &
    echo "Wine started (pid $!)." )
else
  echo "ERROR: $APP_EXE not found!"
  ( wine explorer >/tmp/app.log 2>&1 & )
fi

PORT=${PORT:-8080}
echo "Serving noVNC on port $PORT."
exec websockify --web /usr/share/novnc "$PORT" localhost:5900
