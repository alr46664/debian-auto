#!/bin/bash

install_service(){
    local STATUS_LOCAL=0
    while [ $# -ne 0 ]; do
        cp "$1" /etc/systemd/system &&
        chmod 644 "/etc/systemd/system/$(basename ${1})"
        STATUS_LOCAL+=$?
        shift
    done
    systemctl daemon-reload
    return $STATUS_LOCAL
}

set_service_bg_priority(){
    local STATUS_LOCAL=0
    local CONF_FILE=99-bgpriority.conf
    while [ $# -ne 0 ]; do
        mkdir -p "/etc/systemd/system/${1}.d/" &&
        echo "
[Service]
IOSchedulingClass=idle
CPUSchedulingPolicy=idle
Nice=$2
        " > "/etc/systemd/system/${1}.d/${CONF_FILE}" &&
        chmod 644 "/etc/systemd/system/${1}.d/${CONF_FILE}"
        STATUS_LOCAL+=$?
        shift; shift
    done
    systemctl daemon-reload
    STATUS_LOCAL+=$?
    return $STATUS_LOCAL
}

set_timer_on_calendar(){
    local STATUS_LOCAL=0
    local CONF_FILE=99-on-calendar.conf
    while [ $# -ne 0 ]; do
        mkdir -p "/etc/systemd/system/${1}.d/" &&
        echo "
[Timer]
OnCalendar=$2
        " > "/etc/systemd/system/${1}.d/${CONF_FILE}" &&
        chmod 644 "/etc/systemd/system/${1}.d/${CONF_FILE}"
        STATUS_LOCAL+=$?
        shift; shift
    done
    systemctl daemon-reload
    STATUS_LOCAL+=$?
    return $STATUS_LOCAL
}
