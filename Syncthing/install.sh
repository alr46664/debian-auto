#!/bin/bash
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

[ "$(whoami)" != "root" ] && echo -e "\n\tRUN this script as ROOT. Exiting...\n" && exit 1

USER=syncthing

show_msg(){
    [ $? -eq 0 ] && 
    echo "   ${1} - OK" ||
    (
        echo "   ${1} - FAILED"
        exit 1
    )
}

install_service(){
    local SERVICE=/etc/systemd/system/syncthing.service
    echo "
[Unit]
Description=Syncthing Daemon Service
After=network.target local-fs.target

[Service]
User=$USER
ExecStart=/usr/bin/syncthing
ExecStop=/usr/bin/killall -w syncthing
Nice=19

[Install]
WantedBy=multi-user.target
    " > "$SERVICE" &&
    systemctl daemon-reload &&
    systemctl enable $(basename "$SERVICE") &&
    systemctl start $(basename "$SERVICE")
}

apt-get update &&
apt-get -y install syncthing &&
useradd -m "$USER" &&
usermod -s /usr/sbin/nologin -a -G users "$USER" &&
install_service 
show_msg 'SYNCTHING INSTALL'
 
