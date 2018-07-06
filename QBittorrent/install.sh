#!/bin/bash
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

[ "$(whoami)" != "root" ] && echo -e "\n\tRUN this script as ROOT. Exiting...\n" && exit 1

USER=qbtuser
SERVICE=/etc/systemd/system/qbittorrent.service

sudo apt-get update && 
sudo apt-get install qbittorrent-nox &&
useradd -m "$USER" &&
echo -e "y\n" | su "$USER" -c "qbittorrent-nox" &&
usermod -s /usr/sbin/nologin "$USER" &&
echo "
[Unit]
Description=qBittorrent Daemon Service
After=network.target

[Service]
User=$USER
ExecStart=/usr/bin/qbittorrent-nox
ExecStop=/usr/bin/killall -w qbittorrent-nox
Nice=19

[Install]
WantedBy=multi-user.target
" > "$SERVICE" &&
systemctl daemon-reload &&
systemctl enable $(basename "$SERVICE") &&
systemctl start $(basename "$SERVICE") &&
echo '   QTBITTORRENT HEADLESS INSTALL - OK' ||
(
    echo '   QTBITTORRENT HEADLESS INSTALL - FAILED'
    exit 1
)