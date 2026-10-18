# .exe Runner on Railway (Wine + noVNC)

Run a Windows `.exe` in the cloud and use it from your browser — no Windows license needed.
It uses **Wine** (Windows compatibility layer on Linux) inside Docker, with the app's
window streamed to your browser via **noVNC**.

## Deploy to Railway (2 minutes)

1. Go to [railway.app](https://railway.app) → **New Project** → **Deploy from GitHub repo**
2. Select this repo (`wine-exe-runner`) → **Deploy**
3. When the build finishes: click the service → **Settings** → **Networking** →
   **Generate Domain**
4. Open the generated `https://....up.railway.app` URL in your browser → your app's
   window appears. Click/tap to interact.

## Getting your .exe into it (pick one)

**Option A — download link (easiest, no rebuild):**
Service → **Variables** → add `APP_URL` = direct download link of your `.exe`
(e.g. `https://example.com/myapp.exe`), then **Redeploy**. The container downloads
it on startup and launches it under Wine.

**Option B — bake into the image:**
Put your file at `app/app.exe` in this repo, uncomment the two `COPY` lines in the
`Dockerfile`, commit, and Railway rebuilds automatically.

## How it works

```
browser ──HTTPS──> Railway ──> noVNC (websockify :$PORT) ──> x11vnc ──> Xvfb ──> Wine ──> app.exe
```

- `Dockerfile` — Debian + WineHQ (32/64-bit), Xvfb, x11vnc, noVNC
- `start.sh` — boots the virtual display, VNC, Wine prefix, your app, and the web client
  on Railway's `$PORT`

## Honest limitations (read before relying on this)

- **Not every .exe runs under Wine.** Simple apps usually work; apps with kernel
  drivers, anticheat, or deep Windows integration often don't. Test yours.
- **GUI over the browser is laggy** compared to a real Windows desktop — fine for
  clicking through an app, not for gaming/video.
- **Railway is not free:** one-time $5 trial credit (30 days), then paid plans
  (Hobby $5/month). Trial services are capped at 2 vCPU / 1 GB RAM.
- **No persistence:** files saved inside the container disappear on redeploy.
  Mount a Railway volume if you need files to survive.
- If your app needs extra Windows components (fonts, .NET, Visual C++ runtimes),
  install them with `winetricks` — open a shell in the running container, or extend
  the Dockerfile.

## Why not full Windows on Railway?

Windows needs `/dev/kvm` (hardware virtualization). Railway's shared containers don't
provide it — a real Windows VM there would be unusably slow even if it booted.
Wine sidesteps this: no VM, the `.exe` runs as a Linux process.
