#!/usr/bin/env bash
set -euo pipefail
SERVICE=wtf-proxmoxdash
INSTALL_DIR=/opt/$SERVICE
LOG_FILE=/var/log/$SERVICE.log

if [ "$EUID" -ne 0 ]; then
    echo "Run as root" >&2
    exit 1
fi

REPO_URL=""

# Repository to use if detection fails
DEFAULT_REPO_URL="https://github.com/Jake-Fieldhouse/ProxMoxWtfDash.git"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    REPO_URL=$(git config --get remote.origin.url)
fi

if [ -z "$REPO_URL" ] && [ -d "$INSTALL_DIR/.git" ]; then
    REPO_URL=$(git -C "$INSTALL_DIR" config --get remote.origin.url)
fi

if [ -z "$REPO_URL" ]; then
    REPO_URL="$DEFAULT_REPO_URL"
fi

if [ -d "$INSTALL_DIR/.git" ]; then
    git -C "$INSTALL_DIR" pull --ff-only
else
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-pip git tailscale curl

pip3 install --break-system-packages -r "$INSTALL_DIR/requirements.txt"

CUR_HOST=$(hostname)
if [ "$CUR_HOST" != "$SERVICE" ]; then
    hostnamectl set-hostname "$SERVICE"
    tailscale set --hostname "$SERVICE" >/dev/null 2>&1 || true
    systemctl restart tailscaled || true
fi

cat <<SERVICE >/etc/systemd/system/$SERVICE.service
[Unit]
Description=wtf-proxmoxdash
After=network.target

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/python3 -u $INSTALL_DIR/dashboard.py
Restart=always
RestartSec=5
StandardOutput=append:$LOG_FILE
StandardError=append:$LOG_FILE

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable --now $SERVICE

LAN_IP=$(hostname -I | awk '{print $1}')
TS_IP=$(tailscale ip -4 2>/dev/null | head -n1)
echo "$SERVICE running at http://wtf-proxmoxdash.hosted.jke:8750 and http://${LAN_IP}:8750${TS_IP:+ and http://${TS_IP}:8750}"

