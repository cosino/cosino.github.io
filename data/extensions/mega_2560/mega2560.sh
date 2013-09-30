#!/bin/bash

NAME=$(basename $0)

PORT=/dev/ttyS3
GPIO_NUM=110
GPIO_NAME=pioD14

#
# Sub-commands
#

function mega2560_prog () {
	avrdude -V -F -c wiring -x gpio=$GPIO_NAME \
		-b 115200 -p atmega2560 -P $PORT \
		-U flash:w:$1
}

function mega2560_reset () {
	echo 1 > /sys/class/gpio/$GPIO_NAME/value
	sleep 1
	echo 0 > /sys/class/gpio/$GPIO_NAME/value
}

#
# Main
#

if [ $# -lt 1 ] ; then
	echo "usage: $NAME <command> [<options>]" >&2
	echo "   <command> can be:" >&2
	echo "      prog <file.hex>: program mega2560 with code in file.hex" >&2
	echo "      reset          : hard reset mega2560" >&2
	exit 1
fi
cmd=$1
opt=$2

set +e

bash -c "echo $GPIO_NUM > /sys/class/gpio/export" 2>/dev/null
echo out > /sys/class/gpio/$GPIO_NAME/direction

case $cmd in
prog)
	mega2560_prog $2
	;;
reset)
	mega2560_reset
	;;
*)
	echo "$NAME: invalid command \"$cmd\"" >&2
	exit 1
	;;
esac

exit 0
