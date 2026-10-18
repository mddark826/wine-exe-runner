# Run a Windows .exe on Railway using Wine + noVNC (browser-based desktop)
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:99 \
    WINEPREFIX=/home/wineuser/.wine \
    WINEDEBUG=-all

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
        xvfb x11vnc novnc websockify curl cabextract && \
    wget -O /usr/local/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks && \
    chmod +x /usr/local/bin/winetricks && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# App directory (put your .exe here as app.exe, or set APP_URL at runtime)
RUN useradd -m -s /bin/bash wineuser && \
    mkdir -p /app /home/wineuser/.wine && \
    chown -R wineuser:wineuser /app /home/wineuser

COPY start.sh /start.sh
RUN chmod +x /start.sh && chown wineuser:wineuser /start.sh

# Optional: bake your .exe into the image (uncomment after adding app/app.exe)
# COPY app/app.exe /app/app.exe
# RUN chown wineuser:wineuser /app/app.exe

USER wineuser
WORKDIR /home/wineuser

EXPOSE 8080
CMD ["/start.sh"]
