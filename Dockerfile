# syntax=docker/dockerfile:1
# Web-based Linux Desktop ("Cloud PC"): XFCE4 + Chromium + Terminal + File Manager + Text Editor,
# served to any browser through noVNC (HTML5 VNC client) on the port given by $PORT.
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    PORT=8080 \
    RESOLUTION=1280x800x24 \
    LANG=C.UTF-8

# Desktop, VNC stack, apps and tools. --no-install-recommends keeps the image smaller.
RUN apt-get update && apt-get install -y --no-install-recommends \
      xvfb x11vnc websockify novnc \
      xfce4 xfce4-terminal thunar mousepad \
      chromium \
      dbus-x11 tini sudo curl ca-certificates \
      fonts-dejavu-core fonts-liberation \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Chromium flags for containers. Debian's chromium wrapper reads /etc/chromium.d/*.
# Chromium's own sandbox needs privileges most containers lack, so it is disabled here.
# The container is the isolation boundary instead.
RUN mkdir -p /etc/chromium.d && printf '%s\n' \
    'export CHROMIUM_FLAGS="$CHROMIUM_FLAGS --no-sandbox --disable-dev-shm-usage --disable-gpu --no-first-run --no-default-browser-check"' \
    > /etc/chromium.d/container-flags

# noVNC landing page: opening the root URL goes straight to the desktop with auto-connect.
RUN printf '%s\n' '<!doctype html><meta charset="utf-8"><meta http-equiv="refresh" content="0; url=vnc.html?autoconnect=1&amp;resize=scale">' \
    > /usr/share/novnc/index.html

# Non-root desktop user with passwordless sudo (remove the sudoers line if you don't want it).
RUN useradd -m -u 1000 -s /bin/bash desktop \
 && echo 'desktop ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/desktop \
 && chmod 0440 /etc/sudoers.d/desktop

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh

USER desktop
WORKDIR /home/desktop

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -fsS "http://localhost:${PORT}/" > /dev/null || exit 1

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
