#!/bin/bash
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

CURRENT_DESKTOP="$(env | grep CURRENT_DESKTOP | awk -F = '{print$2}')"
DEBIAN_CODENAME="$(lsb_release -a | grep -i Codename | cut -d':' -f2 | tr -s ' ' | xargs)"

# if it's not root, exit!
[ "$(whoami)" != "root" ] && echo -e "\n\tRUN this script as ROOT. Exiting...\n" && exit 1

STATUS=""
LOG_FILE="install.log"
COUNTER=0

# load functions
. "${SCRIPT_DIR}/status.sh"
. "${SCRIPT_DIR}/mail.sh"

#install useful .tools in system
install_tools(){
    local LUKS="$SCRIPT_DIR/../luks/install.sh"
    local PDF="$SCRIPT_DIR/../pdf/install.sh"
    local NTFS="$SCRIPT_DIR/../ntfs/install.sh"
    local MINIDLNA="$SCRIPT_DIR/../minidlna/install.sh"
    local ANANICY="$SCRIPT_DIR/../Ananicy/install.sh"

    #install luks tools
    bash "$LUKS"
    check_status "TOOLS\n\tLUKS TOOLS - "

    #install pdf tools
    bash "$PDF"
    check_status "\tPDF TOOLS - "

     #install ntfs tools
    bash "$NTFS"
    set_send_mail_on_failure ntfs_mount.service
    check_status "\tNTFS Auto Mounter - "

    #install minidlna
    bash "$MINIDLNA"    
    check_status "\tMiniDLNA - "

    #install ananicy
    bash "$ANANICY"    
    check_status "\tAnanicy - "
}

update_system(){
    APT_USER="aptitude git make gcc rsync youtube-dl smplayer vlc gimp firefox-esr firefox-esr-l10n-pt-br thunderbird thunderbird-l10n-pt-br speedcrunch keepassx libreoffice libreoffice-gtk3 libreoffice-l10n-pt-br xsane sshfs aria2  ghostscript fish bash-builtins qbittorrent unison unison-gtk"
    # drivers
    APT_DRIVER='xserver-xorg-input-synaptics xserver-xorg-input-mouse firmware-realtek firmware-atheros firmware-ipw2x00 firmware-intel-sound intel-microcode amd64-microcode'
    # compression software
    APT_COMPAC='rar unrar p7zip gzip lzip zip pigz'
    # fuse and filesystems
    APT_FUSE='libfsntfs-utils libfsntfs1 cryptsetup exfat-utils exfat-fuse btrfs-progs btrfs-tools gparted mtools mdadm dmsetup lvm2 acl sshfs autossh'
    # multimedia libraries and software
    APT_MULTIMEDIA='ffmpeg libavdevice57 libavfilter6 libfdk-aac1 libfaac0 libmp3lame0 x264 mediainfo'
    # system software
    APT_SYSTEM='sni-qt apt-transport-https command-not-found ssh net-tools nmap dnsutils pv dkms linux-headers-amd64 ttf-mscorefonts-installer'

    if [ $CURRENT_DESKTOP = "KDE" ]; then
        APT_SYSTEM="$APT_SYSTEM kdegraphics-thumbnailers"
    fi

    apt_upgrade upgrade  
    check_status "\tSYSTEM INITIAL UPDATE - "

    apt download $APT_USER $APT_DRIVER $APT_COMPAC $APT_FUSE $APT_MULTIMEDIA $APT_SYSTEM &&
    apt_upgrade install $APT_USER $APT_DRIVER $APT_COMPAC $APT_FUSE $APT_MULTIMEDIA $APT_SYSTEM &&    
    update-command-not-found &&
    apt-get -y purge libreoffice-kde &&
    systemctl start sshd
    check_status "\tSYSTEM USER PACKAGES INSTALL - "
}

install_backup_script(){
    cp "${SCRIPT_DIR}/backup.sh" /opt &&
    chmod +rx /opt/backup.sh
    check_status "\tBACKUP SCRIPT INSTALL - "    
}

set_unattended_upgrades(){
    local APT_CONF_D=/etc/apt/apt.conf.d/
    local STATUS_LOCAL=0
    apt-get -y install unattended-upgrades apt-listchanges 
    if [ $? -eq 0 ]; then
        for var in 50unattended-upgrades 20auto-upgrades; do
            cp "${APT_CONF_D}/${var}" "${APT_CONF_D}/${var}.bak" &&
            cp "${SCRIPT_DIR}/${var}" "$APT_CONF_D" &&
            chmod 644 "${APT_CONF_D}/${var}"
            STATUS_LOCAL+=$?
        done                
        set_send_mail_on_failure apt-daily.service apt-daily-upgrade.service    
        STATUS_LOCAL+=$?
        for var in apt-daily.timer apt-daily-upgrade.timer; do	
  	   mkdir -p "/etc/systemd/system/${var}.d" &&
           echo '
[Timer]
RandomizedDelaySec=15m
    ' > "/etc/systemd/system/${var}.d/99-randomness.conf" 
           STATUS_LOCAL+=$?
        done    
        for var in apt-daily.service apt-daily-upgrade.service; do	
  	   mkdir -p "/etc/systemd/system/${var}.d" &&
           echo '
[Unit]
After=network-online.target
Wants=network-online.target
    ' > "/etc/systemd/system/${var}.d/98-conditions.conf" 
           STATUS_LOCAL+=$?
        done    
        systemctl daemon-reload  
        STATUS_LOCAL+=$?
    else
        STATUS_LOCAL=1
    fi
    ( exit $STATUS_LOCAL )
    check_status "\tSET UNATTENDED UPGRADES - "
}

set_smartd_monitor(){
    local SERVICE=smartd.service
    local SMARTD_CONF=/etc/smartd.conf
    apt-get -y install smartmontools gsmartcontrol &&
    systemctl stop "$SERVICE" 
    sed -i'.bak' -e 's@^[# \t]*start_smartd=.*@start_smartd=yes@' -e 's@^[# \t]*smartd_opts=.*@smartd_opts="--interval=1800"@' /etc/default/smartmontools &&
    cp "$SMARTD_CONF" "${SMARTD_CONF}.bak" &&
    echo 'DEVICESCAN -n standby -m root -M exec /usr/share/smartmontools/smartd-runner' > "$SMARTD_CONF" &&
    mkdir -p "/etc/systemd/system/${SERVICE}.d" &&
    echo '
[Service]
Restart=on-failure
Nice=19
    ' > "/etc/systemd/system/${SERVICE}.d/99-bgprocess.conf" &&    
    systemctl daemon-reload &&
    set_send_mail_on_failure "${SERVICE}" &&
    systemctl enable "$SERVICE" &&
    systemctl restart "$SERVICE" 
    check_status "\tSET SMARTD MONITOR - "
}

set_profile_aliases(){
    local PROFILE_ALIAS='/etc/profile.d/alias.sh'
    echo '#!/bin/bash
alias cd..="cd .."
alias cd.="cd."
alias ll="ls -l"
alias la="ls -la"
alias cnf="command-not-found"
alias sed="sed -r"
    ' > "$PROFILE_ALIAS" &&
    chmod +rx "$PROFILE_ALIAS"
    check_status "\tSET PROFILE GLOBAL ALIASES - "
}

improve_fonts(){
    local LOCAL_STATS=0
    rsync -rPh --chown root --chmod 644 "$SCRIPT_DIR/fonts/" /usr/share/fonts/truetype/ &&
    fc-cache -fv
    LOCAL_STATS=$(($LOCAL_STATS + $?))        
    for user_home in /home/* ; do
        USER=$(basename $user_home)
        USER=$(cut -d: -f1 /etc/passwd | grep "$USER")
        if [ -z "$USER" ]; then continue; fi
        cp "$SCRIPT_DIR/fonts.conf" "$user_home/.fonts.conf" &&
        chmod +r "$user_home/.fonts.conf" &&
        chown "$USER" "$user_home/.fonts.conf"
        LOCAL_STATS=$(($LOCAL_STATS + $?))        
    done
    return $LOCAL_STATS
}

install_codecs(){
    local SOURCE_LIST='/etc/apt/sources.list.d/deb-multimedia.list'
    echo "
    deb http://debian.c3sl.ufpr.br/debian-multimedia $DEBIAN_CODENAME main
    deb-src http://debian.c3sl.ufpr.br/debian-multimedia $DEBIAN_CODENAME main
    " > "$SOURCE_LIST" &&
    chmod +rx "$SOURCE_LIST" &&
    apt-get -y --allow-unauthenticated update -oAcquire::AllowInsecureRepositories=true &&
    apt-get -y --allow-unauthenticated install deb-multimedia-keyring -oAcquire::AllowInsecureRepositories=true &&
    apt-get -y update &&
    apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" upgrade &&
    apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" dist-upgrade &&
    apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" install libdvdcss2
    check_status "\tDEBIAN MULTIMEDIA CODECS - "
}

install_google_chrome(){
    local SOURCE_LIST='/etc/apt/sources.list.d/google-chrome.list'
    local USERNAME=''
    wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - &&
    echo "
    deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main
    " > "$SOURCE_LIST" &&
    chmod +rx "$SOURCE_LIST" &&
    apt_upgrade install google-chrome-stable &&    
    for user in /home/* ; do
        USERNAME=$(basename "${user}")
        if ! grep "$USERNAME" /etc/passwd &> /dev/null; then
            continue
        fi        
        mkdir -p "${user}/.local/share/applications" &&
        chown "$USERNAME" "${user}/.local" "${user}/.local/share" "${user}/.local/share/applications" &&
        cp "$SCRIPT_DIR/google-chrome.desktop" "${user}/.local/share/applications" &&
        chown "$USERNAME" "${user}/.local/share/applications/google-chrome.desktop" &&
        chmod 644 "${user}/.local/share/applications/google-chrome.desktop"         
    done    
    check_status "\tGOOGLE CHROME - "
}

install_virtualbox(){
    local SOURCE_LIST='/etc/apt/sources.list.d/virtualbox.list'
    wget -q -O - https://www.virtualbox.org/download/oracle_vbox_2016.asc | apt-key add - &&
    echo "
    deb https://download.virtualbox.org/virtualbox/debian $DEBIAN_CODENAME contrib
    " > "$SOURCE_LIST" &&
    chmod +rx "$SOURCE_LIST" &&
    local VBOX_PKG=$(apt-cache search virtualbox | grep virtualbox | tr -s ' ' | cut -d' ' -f1 | sort -fiur | head -n 1)
    apt_upgrade install $VBOX_PKG
    check_status "\tVIRTUALBOX PUEL - "
}

disable_desktop_search(){
    local LOCAL_STATS=0
    local DESKTOP_FILES=$(find /etc/xdg/autostart /usr/share/autostart \( -name 'tracker-*.desktop' -o -name 'baloo*.desktop' \) )
    for var in $DESKTOP_FILES ; do
        echo "Hidden=True" >> "$var"
        LOCAL_STATS=$(($LOCAL_STATS + $?))
    done
    return $LOCAL_STATS
}

disable_services(){
    local SERVICES='bluetooth.service rsync.service unattended-upgrades.service ModemManager.service'
    echo 'DisableAutoSpawn' >> /etc/speech-dispatcher/speechd.conf
    for service in $SERVICES; done
        systemctl disable "$service"
    done
    check_status "\tDISABLE NOT USED SERVICES - "
}

players_protect_segfault(){
    local LOCAL_STATS=0
    for player in smplayer vlc; do
        local SCRIPT_FILE="/opt/$player.sh"
        local DESKTOP_FILES=$(find /usr/share/applications/ -name "$player*.desktop")
        if [ -z "$DESKTOP_FILES" ]; then
            LOCAL_STATS=$(($LOCAL_STATS + 1))
            continue
        fi
        for FILE in $DESKTOP_FILES; do
            sed -i'.bak' -e "s@Exec=[a-zA-Z\./]*@Exec=$SCRIPT_FILE@g" "$FILE"
        done
        echo "
        #!/bin/bash
        source /etc/profile
        #set a permanent limit of 4GB
        ulimit -v 4194304
        $player \"\$@\"
        " > "$SCRIPT_FILE" &&
        chmod +rx "$SCRIPT_FILE"
        LOCAL_STATS=$(($LOCAL_STATS + $?))
    done
    return $LOCAL_STATS
}

set_kernel_boot_options(){
    local BOOT_OPTIONS='ipv6.disable=1'
    sed -r -i'.bak' -e 's/GRUB_CMDLINE_LINUX_DEFAULT="(.*)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 '"$BOOT_OPTIONS"'"/' -e 's/( '"$BOOT_OPTIONS"')+/ '"$BOOT_OPTIONS"'/g' /etc/default/grub 
    check_status "\tKERNEL BOOT OPTIONS - "
}

sysctl_tuning(){
    local SYSCTL_CONF=/etc/sysctl.d/99-desktop.conf
    echo '
vm.dirty_background_bytes=31457280
vm.dirty_bytes=73400320
vm.swappiness=20
    ' > "$SYSCTL_CONF" &&
    chmod +r "$SYSCTL_CONF" &&
    sysctl --system
    check_status "\tSYSCTL TUNING - "
}

fs_tuning(){
    sed -i'.bak' -e 's@ / .*@ / defaults,acl,noatime,errors=remount-ro,commit=30 0 1@g' /etc/fstab &&
    mkdir -p /ramdisk &&
    chown root:users /ramdisk &&
    echo 'tmpfs   /ramdisk         tmpfs   nodev,nosuid,size=60%          0  0' >> /etc/fstab
    check_status "\tFILESYSTEM TUNING - "
}

block_drivers(){
    local BLACKLIST_FILE=/etc/modprobe.d/50-blacklist.conf
    echo '
blacklist hid_multitouch
    ' > "$BLACKLIST_FILE" &&
    chmod +r "$BLACKLIST_FILE"
    check_status "\tBLACKLIST PROBLEMATIC DRIVERS - "
}

cleanup(){
    echo '  Cleaning old not needed packages ... ' &&
    apt-get clean &&
    apt-get autoremove 
    check_status "\tCLEANING APT - " | tee -a "$LOG_FILE"        
}

defrag_system(){
    echo '  Defragmenting root dir / ... '
    e4defrag -v /
    check_status "\tDEFRAGMENT SYSTEM - " | tee -a "$LOG_FILE"
}

echo " " | tee "$LOG_FILE"
echo "  UPDATE PROCEDURE BEGIN  " | tee "$LOG_FILE"
echo "  $(uptime)  " | tee -a "$LOG_FILE"
echo "  $(date)    " | tee -a "$LOG_FILE"
echo " " | tee -a "$LOG_FILE"
install_tools | tee -a "$LOG_FILE"
update_system | tee -a "$LOG_FILE"
set_email_agent | tee -a "$LOG_FILE"; check_status "\tSET EMAIL SMTP AGENT - "    
set_email_systemd | tee -a "$LOG_FILE"; check_status "\tSET EMAIL SYSTEMD SERVICE - "    
install_codecs | tee -a "$LOG_FILE"
set_unattended_upgrades | tee -a "$LOG_FILE"

install_google_chrome | tee -a "$LOG_FILE"
install_virtualbox | tee -a "$LOG_FILE"

set_profile_aliases | tee -a "$LOG_FILE"
disable_services | tee -a "$LOG_FILE"

disable_desktop_search | tee -a "$LOG_FILE"
check_status "\tDISABLE DESKTOP SEARCH - " | tee -a "$LOG_FILE"
players_protect_segfault | tee -a "$LOG_FILE"
check_status "\tPLAYERS PROTECT SEGFAULT - " | tee -a "$LOG_FILE"
improve_fonts | tee -a "$LOG_FILE"
check_status "\tIMPROVE FONT RENDERING - " | tee -a "$LOG_FILE"

set_smartd_monitor | tee -a "$LOG_FILE"
set_kernel_boot_options | tee -a "$LOG_FILE"
sysctl_tuning | tee -a "$LOG_FILE"
fs_tuning | tee -a "$LOG_FILE"
block_drivers | tee -a "$LOG_FILE"

install_backup_script | tee -a "$LOG_FILE"
cleanup | tee -a "$LOG_FILE"
defrag_system | tee -a "$LOG_FILE"
echo -e "\n\t======== INSTALLATION REPORT =========\n$STATUS" | tee -a "$LOG_FILE"
echo -e "\n\tDistribution configuration complete. Have fun :) \n"
