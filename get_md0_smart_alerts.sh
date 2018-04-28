#!/bin/bash
### 
#  QUICK CHECK TO SEE IF ANY SMART VALUES ARE NEARING THRESHOLD
###

HDDS=`find /sys | egrep 'md0.*slaves/' | cut -d "/" -f 8 | cut -b 1-3`
THRESH=30

for HDD in $HDDS; do
 #echo $HDD
 # print only where value <= 30.  A low value indicated HDD failure imminent.
 # airflow temp is the exception (190 and 194)
 RETVAL=$(smartctl -A /dev/$HDD | awk "{ if( (\$1 != 190 && \$1 != 194) && (\$1 <= 255 && \$4 <= $THRESH )) { print } }")
 if [ "$RETVAL" != "" ]; then
  echo "failure imminent on $HDD"
 fi
 #echo $RETVAL
done
