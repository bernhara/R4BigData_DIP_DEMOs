#! /bin/bash

HERE=$( dirname "$0" )

for i in $( seq 0 7 )
do
    worker_container_mame=mlr_worker_0${i}
    docker stop "${worker_container_mame}"
    docker rm "${worker_container_mame}"
done

/home/orba6563/bin/weaveworks4Dip.sh --discovery-mode  stop
sleep 3
/home/orba6563/bin/weaveworks4Dip.sh --discovery-mode  start
sleep 3

"${HERE}"/DEMO_train_8_LocalWorkers.sh &
SIMULATION_DELAY=60s "${HERE}/simulatePiActivity.sh &

wait
