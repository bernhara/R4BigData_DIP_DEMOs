#! /bin/bash

HERE=$( dirname $0 )
CMD=$( basename $0 )

DEMO_ROOT_DIR="${HERE}/.."

: ${DEFAULT_REMOTE_DATASET_DIR:=$( readlink -f "${DEMO_ROOT_DIR}/out" )}
: ${DEFAULT_REMOTE_USER:=orba6563}

: ${tmp_dir:=`mktemp -u -p "${DEMO_ROOT_DIR}/tmp"`}
# make this default for all child scripts
export tmp_dir

# limit training time to 5mn
: ${WORKER_ENV_TRAINING_TIMEOUT=2}
: ${WORKER_ENV_VERBOSE=1}

NB_WORKERs=8

trainAllWorkersArgs=''

for i in $( seq 1 ${NB_WORKERs} )
do
    worker_index=$( printf '%02d'  $i )

    eval "env_var_val=\"\${host_${worker_index}}\""
    if [ -z "${env_var_val}" ]
    then
	remote_host="localhost"
    else
	remote_host="${env_var_val}"
    fi

    eval "env_var_val=\"\${user_${worker_index}}\""
    if [ -z "${env_var_val}" ]
    then
	remote_user="${DEFAULT_REMOTE_USER}"
    else
	remote_user="${env_var_val}"
    fi

    eval "env_var_val=\"\${dir_${worker_index}}\""
    if [ -z "${env_var_val}" ]
    then
	remote_dir="${DEFAULT_REMOTE_DATASET_DIR}"
    else
	remote_dir="${env_var_val}"
    fi

    newArgElement="${remote_user}@${remote_host}:${remote_dir}"

    trainAllWorkersArgs="${trainAllWorkersArgs} ${newArgElement}"
done


if [ -z "${MLR_TRAINING_ARGs}" ]
then
    MLR_TRAINING_ARGs=''

    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --train_file=/home/dip/datasets/o4h_location_labels_classify.libsvm.train.txt"

    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --use_weight_file=false"
    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --weight_file="

    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --num_train_eval=20"
    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --num_test_eval=20"
    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --perform_test=false"

    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --num_epochs=40"
    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --num_batches_per_eval=10"

    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --lambda=0"
    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --lr_decay_rate=0.99"
    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --num_train_eval=10000"
    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --init_lr=0.01"

    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --num_comm_channels_per_client=1"
    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --staleness=2"
    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --num_app_threads=3"

    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --output_file_prefix=/tmp/ZZ_"
fi

TRAINING_ARGs="${MLR_TRAINING_ARGs}" \
WORKER_ENV_TRAINING_TIMEOUT="${WORKER_ENV_TRAINING_TIMEOUT}" \
WORKER_ENV_VERBOSE="${WORKER_ENV_VERBOSE=1}" \
"${DEMO_ROOT_DIR}/../Utils/trainAllPetuumMlrWorkers.sh" ${trainAllWorkersArgs}
