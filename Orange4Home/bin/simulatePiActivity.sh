#! /bin/bash

# $Id: $

remote_command="timeout 3s /bin/bash -c 'while true; do touch /tmp/nothing; t=$( shuf -i1-9 -n1 ); sleep 0.0$t; echo \$\$; done'"
for i in 01 02 03 04 05 06 07 08
do
    ssh -f s-pituum-$i "${remote_command}"
done

