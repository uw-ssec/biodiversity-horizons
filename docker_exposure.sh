#!/bin/bash
source run_container.sh

if [ $# -lt 2 ]; then
    echo "usage: $0 <data_dir> <output_dir> <extra-args>"
    exit 1
fi

DATA_DIR=$1
OUT_DIR=$2
shift 2
run_with_mounts $DATA_DIR $OUT_DIR exposure -d data-raw $*
