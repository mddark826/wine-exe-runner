# Run a lightweight Windows .exe on Railway/Render using Wine + noVNC.
# Browser-based GUI: Xvfb (virtual display) -> x11vnc -> websockify/noVNC -> $PORT
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:99 \
    WINEPREFIX=/home/wineuser/.wine \
    WINEDEBUG=fixme-all,+err

# WineHQ (32-bit + 64-bit) + virtual display + VNC + noVNC web client
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

# App directory (the .exe goes here via APP_URL or baked COPY)
RUN useradd -m -s /bin/bash wineuser && \
    mkdir -p /app /home/wineuser/.wine && \
    chown -R wineuser:wineuser /app /home/wineuser

# OPTIONAL: bake your .exe into the image at build time.
# Uncomment and set the URL, or leave it and use the APP_URL variable at runtime.
# RUN curl -L --fail --retry 2 --max-time 600 -o /app/app.exe "https://example.com/your-app.exe" && \
#     chown wineuser:wineuser /app/app.exe

COPY start.sh /start.sh
RUN chmod +x /start.sh && chown wineuser:wineuser /start.sh

USER wineuser
WORKDIR /home/wineuser

EXPOSE 8080
CMD ["/start.sh"]
