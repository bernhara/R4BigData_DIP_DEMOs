#! /bin/bash

: ${SIMULATION_DELAY:=30s}

remote_command="set -x; hostname; timeout ${SIMULATION_DELAY} /bin/bash -c 'mkdir -p /persist_store/DEMOs/tmp; while true; do touch /persist_store/DEMOs/tmp/nothing; sync; t=$( shuf -i1-9 -n1 ); sleep 0.$t; echo \$\$; hostname; done'"
for i in 01 02 03 04 05 06 07 08
do
    ssh s-pituum-$i "${remote_command}"
done

