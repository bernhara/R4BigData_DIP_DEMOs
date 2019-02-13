#! /bin/bash

#
# TODO: not yet implemented
#

echo "NOT YET IMPLEMENTED" 1>&2
exit 1

HERE=$( dirname "$0" )
COMMAND=$( basename "$0" )

#
# if an argument is provide, should be the "location number"
#

Usage () {

    msg="$1"
    (
	1>&2
	echo "Error: ${msg}"
	echo "Usage: ${COMMAND} <libsvm_file> <number of splits>"
    )
    exit 1
}


libsvm_source_file="$1"
nb_splits="$2"

if [ -z "${libsvm_source_file}" ]
then
    Usage 'missing file argument'
fi

if [ ! -r "${libsvm_source_file}" ]
then
    Usage 'file ${libsvm_source_file} could not be read'
fi

if [ ! -r "${libsvm_source_file}.meta" ]
then
    Usage 'file ${libsvm_source_file}.meta could not be read'
fi

if [ -z "${nb_splits}" ]
then
    Usage 'Missing <nb splits> arg'
fi

if [ "${nb_splits}" -eq "${nb_splits}" ] 2>/dev/null
then
    :
else
    Usage 'argument should be an integer in [2..<number of workers>]'
fi

if [ "${nb_splits}" -le 1 ]
then
    :
else
    Usage 'argument should be an integer in [2..<number of workers>]'
fi

TMP_DIR="${HERE}/tmp"

mkdir -p "${TMP_DIR}"

# get the amount of labels
num_label=$(
    l=$( grep 'num_labels:' < "${libsvm_source_file}.meta" )
    set -- l
    echo "$2"
)

for worker_index in $( seq 1 ${num_labels} )
do

    location_number=ZZZZZZZ
    awk -F -v location_number="${location_number}" '
    {
       if ($1 == location_number) {
          print $0
       }
    }
    ' < "${TMP_DIR}/data_only.csv" > "${TMP_DIR}/worker_data.csv"
    
    
if [ -n "${nb_splits}" ]
then
    file_location_suffix=".X.${nb_splits}"
else
    file_location_suffix=""
fi

cp "${TMP_DIR}/input_file_as_libsvm.train.txt" "${OUTPUT_FILE_NAME_PREFIX}.libsvm.train.txt${file_location_suffix}"
cp "${TMP_DIR}/input_file_as_libsvm.train.txt.meta" "${OUTPUT_FILE_NAME_PREFIX}.libsvm.train.txt${file_location_suffix}.meta"

