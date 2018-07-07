#!/bin/bash
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

[ "$(whoami)" != "root" ] && echo -e "\n\tRUN this script as ROOT. Exiting...\n" && exit 1

PWD=$(pwd)
apt-get update && apt-get -y install btrfs-progs &&
cd "${SCRIPT_DIR}/btrfsmaintenance/" &&
./dist-install.sh
cd "$PWD"
