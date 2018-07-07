#!/bin/bash
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

set_send_mail_on_failure(){
    local STATUS_LOCAL=0
    for var in "$@"; do
        mkdir -p "/etc/systemd/system/${var}.d/" &&
        echo '
[Unit]
OnFailure=unit-status-mail@%n.service
        ' > "/etc/systemd/system/${var}.d/99-failure-send-mail.conf" &&
        chmod 644 "/etc/systemd/system/${var}.d/99-failure-send-mail.conf"
        STATUS_LOCAL+=$?
    done
    systemctl daemon-reload
    return $STATUS_LOCAL
}

set_email_systemd(){
    local SCRIPT_FILE=/opt/unit-status-mail.sh
    local SERVICE_FILE=$(basename -s .sh $SCRIPT_FILE)'@.service'
    echo '#!/bin/bash
MAILTO="root"
MAILFROM="unit-status-mailer"
UNIT=$1

EXTRA=""
for e in "${@:2}"; do
  EXTRA+="$e"\r\n
done

UNITSTATUS=$(journalctl -b -u $UNIT)

sendmail $MAILTO <<EOF
From:$MAILFROM
To:$MAILTO
Subject:[${2}] Status mail for unit: $UNIT

Status report for unit: $UNIT
$EXTRA

$UNITSTATUS
EOF

echo -e "Status mail sent to: $MAILTO for unit: $UNIT"
    ' > "$SCRIPT_FILE" &&
    echo "
[Unit]
Description=Unit Status Mailer Service
After=network.target

[Service]
Type=simple
ExecStart=$SCRIPT_FILE %I \"Hostname: %H\" \"Machine ID: %m\" \"Boot ID: %b\"
    " > "/etc/systemd/system/${SERVICE_FILE}" &&
    chmod +rx "$SCRIPT_FILE" &&    
    chmod 644 "/etc/systemd/system/${SERVICE_FILE}" &&
    systemctl daemon-reload
} 


set_email_agent(){
    local SSMTP_CONF=/etc/ssmtp/ssmtp.conf
    local REVALIASES_CONF=/etc/ssmtp/revaliases
    local FROM_ADDR=''
    local USERNAME=''
    local PASSWORD=''
    local MAILHUB=''
    local MAILHUB_NOPORT=''
    local TO_ADDR=''         
    echo 'Type the SMTP server (domain:port) (for gmail, just type "smtp.gmail.com:465" without quotes): ' &&
    read MAILHUB &&
    echo 'Type the SMTP From address (username@domain.com): ' &&
    read FROM_ADDR &&
    echo 'Type the password (for security reasons, no output will be shown): ' &&
    read -s PASSWORD &&
    echo 'Type the destination address (someone@domain) for ROOT user: ' &&
    read TO_ADDR &&
    USERNAME=${FROM_ADDR%%@*} &&
    MAILHUB_PORT=$(echo $MAILHUB | grep -o -P '[0-9]+$' ) &&
    MAILHUB_NOPORT=${MAILHUB%%:*} &&
    apt-get -y purge exim4-base exim4-config exim4-daemon-light mailutils &&
    apt-get -y install ssmtp bsd-mailx &&
    cp "$SSMTP_CONF" "${SSMTP_CONF}.bak" &&
    echo "
FromLineOverride=yes
mailhub=$MAILHUB
root=$FROM_ADDR
AuthUser=$USERNAME
AuthPass=$PASSWORD
    " > "$SSMTP_CONF" && (        
        if [[ "$MAILHUB_PORT" == 587 ]]; then
            echo 'UseSTARTTLS=YES' >> "$SSMTP_CONF"
        elif [[ "$MAILHUB_PORT" == 465 ]]; then
            echo 'UseTLS=YES' >> "$SSMTP_CONF"
        fi        
    ) &&
    cp "$REVALIASES_CONF" "${REVALIASES_CONF}.bak" &&
    echo "root:${TO_ADDR}:${MAILHUB_NOPORT}" > "$REVALIASES_CONF" 
}