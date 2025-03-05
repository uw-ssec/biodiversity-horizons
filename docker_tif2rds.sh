#!/bin/bash
source run_container.sh

if [ $# -lt 2 ]; then
    echo "Usage: $0 <input_file> <output__file> <extra-args>"
    exit 1
fi
INPUT_FILE=$1
OUT_FILE=$2
shift 2
run_with_mounts $(dirname $INPUT_FILE) $(dirname $OUT_FILE) \
tif2rds -i ./data-raw/$(basename $INPUT_FILE) \
-o ./outputs/$(basename $OUT_FILE) $*
