#! /bin/bash

HERE=$( dirname $0 )
CMD=$( basename $0 )

DEMO_ROOT_DIR="${HERE}/.."

: ${REMOTE_DATASET_DIR:=/home/orba6563/PETUUM/DEMOs/Orange4Home/datasets}

# limit training time to 5mn
: ${WORKER_ENV_TRAINING_TIMEOUT=5}
: ${WORKER_ENV_VERBOSE=1}

trainAllWorkersArgs=''

for i in $( seq 1 8 )
do
    worker_index=$( printf '%02d'  $i )

    eval "env_var_val=\"\${host_${worker_index}}\""
    if [ -z "${env_var_val}" ]
    then
	remote_host="s-pituum-${worker_index}"
    else
	remote_host="${env_var_val}"
    fi

    eval "env_var_val=\"\${user_${worker_index}}\""
    if [ -z "${env_var_val}" ]
    then
	remote_user="orba6563"
    else
	remote_user="${env_var_val}"
    fi

    eval "env_var_val=\"\${dir_${worker_index}}\""
    if [ -z "${env_var_val}" ]
    then
	remote_dir="${REMOTE_DATASET_DIR}"
    else
	remote_dir="${env_var_val}"
    fi

    newArgElement="${remote_user}@${remote_host}:${remote_dir}"

    trainAllWorkersArgs="${trainAllWorkersArgs} ${newArgElement}"
done

exit 1

    eval ': ${worker_hostname_${worker_index}:="s-pituum-${worker_index}"'
P    eval ': ${worker_remote_dataset_dir_${worker_index}":="${REMOTE_DATASET_DIR}"}'



: ${worker_hostname_01:="s-pituum-01"}
: ${worker_hostname_02:="s-pituum-02"}
: ${worker_hostname_03:="s-pituum-03"}
: ${worker_hostname_04:="s-pituum-04"}
: ${worker_hostname_05:="s-pituum-05"}
: ${worker_hostname_06:="s-pituum-06"}
: ${worker_hostname_07:="s-pituum-07"}

: ${worker_remote_user_01:="orba6563"}

if [ -z "${MLR_TRAINING_ARGs}" ]
then
    MLR_TRAINING_ARGs=''

    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --train_file=/home/dip/datasets/zz.txt"

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
"${DEMO_ROOT_DIR}/../Utils/trainAllPetuumMlrWorkers.sh" \
${worker_remote_user_01}@${worker_hostname_01}:${REMOTE_DATASET_DIR}
