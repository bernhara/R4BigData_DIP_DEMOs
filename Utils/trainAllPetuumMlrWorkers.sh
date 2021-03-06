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
: ${TRAINING_ARGs:=''}
: ${TRAIN_WORKER_ARGs:=''}
: ${WORKER_ENV_TRAINING_TIMEOUT:=5}
: ${WORKER_ENV_VERBOSE:=''}

: ${DOCKER_TRAIN_IMAGE_NAME:=s-eunuc:5000/dip/mlr-worker:$( uname -m )-latest}

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

: ${use_weavenet:=true}

if ${remove_tmp}
then
    trap 'rm -rf "${tmp_dir}"' 0
fi

mkdir -p "${tmp_dir}"

mkdir -p "${LOCAL_OUTPUT_DIR}"

#
# Launch MLR on all workerd
#

#
# generate a uid constant for this run which will be appended to all hostnames
#
typeset -r overlay_hostname_uid_suffix=$( mktemp -u XXXXXX | tr '[:upper:]' '[:lower:]' )

weave_overlay_worker_fixed_ip_address () {

    # tODO: the address range is hard coded
    # depends how weave has been launched

    dockerd_host_hostname="$1" # NOT USED
    worker_index="$2"

    weavenet_fixed_ip_address_suffix_int=$(( 100 + ${worker_index} ))
    weavenet_fixed_ip_address=$( printf "10.32.1.%03d" "${weavenet_fixed_ip_address_suffix_int}" )

    echo "${weavenet_fixed_ip_address}"
}

overlay_net_hostname () {

    dockerd_host_hostname="$1" # NOT USED
    worker_index="$2"

    overlay_hostname=$( printf "wkr%02d-%s" "${worker_index}" "${overlay_hostname_uid_suffix}" )

    if ${use_weavenet}
    then
	overlay_hostname="${overlay_hostname}.weave.local"
    fi

    echo "${overlay_hostname}"
}

container_worker_name () {

    worker_index="$1"

    container_name=$( printf "mlr_worker_%02d" "${worker_index}" )

    echo "${container_name}"
}

build_trainWorker_peer_arg_list () {

    worker_launcher_common_args=''

    for worker_specification in "$@"
    do
	set -- ${worker_specification}
	worker_index="$1"
	worker_ssh_remote_user="$2"
	worker_ssh_hostname="$3"
	worker_ssh_remote_path_specification="$4"

	if ${use_weavenet}
	then
	    worker_hostname=$( weave_overlay_worker_fixed_ip_address "${worker_ssh_hostname}" "${worker_index}" )
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

    container_name=$( container_worker_name "${worker_index}" )

    if [ -n "${worker_ssh_remote_user}" ]
    then
	worker_ssh_remote_specification="${worker_ssh_remote_user}@${worker_ssh_hostname}"
    else
	worker_ssh_remote_specification="${worker_ssh_hostname}"
    fi

    if ${use_weavenet}
    then

	set -x
	# FIXME: not used
	overlay_worker_hostname=$( overlay_net_hostname "${worker_ssh_hostname}" "${worker_index}" )

	weavenet_fixed_ip_address=$( weave_overlay_worker_fixed_ip_address "${worker_ssh_hostname}" "${worker_index}" )
	weavenet_fixed_ip_address_configuration_env="${weavenet_fixed_ip_address}/24"

	local_worker_command="\
DOCKER_HOST=unix:///var/run/weave/weave.sock ORIG_DOCKER_HOST= \
docker run \
   -t \
   --rm \
   --name "${container_name}" \
   \
   -e TRAINING_TIMEOUT="${WORKER_ENV_TRAINING_TIMEOUT}" \
   -e VERBOSE="${WORKER_ENV_VERBOSE}" \
   -e STATS_WORKER_NAME="${container_name}" \
   \
   -e "WEAVE_CIDR=${weavenet_fixed_ip_address_configuration_env}"
   \
   -v ${worker_ssh_remote_path_specification}/:/home/dip/datasets/:ro \
   -v ${worker_remote_output_prefix}/:/home/dip/mlr_out/ \
   \
   "${DOCKER_TRAIN_IMAGE_NAME}" \
   /home/dip/bin/trainWorker.sh --my_wk_id=${worker_index} ${trainWorker_peer_arg_list} ${TRAIN_WORKER_ARGs} -- ${TRAINING_ARGs} \
"
	set +x

    else

	# FIXME: is no more up to date
	Usage "non docker version not yet implemented"
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
petuum_workers_specification_table=( "${petuum_worker_args_table[@]}" )
num_clients=${#petuum_workers_specification_table[@]}
trainWorker_peer_arg_list=$( build_trainWorker_peer_arg_list "${petuum_workers_specification_table[@]}" )

# lauch all workers

for worker_specification in "${petuum_workers_specification_table[@]}"
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
	    echo "+++++++++++++++++++++++++++++= # ${worker_index} TO STDOUT"
	    echo "++++++++++++++++++++++++++++# ${worker_index} TO STERR" 1>&2
	    ${launch_command}
	    echo "$? ${worker_index} ${worker_ssh_hostname}">${tmp_dir}/worker-${worker_index}-${worker_ssh_hostname}.exit_status
	) 2>${tmp_dir}/worker-${worker_index}-${worker_ssh_hostname}.stderr.log  1>${tmp_dir}/worker-${worker_index}-${worker_ssh_hostname}.stdout.log &

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
    worker_ssh_hostname=$3
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
	) | sed -e "s/^/WORKER #${worker_index}:/" 1>&2
    fi
done

#
# if none has failed, we get the generated weight file
#

# it is located on worker 0 (the first in the list)

set -- ${petuum_workers_specification_table[0]}
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
