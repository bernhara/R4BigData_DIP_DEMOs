#! /bin/bash

#
# launches mlr binary file, providing reasonable arguments in not provided
#

: ${MLR_MAIN:="/share/Petuum/SRCs_sync_with_git/branches/port_to_raspberry_pi2/bosen/app/mlr/bin/mlr_main"}
: ${TRAINING_TIMEOUT:=0}

#
# This comes from the documentation
#

# Petuum Parameters
#  hostfile, "", "Path to file containing server ip:port."
#  num_clients, 1, "Total number of clients"
#  num_app_threads, 1, "Number of app threads in this client"
#  client_id, 0, "Client ID"
#  consistency_model, "SSPPush", "SSP or SSPPush"
#  stats_path, "", "Statistics output file"
#  num_comm_channels_per_client, 1, "number of comm channels per client"
#
# Data Parameters
#  num_train_data, 0, "Number of training data. Cannot exceed the "
#      "number of data in train_file. 0 to use all train data."
#  train_file, "", "The program expects 2 files: train_file, "
#      "train_file.meta. If global_data = false, then it looks for train_file.X, "
#      "train_file.X.meta, where X is the client_id."
#  global_data, false, "If true, all workers read from the same "
#      "train_file. If false, append X. See train_file."
#  test_file, "", "The program expects 2 files: test_file, "
#      "test_file.meta, test_file must have format specified in read_format "
#      "flag. All clients read test file if FLAGS_perform_test == true."
#  num_train_eval, 20, "Use the next num_train_eval train data "
#      "(per thread) for intermediate eval."
#  num_test_eval, 20, "Use the first num_test_eval test data for "
#      "intermediate eval. 0 for using all. The final eval will always use all "
#      "test data."
#  perform_test, false, "Ignore test_file if true."
#  use_weight_file, false, "True to use init_weight_file as init"
#  weight_file, "", "Use this file to initialize weight. "
#    "Format of the file is libsvm (see SaveWeight in MLRSGDSolver)."
#
# MLR Parameters
#  num_epochs, 1, "Number of data sweeps."
#  num_batches_per_epoch, 10, "Since we Clock() at the end of each batch, "
#      "num_batches_per_epoch is effectively the number of clocks per epoch (iteration)"
#  init_lr, 0.1, "Initial learning rate"
#  lr_decay_rate, 1, "multiplicative decay"
#  num_batches_per_eval, 10, "Number of batches per evaluation"
#  lambda, 0, "L2 regularization parameter."
#
# Misc
#  output_file_prefix, "", "Results go here."
#  w_table_id, 0, "Weight table's ID in PS."
#  loss_table_id, 1, "Loss table's ID in PS."
#  staleness, 0, "staleness for weight tables."
#  row_oplog_type, petuum::RowOpLogType::kDenseRowOpLog,
#      "row oplog type"
#  oplog_dense_serialized, false, "True to not squeeze out the 0's "
#      "in dense oplog."
#  num_secs_per_checkpoint, 600, "# of seconds between each saving "
#      "to disk"
#  w_table_num_cols, 1000000,
#      "# of columns in w_table. Only used for binary LR."

default_value_for_arg_array=(
     "global_data:true"
     "perform_test:false"
     "use_weight_file:false"
     "weight_file:"
     "num_epochs:1"
     "num_batches_per_epoch:10"
     "init_lr:0.01"
     "lr_decay_rate:1"
     "num_batches_per_eval:10"
     "num_train_eval:10000"
     "num_test_eval:20"
     "lambda:0"
     "num_app_threads:2"
     "staleness:2"
     "num_comm_channels_per_client:1"
)

mlr_launch_default_args=''

for i in "${default_value_for_arg_array[@]}"
do
    arg_name="${i%:*}"
    arg_value="${i#*:}"

    if grep --silent -- "--${arg_name}=" <<< "$@"
    then
	# contains arg
	:
    else
	mlr_launch_default_args="${mlr_launch_default_args} --${arg_name}=${arg_value}"
    fi
done

mlr_launch_args="${mlr_launch_default_args} $@"

#
# check for missing args
#

mandatory_arg_array=(
   "train_file"
   "hostfile"
   "client_id"
   "num_clients"
)

for i in "${mandatory_arg_array[@]}"
do
    if grep --silent -- "--${i}=" <<< "${mlr_launch_args}"
    then
	# contains arg
	:
    else
	echo "${COMMAND}: missing mandatory args \"--${i}\"" 1>&2
	exit 1
    fi
done

#
# pre-check provided args to prevent mlr core dump
#

getArgValue () {
    set +x
    arg_name="$1"
    shift
    arg_list="$@"

    for i in ${arg_list}
    do
	arg="${i%=*}"
	if [ "${arg}" = "${arg_name}" ]
	then
	    arg_value="${i#*=*}"
	    echo "${arg_value}"
	    break
	fi
    done
    set -x
}


set -x

global_data=$( getArgValue '--global_data' ${mlr_launch_args} )
case "${global_data}" in
    "true")
	data_file_suffix=''
	;;
    "false")
	client_id=$( getArgValue '--client_id' ${mlr_launch_args} )
	data_file_suffix=".X.${client_id}"
	;;
    *)
	echo "${COMMAND}:bad value \"${global_data} for \"--global_data\"" 1>&2
	exit 1
esac

train_file_prefix=$(
    getArgValue '--train_file' ${mlr_launch_args}
)
train_file="${train_file_prefix}${data_file_suffix}"

if [ ! -r "${train_file}" ]
then
    echo "${COMMAND}: train file \"${train_file}\" could not be read" 1>&2
    exit 1
fi

test_file_prefix=$(
    getArgValue '--test_file' ${mlr_launch_args}
)
test_file="${test_file_prefix}${data_file_suffix}"

if [ -n "${test_file}" ]
then
    if [ ! -r "${test_file}" ]
    then
	echo "${COMMAND}: test file \"${test_file}\" could not be read" 1>&2
	exit 1
    fi
fi


if [ -z "${TRAINING_TIMEOUT}" ]
then
    TRAINING_TIMEOUT=0
fi

if [ "$( expr "${TRAINING_TIMEOUT}" + 0 2>/dev/null )" != "${TRAINING_TIMEOUT}" ]
then
    echo "${COMMAND}: TRAINING_TIMEOUT value \"${TRAINING_TIMEOUT}\" is not an integer value" 1>&2
    exit 1
fi

if [ "${TRAINING_TIMEOUT}" -lt 0 ]
then
    echo "${COMMAND}: TRAINING_TIMEOUT value \"${TRAINING_TIMEOUT}\" should be a positive value" 1>&2
    exit 1
fi


if [ -n "${VERBOSE}" ]
then
    echo "$0: enable verbosity" 1>&2
    set -x
fi

set -a
: ${GLOG_logtostderr:=true}
: ${GLOG_v:=-1}
: ${GLOG_minloglevel=:0}
set +a

if [ "${TRAINING_TIMEOUT}" -gt 0 ]
then
    timeout --preserve-status "${TRAINING_TIMEOUT}m" ${MLR_MAIN} "$@"
else
    ${MLR_MAIN} "$@"
fi

exit $?
