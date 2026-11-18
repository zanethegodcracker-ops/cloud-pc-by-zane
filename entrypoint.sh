#!/bin/bash
# Starts: Xvfb (virtual display) -> D-Bus + XFCE4 desktop -> x11vnc (localhost only)
#         -> noVNC via websockify on $PORT (the only public entry point).
set -eu

PORT="${PORT:-8080}"
RESOLUTION="${RESOLUTION:-1280x800x24}"
DISPLAY_NUM=":1"
VNC_INTERNAL_PORT=5900

export DISPLAY="$DISPLAY_NUM"
export HOME="/home/desktop"
export XDG_RUNTIME_DIR="/tmp/runtime-$(id -u)"
export XDG_CONFIG_HOME="$HOME/.config"

log() { echo "[cloud-pc] $*"; }

# 1. Runtime directory required by desktop apps
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"

# 2. VNC password. Classic VNC authentication only uses the first 8 characters.
if [ -z "${VNC_PASSWORD:-}" ]; then
  VNC_PASSWORD="$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')"
  log "VNC_PASSWORD not set. Generated one for this run: $VNC_PASSWORD"
  log "Set VNC_PASSWORD in your host's environment settings to keep a fixed password."
fi
if [ "${#VNC_PASSWORD}" -gt 8 ]; then
  log "WARNING: VNC only uses the first 8 characters of VNC_PASSWORD."
fi
x11vnc -storepasswd "$VNC_PASSWORD" /tmp/vncpasswd >/dev/null 2>&1
chmod 600 /tmp/vncpasswd

# 3. Remove a stale X lock from a previous run
rm -f /tmp/.X1-lock 2>/dev/null || true

# 4. Virtual display
Xvfb "$DISPLAY_NUM" -screen 0 "$RESOLUTION" -ac +extension RANDR -nolisten tcp -noreset \
  >/tmp/xvfb.log 2>&1 &
XVFB_PID=$!
for _ in $(seq 1 50); do
  [ -S "/tmp/.X11-unix/X${DISPLAY_NUM#:}" ] && break
  sleep 0.2
done
if ! kill -0 "$XVFB_PID" 2>/dev/null; then
  log "Xvfb failed to start. Check RESOLUTION (format WIDTHxHEIGHTxDEPTH, e.g. 1280x800x24)."
  cat /tmp/xvfb.log
  exit 1
fi
log "Virtual display $DISPLAY_NUM at $RESOLUTION"

# 5. Desktop shortcuts (created only once, so your changes survive restarts)
mkdir -p "$HOME/Desktop" "$HOME/.config"
make_launcher() {
  f="$HOME/Desktop/$1.desktop"
  [ -f "$f" ] && return 0
  cat > "$f" <<LAUNCHER_END
[Desktop Entry]
Type=Application
Name=$1
Exec=$2
Icon=$3
Terminal=false
LAUNCHER_END
  chmod +x "$f"
}
make_launcher "Web Browser" "chromium" "chromium"
make_launcher "Terminal" "xfce4-terminal" "utilities-terminal"
make_launcher "File Manager" "thunar" "system-file-manager"
make_launcher "Text Editor" "mousepad" "accessories-text-editor"

# 6. XFCE4 desktop session with its own D-Bus session
dbus-run-session -- startxfce4 >/tmp/xfce.log 2>&1 &
sleep 3
log "XFCE4 desktop started"

# 7. VNC server, bound to localhost so only websockify can reach it
x11vnc -display "$DISPLAY_NUM" -rfbport "$VNC_INTERNAL_PORT" -localhost \
  -rfbauth /tmp/vncpasswd -forever -shared -noxdamage -quiet >/tmp/x11vnc.log 2>&1 &
log "VNC server on localhost:$VNC_INTERNAL_PORT"

# 8. noVNC web client + websockify on the hosting port (foreground process)
log "Cloud PC ready on port $PORT"
exec websockify --web=/usr/share/novnc/ "0.0.0.0:${PORT}" "localhost:${VNC_INTERNAL_PORT}"
