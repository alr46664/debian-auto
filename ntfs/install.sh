#!/bin/bash
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

DEST_DIR=/opt
SCRIPT_FILE=ntfs_mount.sh
SERVICE_FILE=ntfs_mount.service

CONFIG_FILE=/etc/ntfs_to_mount.conf

# if it's not root, exit!
[ "$(whoami)" != "root" ] && echo -e "\n\tRUN this script as ROOT. Exiting...\n" && exit 1

cp "$SCRIPT_DIR/$SCRIPT_FILE" "$DEST_DIR" &&
chmod +rx "$DEST_DIR/$SCRIPT_FILE" &&
touch "$CONFIG_FILE" &&
chmod +r "$CONFIG_FILE" &&
echo "
[Unit]
Description=NTFS Auto Mounter
RequiresMountsFor=/dev

[Service]
Type=oneshot
ExecStart=$DEST_DIR/$SCRIPT_FILE
Nice=19

[Install]
WantedBy=local-fs.target
" > "/etc/systemd/system/$SERVICE_FILE" &&
chmod +r "/etc/systemd/system/$SERVICE_FILE" &&
systemctl daemon-reload &&
systemctl enable "$SERVICE_FILE"

