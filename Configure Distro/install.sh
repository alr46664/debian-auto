#!/bin/bash
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

CURRENT_DESKTOP="$(env | grep CURRENT_DESKTOP | awk -F = '{print$2}')"
DEBIAN_CODENAME="$(lsb_release -a | grep -i Codename | cut -d':' -f2 | tr -s ' ' | xargs)"

# if it's not root, exit!
[ "$(whoami)" != "root" ] && echo -e "\n\tRUN this script as ROOT. Exiting...\n" && exit 1

STATUS=""
LOG_FILE="install.log"
COUNTER=0

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
    yes '' | apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" $@
}

#install useful .tools in system
install_tools(){
    local LUKS="$SCRIPT_DIR/../luks/install.sh"
    local PDF="$SCRIPT_DIR/../pdf/install.sh"
    local NTFS="$SCRIPT_DIR/../ntfs/install.sh"

    #install luks tools
    bash "$LUKS"
    check_status "TOOLS\n\tLUKS TOOLS - "

    #install pdf tools
    bash "$PDF"
    check_status "\tPDF TOOLS - "

     #install ntfs tools
    bash "$NTFS"
    check_status "\tNTFS Auto Mounter - "
}

update_system(){
    APT_USER="aptitude git make gcc rsync youtube-dl smplayer vlc gimp firefox-esr firefox-esr-l10n-pt-br thunderbird thunderbird-l10n-pt-br speedcrunch keepassx libreoffice libreoffice-gtk3 libreoffice-l10n-pt-br xsane sshfs aria2  ghostscript"
    # drivers
    APT_DRIVER='xserver-xorg-input-synaptics xserver-xorg-input-mouse firmware-realtek firmware-atheros firmware-ipw2x00 firmware-intel-sound intel-microcode amd64-microcode'
    # compression software
    APT_COMPAC='rar unrar p7zip gzip lzip zip pigz'
    # fuse and filesystems
    APT_FUSE='libfsntfs-utils libfsntfs1 cryptsetup exfat-utils exfat-fuse gparted'
    # multimedia libraries and software
    APT_MULTIMEDIA='ffmpeg libavdevice57 libavfilter6 libfdk-aac1 libfaac0 libmp3lame0 x264 mediainfo'
    # system software
    APT_SYSTEM='sni-qt pv ttf-mscorefonts-installer'

    if [ $CURRENT_DESKTOP = "KDE" ]; then
        APT_SYSTEM="$APT_SYSTEM kdegraphics-thumbnailers"
    fi

    apt_upgrade upgrade
    check_status "\tSYSTEM INITIAL UPDATE - "

    apt_upgrade install $APT_USER $APT_DRIVER $APT_COMPAC $APT_FUSE $APT_MULTIMEDIA $APT_SYSTEM
    check_status "\tSYSTEM USER PACKAGES INSTALL - "
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
    yes '' | apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" upgrade &&
    yes '' | apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold" dist-upgrade
    check_status "\tDEBIAN MULTIMEDIA CODECS - "
}

install_google_chrome(){
    local SOURCE_LIST='/etc/apt/sources.list.d/google-chrome.list'
    wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - &&
    echo "
    deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main
    " > "$SOURCE_LIST" &&
    chmod +rx "$SOURCE_LIST" &&
    apt_upgrade install google-chrome-stable &&
    chattr -i /usr/share/applications/google-chrome.desktop &&
    cp "$SCRIPT_DIR/google-chrome.desktop" /usr/share/applications &&
    chmod +rx /usr/share/applications/google-chrome.desktop &&
    chattr +i /usr/share/applications/google-chrome.desktop
    check_status "\tGOOGLE CHROME - "
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
    systemctl disable bluetooth.service rsync.service
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
        #set a permanent limit of 2GB
        ulimit -v 2097152
        $player \"\$@\"
        " > "$SCRIPT_FILE" &&
        chmod +rx "$SCRIPT_FILE"
        LOCAL_STATS=$(($LOCAL_STATS + $?))
    done
    return $LOCAL_STATS
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
    sed -i'.bak' -e 's@ / .*@ / noatime,errors=remount-ro,commit=30 0 1@g' /etc/fstab
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
    echo '  Cleaning old not needed packages ... '
    apt-get clean
    apt-get autoremove
}

echo " " | tee "$LOG_FILE"
echo "  UPDATE PROCEDURE BEGIN  " | tee "$LOG_FILE"
echo "  $(uptime)  " | tee -a "$LOG_FILE"
echo "  $(date)    " | tee -a "$LOG_FILE"
echo " " | tee -a "$LOG_FILE"
install_tools | tee -a "$LOG_FILE"
update_system | tee -a "$LOG_FILE"
install_codecs | tee -a "$LOG_FILE"

install_google_chrome | tee -a "$LOG_FILE"

disable_services | tee -a "$LOG_FILE"
disable_desktop_search | tee -a "$LOG_FILE"
check_status "\tDISABLE DESKTOP SEARCH - " | tee -a "$LOG_FILE"
players_protect_segfault | tee -a "$LOG_FILE"
check_status "\tPLAYERS PROTECT SEGFAULT - " | tee -a "$LOG_FILE"

sysctl_tuning | tee -a "$LOG_FILE"
fs_tuning | tee -a "$LOG_FILE"
block_drivers | tee -a "$LOG_FILE"

cleanup | tee -a "$LOG_FILE"
echo -e "\n\t======== INSTALLATION REPORT =========\n$STATUS" | tee -a "$LOG_FILE"
echo -e "\n\tDistribution configuration complete. Have fun :) \n"
