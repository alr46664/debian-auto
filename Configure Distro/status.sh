#!/bin/bash

# insert done or failed depending on the return status
check_status() {
    local STATS=$?
    local MSG="$1"

    [ $STATS -eq 0 ] &&
    STATUS="$STATUS[$COUNTER] $MSG - DONE\n" ||
    STATUS="$STATUS[$COUNTER] $MSG - FAILED\n"
    COUNTER=$(($COUNTER+1))
}

apt_upgrade(){
    export DEBIAN_FRONTEND=noninteractive
    apt-get -y clean &&
    apt-get -y update &&
    apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" $@
} 
