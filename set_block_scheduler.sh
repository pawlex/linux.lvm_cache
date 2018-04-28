#!/bin/sh
####
# Blanket sets all blockdev schedulers to noop
####

find /sys | egrep 'block.*scheduler' | xargs -I{} sh -c 'echo noop > {}'
find /sys | egrep 'block.*scheduler' | xargs cat | grep -v none


