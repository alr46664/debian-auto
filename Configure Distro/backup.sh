#!/bin/bash
MODE=0
PARTITION=''
NEWROOT=''
BACKUP_FILE=''
EFI_BOOT=''
DATE=$(date '+%F-%X' | sed -e 's@:@-@g')

mount_devices(){
    local STATUS_LOCAL=0
    NEWROOT=$(mount | grep "$PARTITION" | tr -s ' ' | cut -d' ' -f3)    
    cd "$NEWROOT" &&    
    mount -o bind "$(dirname "$BACKUP_FILE")" "${NEWROOT}/media" &&    
    BACKUP_FILE=$(basename -s .tar.gz "$BACKUP_FILE") 
    STATUS_LOCAL+=$?
    if [ -n "$EFI_BOOT" ]; then
        mount -o ro "$EFI_BOOT" "${NEWROOT}/boot"
        STATUS_LOCAL+=$?
    fi                    
    for var in sys dev proc ; do
        mount -o bind "/${var}" "${NEWROOT}/${var}" 
        STATUS_LOCAL+=$?
    done    
    return $STATUS_LOCAL
}

install_grub_efi(){
    if ! chroot "$NEWROOT" aptitude search grub-efi-amd64 | grep -P '^i' &> /dev/null; then
        chroot "$NEWROOT" apt-get -y install grub-efi-amd64
    else
        chroot "$NEWROOT" grub-install --efi-directory=/boot --target=x86_64-efi "$PARTITION"
    fi    
    
}

install_grub_pc(){
    if ! chroot "$NEWROOT" aptitude search grub-pc | grep -P '^i' &> /dev/null; then
        chroot "$NEWROOT" apt-get -y install grub-pc
    else
        chroot "$NEWROOT" grub-install --target=i386-pc "$PARTITION"
    fi    
}

run_backup(){        
    chroot "$NEWROOT" \
    tar -cvpzf "/media/${BACKUP_FILE}_${DATE}.tar.gz" \
    --numeric-owner --atime-preserve --acls --xattrs \
    --exclude=/sys \
    --exclude=/proc \
    --exclude=/dev \
    --exclude=/media \
    --exclude=/home/*/.local/share/Trash /
}

run_restore(){
    chroot "$NEWROOT" \
    tar -xvpzf "/media/${BACKUP_FILE}.tar.gz" -C / --numeric-owner 
    if [ $? -ne 0 ]; then
        return 1
    fi
    if [ -n "$EFI_BOOT" ]; then
        install_grub_efi        
    else
        install_grub_pc        
    fi        
}

show_help(){
    echo ' '
    echo '  Usage: backup.sh [--efi-boot EFI_PARTITION] [-b|-r] backupfile --root root_partition'    
    echo ' '
    echo ' WARNING: root_partition must be already mounted for this script to work'
    echo ' '
    exit 1
}

while [ $# -ne 0 ]; do
    case "$1" in
    -b|--backup)
        MODE=backup
        shift
        BACKUP_FILE="$1"
        ;;
    -r|--recovery)
        MODE=recovery
        shift
        BACKUP_FILE="$1"
        ;;
    --efi-boot)
        shift
        EFI_BOOT="$1"
        ;;
    --root)
        shift
        PARTITION="$1"
        ;;
    *)
        show_help
        ;;
    esac    
    shift
done

if [ "$MODE" == backup ]; then
    mount_devices &&
    run_backup &&
    echo -e '\nBACKUP - OK\n' ||
    (
        echo -e '\nBACKUP - FAILED\n'  
        exit 1      
    )
elif [ "$MODE" == recovery ]; then
    mount_devices &&
    run_restore &&
    echo -e '\nRECOVERY - OK\n' ||
    (
        echo -e '\nRECOVERY - FAILED\n'  
        exit 1      
    )
else        
    show_help
fi






