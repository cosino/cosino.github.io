#!/bin/bash

#
# Initial settings
#

NAME=$(basename $0)
BOARD=cosino

#
# Functions
#

function usage() {
	echo "usage: $NAME [OPTIONS] <device>" >&2
	echo -e "\twhere OPTIONS are:" >&2
	echo -e "\t  --add-wifi                : add wifi support" >&2
	echo -e "\t  --format-only             : format the card without adding any files" >&2
	echo -e "\t  -h|--help                 : display this help and exit" >&2
	echo -e "\tnote: you must be root to execute this program!" >&2
        exit 1
}

#
# Main
#

TEMP=$(getopt -o h --long help,add-wifi,format-only -n $NAME -- "$@")
[ $? != 0 ] && exit 1
eval set -- "$TEMP"
while true ; do
        case "$1" in
	-h|--help)
                usage
                ;;

	--add-wifi)
		ADD_WIFI=y
		shift
		;;

	--format-only)
		FORMAT_ONLY=y
		shift
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
echo -e "-------------------------------------------------------------------------------"
lsblk $dev
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
if [ -z "$FORMAT_ONLY" ] ; then
	mount $devp1 /mnt/
	cp bootloader/$BOARD/at91bootstrap/latest-sdcardboot /mnt/boot.bin
	cp bootloader/$BOARD/u-boot/latest-sdcardboot /mnt/u-boot.bin
	cp bootloader/$BOARD/u-boot/latest-uEnv-sdcardboot /mnt/uEnv.txt
	cat kernel/$BOARD/latest-debian kernel/$BOARD/latest-dtb-debian > /mnt/zImage
	umount /mnt
fi
fsck.vfat -a $devp1

echo "$NAME: building root partition..."
mkfs.ext4 -L root $devp2
tune2fs -O has_journal -o journal_data_ordered $devp2
tune2fs -O dir_index $devp2
if [ -z "$FORMAT_ONLY" ] ; then
	mount $devp2 /mnt/
	f=$(readlink -f distro/$BOARD/debian/latest)
	cat ${f/-00/-}* | tar -C /mnt/ -xvjf - --strip-components=1
	tar -C /mnt/ -xvjf kernel/$BOARD/latest-modules-debian
	tar -C /mnt/ -xvjf kernel/$BOARD/latest-headers-debian
	
	if [ -n "$ADD_WIFI" ] ; then
		if [ ! -d extensions/$BOARD ] ; then
			echo "$NAME: WARINIG! No wifi extensions to add!"
		else
			tar -C /mnt/ -xvzf \
				extensions/$BOARD/mega_2560/latest-wf111-kernel
			tar -C /mnt/ -xvzf \
				extensions/$BOARD/mega_2560/latest-wf111-userspace
	
			echo 'options unifi_sdio sdio_clock=4000' > \
					/mnt/etc/modprobe.d/unifi.conf
		fi
	fi
	
	umount /mnt
fi
fsck.ext4 -D $devp2

echo "$NAME: done!"
exit 0
