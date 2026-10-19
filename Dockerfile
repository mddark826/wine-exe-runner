# TEST: Full Traffic Spirit + winetricks (vcrun2019, corefonts) on Render
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:99 \
    WINEPREFIX=/home/wineuser/.wine \
    WINEDEBUG=fixme-all,+err \
    WINETRICKS_GUI=none

# WineHQ + tools + p7zip for ipts.7z extraction
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends wget gnupg ca-certificates && \
    mkdir -pm755 /etc/apt/keyrings && \
    wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key && \
    wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/bookworm/winehq-bookworm.sources && \
    apt-get update && \
    apt-get install -y --install-recommends winehq-stable && \
    apt-get install -y --no-install-recommends \
        xvfb x11vnc novnc websockify curl cabextract p7zip-full && \
    wget -O /usr/local/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks && \
    chmod +x /usr/local/bin/winetricks && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash wineuser && \
    mkdir -p /app/ipts /home/wineuser/.wine && \
    chown -R wineuser:wineuser /app /home/wineuser

# Bake FULL Traffic Spirit package
RUN (curl -L --fail --retry 2 --max-time 900 -o /tmp/ipts.7z "http://dlc.ipts.com/v5/ipts.7z" && \
    7z x -p"ipts123" -o/app/ipts /tmp/ipts.7z >/dev/null && \
    rm -f /tmp/ipts.7z && \
    chown -R wineuser:wineuser /app/ipts && \
    echo "Baked Traffic Spirit") || echo "WARNING: bake failed"

COPY start.sh /start.sh
RUN chmod +x /start.sh && chown wineuser:wineuser /start.sh

USER wineuser
WORKDIR /home/wineuser

EXPOSE 8080
CMD ["/start.sh"]
