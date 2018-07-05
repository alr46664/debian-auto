#!/bin/bash
MODE=0
PARTITION=''
NEWROOT=''
BACKUP_FILE=''
EFI_BOOT=''
DATE=$(date '+%F-%X' | sed -e 's@:@-@g')

mount_devices(){
    local STATUS_LOCAL=0
    NEWROOT=/new_root
    mkdir -p "$NEWROOT" &&
    cd "$NEWROOT" &&
    mount -o ro "$PARTITION" "$NEWROOT" &&
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

run_backup(){        
    chroot "$NEWROOT" \
    tar -cvpzf "/media/${BACKUP_FILE}_${DATE}.tar.gz" \
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
        chroot "$NEWROOT" \
        grub-install --efi-directory=/boot --target=x86_64-efi "$PARTITION"
    else
        chroot "$NEWROOT" \
        grub-install --target=i386-pc "$PARTITION"
    fi        
}

show_help(){
    echo 'Usage: backup.sh [--efi-boot EFI_PARTITION] [-b|-r] backupfile --root root_partition'
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






