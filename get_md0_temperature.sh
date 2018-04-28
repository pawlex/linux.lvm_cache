#!/bin/bash
####
# Gets temperature of all md0 members
####

HDDS=`find /sys | egrep 'md0.*slaves/' | cut -d "/" -f 8 | cut -b 1-3`

for HDD in $HDDS; do
 echo $HDD
 smartctl -A /dev/$HDD | egrep '^190|^194'
done
