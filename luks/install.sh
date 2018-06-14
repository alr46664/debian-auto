#!/bin/bash
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
UTILITIES="$SCRIPT_DIR/../Utilities"
# if it's not root, exit!
[ "$(whoami)" != "root" ] && echo -e "\n\tRUN this script as ROOT. Exiting...\n" && exit 1

#GENERAL CONFIG VARIABLES
INSTALL_DIR="/usr/sbin"

cpy_install() {
    for file in $@; do
        cp "$SCRIPT_DIR/$file" "$INSTALL_DIR" &&
        chmod +rx "$INSTALL_DIR/$file"
    done
}

cpy_install lclose.sh lopen.sh lcreate.sh &&
echo -e "Installation of luks scripts - SUCCESSFUL" ||
(
    echo -e "Installation of luks scripts - FAILED"
    exit 1
)

