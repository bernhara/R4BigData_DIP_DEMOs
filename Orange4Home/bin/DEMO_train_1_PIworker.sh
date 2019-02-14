#! /bin/bash

HERE=$( dirname $0 )
CMD=$( basename $0 )

DEMO_ROOT_DIR="${HERE}/.."

: ${REMOTE_DATASET_DIR:=/home/orba6563/PETUUM/DEMOs/Orange4Home/datasets}

: ${worker_hostname_01:="s-pituum-01"}

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
"${DEMO_ROOT_DIR}/../Utils/trainAllPetuumMlrWorkers.sh" \
${worker_remote_user_01}@${worker_hostname_01}:${REMOTE_DATASET_DIR}
