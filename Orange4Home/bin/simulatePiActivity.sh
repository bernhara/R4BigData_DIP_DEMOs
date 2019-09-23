#! /bin/bash

: ${SIMULATION_DELAY:=30s}

remote_command="set -vx; hostname; timeout ${SIMULATION_DELAY} /bin/bash -c 'mkdir -p /persist_store/DEMOs/tmp; while true; do cp -r /persist_store/DEMOs/Orange4Home/datasets/ /persist_store/DEMOs/tmp/; sync; t=$( shuf -i1-9 -n1 ); sleep 0.$t; echo \$\$; hostname; done'"
for i in 01 02 03 04 05 06 07 08
do
    ssh dip@s-pituum-$i "${remote_command}"
done

