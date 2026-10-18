# .exe Runner on Railway (Wine + noVNC)

Run a Windows `.exe` in the cloud and use it from your browser — no Windows license needed.
It uses **Wine** (Windows compatibility layer on Linux) inside Docker, with the app's
window streamed to your browser via **noVNC**.

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/new/template?template=https%3A%2F%2Fgithub.com%2Fmddark826%2Fwine-exe-runner)

👆 Click the button above — Railway clones this repo and deploys it automatically.
Then follow step 3 below.

## Deploy (2 minutes)

1. Click **Deploy on Railway** above (or: railway.app → New Project → Deploy from
   GitHub repo → select this repo).
2. Wait for the Docker build to finish (a few minutes — it installs Wine and
   downloads the `.exe`).
3. Click the service → **Settings** → **Networking** → **Generate Domain**.
4. Open the generated `https://....up.railway.app/vnc.html` URL → click **Connect** →
   your app's window appears. Click/tap to interact.

> Tip: open `/vnc.html` directly (not the bare domain) to land on the noVNC client.

## Getting your .exe into it (pick one)

**Option A — download link (easiest, no rebuild):**
Service → **Variables** → add `APP_URL` = direct download link of your `.exe`
(e.g. `https://example.com/myapp.exe`), then **Redeploy**. The container downloads
it on startup and launches it under Wine.

**Option B — baked into the image at build time (default):**
The `Dockerfile` already downloads the `.exe` during the image build (see the
`curl` step in it). To use a different `.exe`, change that URL and push — Railway
rebuilds automatically. This also helps on Railway accounts with restricted
outbound network, where the runtime download cannot reach the internet.

## App won't display? (black window fix)

Many modern apps are **Chromium/Electron/CEF-based** — under Wine with no GPU they
render a black window or crash. `start.sh` already launches the app with the
standard workaround flags:

```
--no-sandbox --disable-gpu --disable-dev-shm-usage
```

To customize, set the `APP_ARGS` variable on the service (empty it with a single
space if your app dislikes flags). Plain non-Chromium apps simply ignore unknown
flags, so the defaults are safe.

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
