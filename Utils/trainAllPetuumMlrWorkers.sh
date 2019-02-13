#! /bin/bash

HERE=`dirname $0`
CMD=`basename $0`

ARGarray=( "$@" )

if [ -r "${HERE}/${CMD}-config" ]
then
    . "${HERE}/${CMD}-config"
fi


: ${WORKER_DEFAULT_INSTALL_DIR:=`realpath "${HERE}"`}
: ${LOCAL_OUTPUT_DIR:="${HERE}/out"}

: ${worker_remote_output_prefix:=/tmp/mlr_out}

#
# list of extra args added to the trainWorker command
#
: ${TRAINING_TUNING_ARGs:=''}


Usage ()
{
    if [ -n "$1" ]
    then
	echo "ERROR: $1" 1>&2
    fi
    echo "Usage: ${CMD} [--dryrun] <worker specification> [<worker specification>]*" 1>&2
    echo "with <worker specification> having the following form: [<remote user>@]<worker hostname>[:<mlr remote folder installation dir if differs from default>]" 1>&2
    echo "NOTES: workers are indexed in appearing order (first specified worker has index 0)" 1>&2
    exit 1
}

realpath () {
    readlink --canonicalize "$1"
}

set -- "${ARGarray[@]}"

dryrun=false
if [ "$1" = "--dryrun" ]
then
    dryrun=true
    shift 1
fi

#
# parse worker specification list
#
declare -a petuum_worker_args_table

list_index=0
while [ -n "$1" ]
do
    worker_specification="$1"

    worker_index="${list_index}"

    worker_ssh_specification="${worker_specification%:*}"
    worker_ssh_hostname="${worker_ssh_specification#*@}"
    worker_ssh_remote_user="${worker_ssh_specification%@*}"
    if [ "${worker_ssh_remote_user}" = "${worker_ssh_specification}" ]
    then
	# no remote user specified
	worker_ssh_remote_user=""
    fi

    worker_ssh_remote_path_specification="${worker_specification#*:}"
    if [ "${worker_ssh_remote_path_specification}" = "${worker_specification}" ]
    then
	# no remote path specified => same path
	worker_ssh_remote_path_specification="${WORKER_DEFAULT_INSTALL_DIR}"
    fi

    petuum_worker_args_table[${worker_index}]="${list_index} ${worker_ssh_remote_user} ${worker_ssh_hostname} ${worker_ssh_remote_path_specification}"
    list_index=$(( ${list_index} + 1 ))

    shift

done

if [ ${#petuum_worker_args_table[@]} -eq 0 ]
then
    Usage "Missing worker specification"
fi

##############################################################################################

#
# Manage tmp storage

: ${remove_tmp:=true}
: ${tmp_dir:=`mktemp -u -p "${HERE}/tmp"`}

: ${use_weave_net:=true}

if ${remove_tmp}
then
    trap 'rm -rf "${tmp_dir}"' 0
fi

mkdir -p "${tmp_dir}"

mkdir -p "${LOCAL_OUTPUT_DIR}"

#
# Launch MLR on all workerd
#

weave_net_hostname () {
    dockerd_host_hostname="$1"

    dockerd_host_hostname_number="${dockerd_host_hostname##*-}"

    overlay_hostname="mlr_worker_${dockerd_host_hostname_number}"

    echo "${overlay_hostname}"
}

build_trainWorker_peer_arg_list () {

    worker_launcher_common_args=''

    for worker_specification in "${petuum_workers_specification_list[@]}"
    do
	set -- ${worker_specification}
	worker_index="$1"
	worker_ssh_remote_user="$2"
	worker_ssh_hostname="$3"
	worker_ssh_remote_path_specification="$4"

	if ${use_weave_net}
	then
	    worker_hostname=$( weave_net_hostname "${worker_ssh_hostname}" )
	else
	    worker_hostname="${worker_ssh_hostname}"
	fi

	worker_launcher_common_args="${worker_launcher_common_args}  --peer_wk=${worker_hostname}:${petuum_interworker_tcp_port}"

    done

    echo "${worker_launcher_common_args}"

}

build_worker_mlr_cmd () {

    worker_index="$1"
    worker_ssh_remote_user="$2"
    worker_ssh_hostname="$3"
    worker_ssh_remote_path_specification="$4"

    if [ -n "${worker_ssh_remote_user}" ]
    then
	worker_ssh_remote_specification="${worker_ssh_remote_user}@${worker_ssh_hostname}"
    else
	worker_ssh_remote_specification="${worker_ssh_hostname}"
    fi

    if ${use_weave_net}
    then
	overlay_worker_hostname=`weave_net_hostname ${worker_ssh_hostname}`
	local_worker_command="\
DOCKER_HOST=unix:///var/run/weave/weave.sock ORIG_DOCKER_HOST= \
docker run \
   --rm -it \
   --name ${overlay_worker_hostname} \
   \
   -v ${worker_ssh_remote_path_specification}/datasets:/home/dip/datasets:ro \
   -v ${worker_remote_output_prefix}/:/tmp/mlr_out/ \
   \
   -v /home/orba6563/tmp/bin:/home/dip/bin
   \
   -e DATAFILE_NAME_PREFIX=PITUUM_CLUSTER_DEMO \
   -e DATASETS_DIR=/home/dip/datasets \
   \
   s-eunuc:5000/dip/mlr-worker:latest \
   /home/dip/bin/trainWorker.sh --my_wk_id=${worker_index} ${trainWorker_peer_arg_list} -- ${TRAINING_TUNING_ARGs} \
"
    else

	# FIXME: is no more up to date
	local_worker_command="\
${worker_ssh_remote_path_specification}/trainWorker.sh --output_prefix_file ${worker_remote_output_prefix} ${worker_index} ${trainWorker_peer_arg_list} \
"
    fi

    remote_command="ssh \
-tt \
-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
${worker_ssh_remote_specification} \
\
/bin/bash -c '${local_worker_command}' \
\
"

    echo "${remote_command}"
}

#######################################################################
#
# Main
#
#######################################################################

# compute globals

: ${petuum_interworker_tcp_port:=9999}
petuum_workers_specification_list=${petuum_worker_args_table}
num_clients=${#petuum_workers_specification_list[@]}
trainWorker_peer_arg_list=$( build_trainWorker_peer_arg_list )

# lauch all workers

for worker_specification in "${petuum_workers_specification_list[@]}"
do
    set -- ${worker_specification}
    worker_index="$1"
    worker_ssh_remote_user="$2"
    worker_ssh_hostname="$3"
    worker_ssh_remote_path_specification="$4"

    launch_command=$( build_worker_mlr_cmd "${worker_index}" "${worker_ssh_remote_user}" "${worker_ssh_hostname}" "${worker_ssh_remote_path_specification}" )

    if $dryrun
    then
	echo "** would execute **: ${launch_command}"
    else
	(
	    ${launch_command}
	    echo "$? ${worker_index} ${worker_ssh_hostname}">${tmp_dir}/worker-${worker_index}-${worker_ssh_hostname}.exit_status
	)
        exit 1
#	) 2>${tmp_dir}/worker-${worker_index}-${worker_ssh_hostname}.stderr.log  1>${tmp_dir}/worker-${worker_index}-${worker_ssh_hostname}.stdout.log &

    fi

    
done

# wait for termination af all lauched workers
wait

one_has_failed=false

# test if some failed
exit_status_file_list=$( ls -1 ${tmp_dir}/worker-*.exit_status  2>/dev/null )
for exit_status_file in ${exit_status_file_list}
do
    set -- $( cat "${exit_status_file}" )
    exit_status=$1
    worker_index=$2
    woker_ssh_hostname=$3
    if [ "${exit_status}" -ne "0" ]
    then

	one_has_failed=true

	(
	    echo "ERROR: worker #${worker_index} ($worker_ssh_hostname) FAILED"
	    echo
	    echo "STDOUT:"
	    echo
	    echo "================================================================================="
	    cat "${tmp_dir}/worker-${worker_index}-${worker_ssh_hostname}.stdout.log"
	    echo "================================================================================="
	    echo
	    echo "STDERR:"
	    echo
	    echo "================================================================================="
	    cat "${tmp_dir}/worker-${worker_index}-${worker_ssh_hostname}.stderr.log"
	    echo "================================================================================="
	) 1>&2
    fi
done

#
# if none has failed, we get the generated weight file
#

# it is located on worker 0 (the first in the list)

set -- ${petuum_workers_specification_list[0]}
worker_ssh_remote_user="$2"
worker_ssh_hostname="$3"

remote="${worker_ssh_hostname}:${worker_remote_output_prefix}*"

if [ -n "${worker_ssh_remote_user}" ]
then
    remote="${worker_ssh_remote_user}@${remote}"
fi

command="scp -r \"${remote}\" \"${LOCAL_OUTPUT_DIR}\""
if $dryrun
then
    echo "** would execute **: ${command}"
else
    if ! ${one_has_failed}
    then
	eval "${command}"
    fi
fi
