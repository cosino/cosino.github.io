#!/bin/bash

#
# Initial settings
#

NAME=$(basename $0)
VALID_BOARDS="cosino enigma"
declare -A VALID_EXTENSIONS=(	\
	[cosino]="mega_256"	\
	[enigma]="industrial"	\
)

#
# Functions
#

function usage() {
	echo "usage: $NAME [OPTIONS] <device>" >&2
	echo -e "\twhere OPTIONS are:" >&2
	echo -e "\t  --board <name>            : board to manage (default is \"$board\")" >&2
	echo -e "\t  --extension <name>        : extension to manage (default is according to selected board)" >&2
	echo -e "\t  --format-only             : format the card without adding any files" >&2
	echo -e "\t  -h|--help                 : display this help and exit" >&2
	echo -e "\tnote: you must be root to execute this program!" >&2
        exit 1
}

#
# Main
#

# Default settings
board=cosino

# Check command line
TEMP=$(getopt -o h --long help,board:,extension:,format-only -n $NAME -- "$@")
[ $? != 0 ] && exit 1
eval set -- "$TEMP"
while true ; do
        case "$1" in
	-h|--help)
                usage
                ;;

	--board)
		board=$2
		if ! [[ "$VALID_BOARDS" =~ "$board" ]] ; then
			echo "$NAME: invalid board $board, must be in: $VALID_BOARDS" >&2
			exit 1
		fi

		shift 2
	;;

	--extension)
		extension=$2
		if ! [[ "${VALID_EXTENSIONS[$board]}" =~ "$extension" ]] ; then
			echo "$NAME: invalid board $extension, must be in: ${VALID_EXTENSIONS[$board]}" >&2
			exit 1
		fi

		shift 2
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

[ -z "$extension" ] && extension=${VALID_EXTENSIONS[$board]%% *}
echo "$NAME: preparing SD for ${board}_${extension}"

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
	cp bootloader/$board/at91bootstrap/latest-sdcardboot /mnt/boot.bin
	cp bootloader/$board/u-boot/latest-sdcardboot /mnt/u-boot.bin
	cp bootloader/$board/u-boot/latest-uEnv-sdcardboot /mnt/uEnv.txt
	cat kernel/$board/latest-debian kernel/$board/latest-dtb-debian > /mnt/zImage
	umount /mnt
fi
fsck.vfat -a $devp1

echo "$NAME: building root partition..."
mkfs.ext4 -L root $devp2
tune2fs -O has_journal -o journal_data_ordered $devp2
tune2fs -O dir_index $devp2
if [ -z "$FORMAT_ONLY" ] ; then
	mount $devp2 /mnt/
	f=$(readlink -f distro/$board/debian/latest)
	cat ${f/-00/-}* | tar -C /mnt/ -xvjf - --strip-components=1
	tar -C /mnt/ -xvjf kernel/$board/latest-modules-debian
	tar -C /mnt/ -xvjf kernel/$board/latest-headers-debian
	
	if [ ! -d extensions/$board/$extension/ ] ; then
		echo "$NAME: WARINIG! No ${board}'s extensions to add!"
	else
		tar -C /mnt/ -xvjf extensions/$board/$extension/latest-rootfs
	fi

	# Add the swapfile
	fallocate -l 128M /mnt/swap
	chown root:root /mnt/swap
	chmod 0600 /mnt/swap
	mkswap /mnt/swap
	echo "/swap none swap defaults 0 0" >> /mnt/etc/fstab
	
	umount /mnt
fi
fsck.ext4 -D $devp2

echo "$NAME: done!"
exit 0
