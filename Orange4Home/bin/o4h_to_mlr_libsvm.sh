#! /bin/bash

# $Id: o4h_to_mlr_libsvm.sh,v 1.21 2019/02/13 08:55:10 orba6563 Exp $

HERE=$( dirname "$0" )
DEMO_ROOT_DIR="${HERE}/.."

: ${rebase_locations_to_zero:=true}

#
# if an argument is provide, should be the "location number"
#

if [ -n "$1" ]
then
    location_number="$1"
fi

if [ -n "${location_number}" ]
then
    if [ "${location_number}" -eq "${location_number}" ] 2>/dev/null
    then
	:
    else
	(1>&2
	    echo 'argument should be an integer in [1..<number of locations>]'
	)
	exit 1
    fi
fi

TMP_DIR="${DEMO_ROOT_DIR}/tmp"

mkdir -p "${TMP_DIR}"

: ${INPUT_FILE="${DEMO_ROOT_DIR}/reference_dataset/o4h_location_labels_classify.csv"}

: ${OUTPUT_FILE_NAME_PREFIX:=$( basename "${INPUT_FILE}" ".csv" )}

: ${KEEP_ZERO_VALUES:=""}

# dos2unix
sed -e 's/\r//' "${INPUT_FILE}" > "${TMP_DIR}/unix_input.csv"

# remove header
sed 1d "${TMP_DIR}/unix_input.csv" > "${TMP_DIR}/numbered_data_only.csv"

# remove line number field (field #1)
cut '--delimiter=,' --complement  --fields=1 "${TMP_DIR}/numbered_data_only.csv" > "${TMP_DIR}/data_only.csv"

# extract specific location of requested
if [ -n "${location_number}" ]
then
    awk -F ',' -v location_number="${location_number}" '
    {
       if ($1 == location_number) {
          print $0
       }
    }
    ' < "${TMP_DIR}/data_only.csv" > "${TMP_DIR}/worker_data.csv"
else
    cp "${TMP_DIR}/data_only.csv" "${TMP_DIR}/worker_data.csv"
fi

# convert to libsvm
awk -F ',' '
{
   # print the label
   printf "%d",$1

   # print all feature values
   for(i=2;i<NF;i++) {
      printf " %d:%.15f",i-2,$i
   }
   print ""
}
' < "${TMP_DIR}/worker_data.csv" > "${TMP_DIR}/dense_input_file_as_libsvm.train.txt"

# make it sparce
if [ -z "${KEEP_ZERO_VALUES}" ]
then
    sed \
	-e 's/ [0-9]\+:0\.0\+/ /g' \
	"${TMP_DIR}/dense_input_file_as_libsvm.train.txt" > "${TMP_DIR}/multiple_space_input_file_as_libsvm.train.txt"

    tr -s ' ' < "${TMP_DIR}/multiple_space_input_file_as_libsvm.train.txt" > "${TMP_DIR}/input_file_as_libsvm.train.txt"

else
    cp "${TMP_DIR}/dense_input_file_as_libsvm.train.txt" "${TMP_DIR}/input_file_as_libsvm.train.txt"
fi

#
# compute meta file
#

# get the total amount of data
num_train_total=$( wc -l < "${TMP_DIR}/data_only.csv" )

feature_dim=$(
    nb_separators=$( head -1 "${TMP_DIR}/data_only.csv" | tr -cd ',' | wc -c )
    expr ${nb_separators} - 1
)

num_train_this_partition=$( wc -l < "${TMP_DIR}/input_file_as_libsvm.train.txt" )

# TODO: may change
num_labels=8

echo "\
num_train_total: ${num_train_total}
num_train_this_partition: ${num_train_this_partition}
feature_dim: ${feature_dim}
num_labels: ${num_labels}
format: libsvm
feature_one_based: 0
label_one_based: 0
snappy_compressed: 0
sample_one_based: 0" \
   > "${TMP_DIR}/input_file_as_libsvm.train.txt.meta"

#
# rebase labels
#

if ${rebase_locations_to_zero}
then
    awk '
    {
       # print the rebased label
       printf "%d",$1-1

       # print all feature values
       for(i=2;i<NF;i++) {
          printf " %s",$i
       }
       print ""
    }
' < "${TMP_DIR}/input_file_as_libsvm.train.txt" > "${TMP_DIR}/rebased_input_file_as_libsvm.train.txt"
    :
else
    cp "${TMP_DIR}/input_file_as_libsvm.train.txt" "${TMP_DIR}/rebased_input_file_as_libsvm.train.txt"
fi

# for later...
#!!let num_test=$( expr ${num_train_total} / 4 )

if [ -n "${location_number}" ]
then
    file_location_suffix=".X.${location_number}"
else
    file_location_suffix=""
fi

cp "${TMP_DIR}/input_file_as_libsvm.train.txt" "${DEMO_ROOT_DIR}/out/${OUTPUT_FILE_NAME_PREFIX}.libsvm.train.txt${file_location_suffix}"
cp "${TMP_DIR}/rebased_input_file_as_libsvm.train.txt" "${DEMO_ROOT_DIR}/out/${OUTPUT_FILE_NAME_PREFIX}.libsvm.train.txt${file_location_suffix}.meta"

