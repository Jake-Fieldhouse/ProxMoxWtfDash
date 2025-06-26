#!/usr/bin/env bash
set -euo pipefail
HOST=${1:-wtf}
SERVICE=wtf-proxmoxdash
INSTALL_DIR=/opt/$SERVICE
LOG_FILE=/var/log/$SERVICE.log
DOMAIN="${HOST}-proxmoxdash.hosted.jke"

if [ "$EUID" -ne 0 ]; then
    echo "Run as root" >&2
    exit 1
fi

check_proxmox_dns() {
    local host_ip=""
    if command -v getent >/dev/null 2>&1; then
        host_ip=$(getent hosts proxmox.hosted.jke | awk '{print $1}' | head -n1)
    fi
    if [ -z "$host_ip" ] && command -v dig >/dev/null 2>&1; then
        host_ip=$(dig +short proxmox.hosted.jke | head -n1)
    fi
    if [ -z "$host_ip" ]; then
        echo "Could not resolve proxmox.hosted.jke. Please fix DNS before running the installer." >&2
        exit 1
    fi
    local local_ip
    local_ip=$(hostname -I | awk '{print $1}')
    echo "proxmox.hosted.jke resolves to $host_ip (local IP: $local_ip)"
    if [ "$host_ip" != "$local_ip" ]; then
        echo "proxmox.hosted.jke does not resolve to this machine. Fix DNS before installing." >&2
        exit 1
    fi
}

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

check_proxmox_dns

apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-pip tailscale curl

if ! command -v git >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y git
fi

if [ -d "$INSTALL_DIR/.git" ]; then
    git -C "$INSTALL_DIR" pull --ff-only
else
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

pip3 install --break-system-packages -r "$INSTALL_DIR/requirements.txt"

CUR_HOST=$(hostname)
if [ "$CUR_HOST" != "$HOST" ]; then
    hostnamectl set-hostname "$HOST"
    tailscale set --hostname "$HOST" >/dev/null 2>&1 || true
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
echo "$SERVICE running at http://${DOMAIN}:8750 and http://${LAN_IP}:8750${TS_IP:+ and http://${TS_IP}:8750}"

