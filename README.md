# Lightweight .exe Runner on Railway / Render (Wine + noVNC)

Run a **lightweight** Windows `.exe` in the cloud and use it from your browser.
Uses **Wine** on Linux inside Docker; the app's window is streamed to your browser
via **noVNC**. No Windows license needed.

> **Scope:** simple Win32 GUI utilities (PuTTY, Notepad++, small tools).
> Heavy Chromium/Electron apps, games, and anything needing drivers/anticheat
> will not work reliably under Wine — see *Limitations* below.

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/new/template?template=https%3A%2F%2Fgithub.com%2Fmddark826%2Fwine-exe-runner)

## Deploy

**Railway** (recommended — no sleep on trial, 0.5GB RAM per service is enough):
1. Click **Deploy on Railway** above, or: railway.app → New Project → Deploy from GitHub repo → select this repo.
2. Wait for the Docker build (~3-5 min).
3. Service → **Variables** → add `APP_URL` = direct download link of your `.exe`
   (must be a **direct** link, not a Google Drive preview page).
4. Service → **Settings** → **Networking** → **Generate Domain**.
5. Open `https://....up.railway.app/vnc.html` → click **Connect** → your app appears.

**Render** (free, no card — but sleeps after 15 min idle):
1. render.com → New → Web Service → connect this repo (Docker runtime auto-detected).
2. Add environment variable `APP_URL` = direct `.exe` link.
3. Deploy, open the `https://....onrender.com/vnc.html` URL → **Connect**.
4. Note: free services sleep after 15 min idle; first load after sleep takes ~60s.

## Configuration (environment variables)

| Variable  | Required | Purpose |
|-----------|----------|---------|
| `APP_URL` | Yes (or bake the exe) | Direct download URL of the `.exe` |
| `APP_EXE` | No | Path of exe to run (default `/app/app.exe`) |
| `APP_ARGS`| No | Extra CLI flags (default `--no-sandbox --disable-gpu --disable-dev-shm-usage`, helps Chromium-based apps; ignored by others) |

Alternative: bake the `.exe` into the image — uncomment the `curl` step in the
`Dockerfile`, set your URL, push.

## Verified working (tested under Wine + Xvfb headless)

- **Notepad++** portable (x64) — window renders, no errors ✅
- **PuTTY** (x64) — launches ✅

## Known NOT working

- **Traffic Spirit** (Chromium-based, 142MB) — crashes under Wine with a page
  fault; app-specific incompatibility, not an infra problem.

## How it works

```
browser ──HTTPS──> Railway/Render ──> noVNC (websockify :$PORT) ──> x11vnc ──> Xvfb (:99) ──> Wine ──> your .exe
```

## Honest limitations

- **Wine ≠ Windows.** Check [Wine AppDB](https://appdb.winehq.org/) for your app.
  Simple Win32 apps usually work; .NET apps may need `winetricks dotnet48`;
  drivers, anticheat, and deep OS integration do not work.
- **RAM:** Wine + app needs ~200-300MB. Fine on Railway trial; tight but OK on
  Render's 512MB free tier for light apps.
- **No GPU.** Anything needing 3D acceleration will fail or fall back to software.
- **Laggy GUI** over the browser vs a real desktop — fine for utilities.
- **No persistence.** Files in the container vanish on redeploy.
- **Render sleeps** after 15 min idle (cold start ~60s).
