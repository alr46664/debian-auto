#!/bin/bash
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# if it's not root, exit!
[ "$(whoami)" != "root" ] && echo -e "\n\tRUN this script as ROOT. Exiting...\n" && exit 1

#GENERAL CONFIG VARIABLES
INSTALL_DIR=/usr/bin

# install binaries
cp "$SCRIPT_DIR/pdfcompress.sh" "$INSTALL_DIR" &&
chmod +rx "$INSTALL_DIR/pdfcompress.sh" &&
mv "$INSTALL_DIR/pdfcompress.sh" "$INSTALL_DIR/pdfcompress" &&
echo -n "Installation of PDF Utilities - " &&
echo 'SUCCESS' ||
(
  echo 'FAILED'
  exit 1
)

