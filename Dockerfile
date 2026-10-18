# Run a Windows .exe on Railway using Wine + noVNC (browser-based desktop)
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:99 \
    WINEPREFIX=/home/wineuser/.wine \
    WINEDEBUG=fixme-all,+err \
    LANG=zh_CN.UTF-8 \
    LC_ALL=zh_CN.UTF-8

# WineHQ (32-bit + 64-bit Wine) + virtual display + VNC + noVNC web client
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends wget gnupg ca-certificates && \
    mkdir -pm755 /etc/apt/keyrings && \
    wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key && \
    wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/bookworm/winehq-bookworm.sources && \
    apt-get update && \
    apt-get install -y --install-recommends winehq-stable && \
    apt-get install -y --no-install-recommends \
        xvfb x11vnc novnc websockify curl cabextract x11-utils procps p7zip-full \
        fonts-wqy-zenhei fonts-wqy-microhei locales && \
    sed -i 's/# zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen zh_CN.UTF-8 && \
    wget -O /usr/local/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks && \
    chmod +x /usr/local/bin/winetricks && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# App directory
RUN useradd -m -s /bin/bash wineuser && \
    mkdir -p /app /home/wineuser/.wine && \
    chown -R wineuser:wineuser /app /home/wineuser

# Bake the FULL Traffic Spirit package (exe + support files) into the image.
# Download the official 7z, extract with the published password to /app/ipts/.
# Non-fatal: APP_URL runtime download is the fallback.
# NOTE: the download URL below is visible to anyone who can see this public repo.
RUN mkdir -p /app/ipts && \
    (curl -L --fail --retry 2 --max-time 900 -o /tmp/ipts.7z "http://dlc.ipts.com/v5/ipts.7z" && \
    7z x -p"ipts123" -o/app/ipts /tmp/ipts.7z >/dev/null && \
    rm -f /tmp/ipts.7z && \
    chown -R wineuser:wineuser /app/ipts && \
    ls /app/ipts && \
    echo "Baked Traffic Spirit into /app/ipts") || \
    echo "WARNING: Traffic Spirit download/extract failed; will try APP_URL at runtime"

COPY start.sh /start.sh
RUN chmod +x /start.sh && chown wineuser:wineuser /start.sh

USER wineuser
WORKDIR /home/wineuser

EXPOSE 8080
CMD ["/start.sh"]
