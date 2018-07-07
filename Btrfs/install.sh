#!/bin/bash
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

BTRFS_BALANCE=btrfs-balance
BTRFS_SCRUB=btrfs-scrub

. "${SCRIPT_DIR}/../Configure Distro/mail.sh"
. "${SCRIPT_DIR}/../Configure Distro/systemd.sh"

[ "$(whoami)" != "root" ] && echo -e "\n\tRUN this script as ROOT. Exiting...\n" && exit 1

PWD=$(pwd)

cd "${SCRIPT_DIR}/btrfsmaintenance" &&
apt-get update && apt-get -y install btrfs-progs &&
./dist-install.sh &&
install_service ${BTRFS_BALANCE}.service ${BTRFS_BALANCE}.timer ${BTRFS_SCRUB}.service ${BTRFS_SCRUB}.timer &&
systemctl daemon-reload &&
systemctl enable ${BTRFS_BALANCE}.timer ${BTRFS_SCRUB}.timer
STATUS=$?

cd "$PWD"
if [ $STATUS -eq 0 ]; then
    echo -e '\n\tBTRFS MAINTENANCE INSTALL - OK\n'
else
    echo -e '\n\tBTRFS MAINTENANCE INSTALL - FAILED\n'    
    exit 1
fi
