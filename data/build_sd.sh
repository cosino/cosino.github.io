#!/bin/bash

#
# Initial settings
#

NAME=$(basename $0)

#
# Functions
#

function usage() {
	echo "usage: $NAME <device>" >&2
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

# Check command line
if [ $# -lt 1 ] ; then
        usage
fi
dev=$1

# Build partitions names
if echo $dev | grep -q "mmcblk" ; then
	devp1=${dev}p1
	devp2=${dev}p2
else
	devp1=${dev}1
	devp2=${dev}2
fi

# Check for root user
if [ "$(whoami)" != "root" ] ; then
        echo "$NAME: you must be root to execute this program!" >&2
        exit 1
fi

# Display current content
echo -e "$NAME: device $dev is currently hold the following data:\n"
fdisk -l $dev | sed -e 's/^/   /'
echo -e "\n$NAME: press ENTER to continue erasing ALL DATA, or just hit CTRL-C to"
echo "$NAME: stop here! :-)"
read ans

umount $devp1
umount $devp2

set -e

echo "$NAME: erasing device..."
dd if=/dev/zero of=$dev bs=512 count=1

echo "$NAME: formatting device..."
echo -e 'p\nn\np\n1\n\n+16M\nn\np\n2\n\n\nt\n1\ne\nw\n' | fdisk $dev

echo "$NAME: building boot partition..."
mkfs.vfat -n boot $devp1
mount $devp1 /mnt/
cp bootloader/at91bootstrap/latest-sdcardboot /mnt/boot.bin
cp bootloader/u-boot/latest-sdcardboot /mnt/u-boot.bin
cp bootloader/u-boot/latest-uEnv-sdcardboot /mnt/uEnv.txt
cat kernel/latest-debian kernel/latest-dtb-debian > /mnt/zImage
umount /mnt
fsck.vfat -a $devp1

echo "$NAME: building root partition..."
mkfs.ext4 -L root $devp2
tune2fs -O has_journal -o journal_data_ordered $devp2
tune2fs -O dir_index $devp2
mount $devp2 /mnt/
f=$(readlink -f distro/debian/latest)
cat ${f/-00/-}* | tar -C /mnt/ -xvjf - --strip-components=1
#tar -C /mnt/ -xvjf distro/debian/latest --strip-components=1
tar -C /mnt/ -xvjf kernel/latest-modules-debian --strip-components=1
#tar -C /mnt/ -xvjf kernel/latest-headers-debian --strip-components=1
umount /mnt
fsck.ext4 -D $devp2

echo "$NAME: done!"
exit 0
