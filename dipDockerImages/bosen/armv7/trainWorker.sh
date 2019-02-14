#! /bin/bash

HERE=`dirname $0`
CMD=`basename $0`

ARGarray=( "$@" )

if [ -r "${HERE}/${CMD}-config" ]
then
    . "${HERE}/${CMD}-config"
fi

# Globals
: ${MLR_WRAPPER:="${HERE}/mlrWrapper.sh"}

Usage ()
{
    if [ -n "$1" ]
    then
	echo "ERROR: $1" 1>&2
    fi
    echo "Usage: ${CMD} [--dryrun] --my_wk_id=<this worker index> --peer_wk=<worker specification> [--peer_wk=<worker specification>]* -- <mlr args>" 1>&2
    echo "with <worker specification> having the following form: <worker hostname>:<petuum interworker tcp port>" 1>&2
    echo "NOTES:" 1>&2
    echo "\tworkers are indexed in appearing order (first specified worker has index 0)" 1>&2
    echo "\torder of arguments is relevant" 1>&2
    exit 1
}

realpath () {
    readlink --canonicalize "$1"
}

set -- "${ARGarray[@]}"

dryrun=false
peer_wk_list=''
this_worker_index=''
mlr_args=''

while [ -n "$1" ]
do

    case "$1" in

	"--dryrun")
	    dryrun=true
	    ;;

	--my_wk_id=*)
	    this_worker_index="${1#*=}"
	    ;;

	--peer_wk=*)
	    peer_wk_list="${peer_wk_list} ${1#*=}"
	    ;;

	"--" )
	    # remaing are mlr args
	    shift
	    mlr_args="$@"
	    # stop parsing args
	    break
	    ;;

	*)
	    Usage "Bad arg: $1"
	    ;;

    esac
    shift
done	

if [ -z ${this_worker_index} ]
then
    Usage "Missing <this worker index> argument"
fi

if [ -z "${peer_wk_list}" ]
then
    Usage "Missing remote worker specification"
fi

for opt in ${mlr_args}
do
    case "${opt}" in
	--client_id=*|--num_clients=*|--hostfile=* )
	    Usage "${opt} cannot be overwriten here" 1>&2
	    ;;
    esac
done

declare -a petuum_workers_specification_list

list_index=0
for i in ${peer_wk_list}
do
    worker_specification="$i"

    worker_index="${list_index}"

    worker_hostname="${worker_specification%:*}"
    if [ "${worker_hostname}" = "${worker_specification}" ]
    then
	Usage "Missing port in <worker specification>"
    fi

    petuum_interworker_tcp_port="${worker_specification#*:}"

    petuum_workers_specification_list[${worker_index}]="'${list_index}' '${worker_hostname}' '${petuum_interworker_tcp_port}'"
    list_index=$(( ${list_index} + 1 ))

done

##############################################################################################
#
# Utils
#

##############################################################################################

#
# Manage tmp storage

: ${remove_tmp:=true}
: ${tmp_dir:=`mktemp -u -p "${HERE}/tmp"`}

if ${remove_tmp}
then
    trap 'rm -rf "${tmp_dir}"' 0
fi

# import_logs_dir is supposed to exist
mkdir -p "${tmp_dir}"

# generate server file
(
    for worker_specification in "${petuum_workers_specification_list[@]}"
    do

        # transform the list into an array (all elements are quoted to handle empty elements (=> eval)
        eval worker_specification_array=( ${worker_specification} )
        worker_index="${worker_specification_array[0]}"
        worker_hostname="${worker_specification_array[1]}"
        petuum_interworker_tcp_port="${worker_specification_array[2]}"

        echo ${worker_index} ${worker_hostname} ${petuum_interworker_tcp_port}
    done
) > ${tmp_dir}/localserver

#
# Launch MLR on all workerd
#

nb_workers=${#petuum_workers_specification_list[@]}

if [ ${nb_workers} -ge 2 ]
then
    # Distributed version
    partitioned_mode=true
else
    partitioned_mode=false
fi


# TODO: which args should be parametrized

if [ -z "${output_prefix_file}" ]
then
    output_prefix_file="${tmp_dir}/rez"
fi

if $partitioned_mode
then
    mlr_arg_global_data=false
else
    mlr_arg_global_data=true
fi

command='
"${MLR_WRAPPER}" \
   --client_id="${this_worker_index}" \
   --num_clients=${nb_workers} \
   --global_data=${mlr_arg_global_data} \
   --hostfile=${tmp_dir}/localserver \
   \
   ${mlr_args} \
'

if ${dryrun}
then
    echo "${command}"
else
    eval "${command}"
fi
