#!/bin/bash

#
# Initial settings
#

NAME=$(basename $0)

#
# Functions
#

function usage() {
        echo "usage: $NAME" >&2
        echo -e "\tnote: you must be root to execute this program!" >&2
        exit 1
}

#
# Main
#

TEMP=$(getopt -o h -n $NAME -- "$@")
[ $? != 0 ] && exit 1
eval set -- "$TEMP"
while true ; do
        case "$1" in
        -h)
                usage
                ;;

        --)
                shift
                break
                ;;

        *)
                echo "$NAME: internal error!" >&2
                exit 1
                ;;
        esac
done

# Check for root user
if [ "$(whoami)" != "root" ] ; then
        echo "$NAME: you must be root to execute this program!" >&2
        exit 1
fi

# Display current content
echo -e "$NAME: I'm going to rewrite your NAND!\n"
echo -e "$NAME: press ENTER to continue erasing ALL DATA, or just hit CTRL-C to"
echo "$NAME: stop here! :-)"
read ans

set -e

echo "$NAME: programming at91bootstrap..."
flash_erase -q /dev/mtd0 0 0
./bootloader/at91bootstrap/cosino_nand_blesser 2> /dev/null | cat - ./bootloader/at91bootstrap/latest-nandflashboot > /dev/mtdblock0

echo "$NAME: programming u-boot..."
flash_erase -q /dev/mtd1 0 0
cat ./bootloader/u-boot/latest-nandflash > /dev/mtdblock1

echo "$NAME: programming linux..."
flash_erase -q /dev/mtd3 0 0
cat ./kernel/latest-openwrt > /dev/mtdblock3

echo "$NAME: building up openwrt..."
flash_erase -q -j /dev/mtd4 0 0
umount /mnt 2> /dev/null || true
mount -t jffs2 /dev/mtdblock4 /mnt/
tar -C /mnt -xzf ./distro/openwrt/latest-mega2560
umount /mnt

echo "$NAME: done!"
exit 0
