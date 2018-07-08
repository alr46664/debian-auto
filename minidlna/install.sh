#!/bin/bash

CONFIG=/etc/minidlna.conf
USERMOD="usermod -s /usr/sbin/nologin -a -G users minidlna"

[ $(whoami) != root ] && echo 'RUN IT AS ROOT' && exit 1

apt-get update && apt-get -y install minidlna &&
systemctl enable minidlna &&
systemctl restart minidlna &&
${USERMOD} || (
    useradd minidlna &&
    ${USERMOD}
) &&
sed -i -e 's@^[# \t]*user=.*@user=minidlna@i' "$CONFIG" &&
editor "$CONFIG"