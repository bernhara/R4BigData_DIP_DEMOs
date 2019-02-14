#! /bin/bash

echo "0 localhost 9999" > /tmp/sole_localhost_hostfile

# train file is the one embedded in the container

/home/dip/bin/mlrWrapper.sh \
    train_file="/home/dip/datasets/covtype.scale.train.small" \
    test_file="/home/dip/datasets/covtype.scale.test.small" \
    num_app_threads=2 \
    \
    num_comm_channels_per_client=1 \
    num_clients=1 \
    client_id=0 \
    global_data=true \
    perform_test=true \
    hostfile="/tmp/sole_localhost_hostfile" \
    output_file_prefix="/tmp/direct_mlr_out" \
    num_test_eval=20 \
    num_batches_per_epoch=5 \
    num_epochs=20 \
    lr_decay_rate=0.99 \
    num_train_eval=10000 \
    init_lr=0.01 \
    num_batches_per_eval=10 \
    lambda=0


