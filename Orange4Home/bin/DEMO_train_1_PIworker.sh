#! /bin/bash

HERE=$( dirname $0 )
CMD=$( basename $0 )

DEMO_ROOT_DIR="${HERE}/.."

: ${REMOTE_ROOT_DIR:=/home/orba6563/PETUUM/DEMOs}

: ${worker_hostname_01:="s-pituum-01"}

: ${worker_remote_user_01:="orba6563"}

if [ -z "${MLR_TRAINING_ARGs}" ]
then
    MLR_TRAINING_ARGs=''

    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --train_file=/home/dip/datasets/o4h_location_labels_classify.libsvm.train.txt"
    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --use_weight_file=false"
    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --weight_file="

    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --num_comm_channels_per_client=1"
    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --staleness=2"
    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --num_app_threads=3"
    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --num_batches_per_epoch=10 --num_epochs=40"
    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --output_file_prefix="${output_prefix_file}""
    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --lr_decay_rate=0.99 --num_train_eval=10000"
    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --global_data=${mlr_arg_global_data}"
    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --init_lr=0.01"
    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --num_test_eval=20 --perform_test=false --num_batches_per_eval=10 --lambda=0"
    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --hostfile=${tmp_dir}/localserver"
    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --train_file=${train_file}"

    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --client_id="${this_worker_index}""
    MLR_TRAINING_ARGs="${MLR_TRAINING_ARGs} --num_clients=${nb_workers}"
fi

TRAINING_TUNING_ARGs="${MLR_TRAINING_ARGs}" \
"${HERE}/../Utils/trainAllPetuumMlrWorkers.sh" \
    ${worker_remote_user_01}@${worker_hostname_01}:${REMOTE_ROOT_DIR}
