#!/usr/bin/env python

import os
import sys
import getopt
import string
import serial

NAME = os.path.basename(sys.argv[0])

def usage():
        print "usage: ", NAME ," [-h] <serdev>"
        sys.exit(2);

try:
        opts, args = getopt.getopt(sys.argv[1:], "h",
                        ["help"])
except getopt.GetoptError, err:
        # Print help information and exit:
        print str(err)
        usage()

for o, a in opts:
        if o in ("-h", "--help"):
                usage()
        else:
                assert False, "unhandled option"

# Check command line
if len(args) < 1:
    usage()
dev = args[0]

# Configure the serial connections
ser = serial.Serial(
    port	= dev,
    baudrate	= 9600,
)

while True:
	line = ser.readline()
	line = filter(lambda x: x in string.printable, line)
        print(line),

ser.close()
