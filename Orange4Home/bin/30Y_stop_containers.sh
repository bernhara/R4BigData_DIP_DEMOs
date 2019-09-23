#! /bin/bash

HERE=$( dirname "$0" )

for i in $( seq 0 7 )
do
    worker_container_mame=mlr_worker_0${i}
    docker stop "${worker_container_mame}"
    docker rm "${worker_container_mame}"
done
