#! /bin/bash

: ${in_file_name:=""}

if [ -z "${in_file_name}" ]
then

    # create a fifo

    : ${data_in_file_pipe:=/tmp/minibatch.svm}
    
    if [ ! -p "${data_in_file_pipe}" ]
    then
	mknod --mode=a=rw "${data_in_file_pipe}" p
    fi

    in_file_name=${data_in_file_pipe}
fi

get_distance_to_optimal ()
{

    num_labels=$1
    feature_dim=$2

    computed_distance=$$
    
    shift 2
    declare -a label_lines=( "$@" )

    echo ${computed_distance}
    return

    echo '================ START'


    for i in seq ${num_labels}
    do
	echo "$i ==> ${label_lines[$i]}"
    done

    echo '================ END'

}


push_to_elastic ()
{

    distance="$1"

    : ${worker_name:=TEST}

    format='-Iseconds'


    test_time=$( date ${format} )
    sample_timestamp=$( date -u '+%Y-%m-%dT%H:%M:%SZ' )
    index="dip-distance-"$( date '+%Y-%m-%d' )

    body="
{
   \"worker_name\": \"${worker_name}\",
   \"distance\": ${distance},
   \"label\": \"test $$\",
   \"sample_date\": \"${sample_timestamp}\",
   \"test_time\": \"${test_time}\",
   \"comment\": \"none\",
   \"@timestamp\": \"${sample_timestamp}\"
}
"

    curl -X POST "localhost:9200/${index}/_doc/" -H 'Content-Type: application/json' -d "${body}"


}




read line
num_labels=${line#*:}
read line
feature_dim=${line#*:}

mapfile -n ${num_labels} weights

distance_to_optimal=$( get_distance_to_optimal ${num_labels} ${feature_dim} "${weights[@]}" )

push_to_elastic ${distance_to_optimal}
