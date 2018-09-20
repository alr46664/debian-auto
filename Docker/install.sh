#!/bin/bash

show_result(){
    local MSG=$1
    [ $? -eq 0 ] && echo "$MSG - SUCCESS" ||
    (
        "$MSG - FAILED"
        return 1
    )
}

install_docker(){
    sudo apt-get update &&
    sudo apt-get install apt-transport-https ca-certificates curl gnupg2 software-properties-common &&
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add - &&
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable" &&
    sudo apt-get update &&
    sudo apt-get -y install docker-ce &&
    show_result "Docker CE Installation"
}

config_docker_no_root(){
    local STATUS=0
    local GROUP=docker
    local USERS=$(cat /etc/passwd | grep /home | egrep -v '(/bin/false|/usr/sbin/nologin)' | cut -d':' -f1 | xargs) &&
    sudo groupadd $GROUP 
    for USER in $USERS ; do
        sudo usermod -aG $GROUP $USER 
        STATUS=$(($STATUS+1))
    done        
    [ $STATUS -eq 0 ] &&
    echo 'You need to LOG OUT and LOG IN again to use DOCKER CE'
    show_result "Docker CE Configuration"
}

install_docker &&
config_docker_no_root ||
(
    echo 'Docker CE Automated Script - FAILED'
    exit 1
)




