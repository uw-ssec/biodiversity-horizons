#!/bin/bash
source run_container.sh

if [ $# -lt 2 ]; then
    echo "usage: $0 <input_config_yml_file_path> <output_dir>"
    exit 1
fi

INPUT_CONFIG_YML_FILE=$1
OUT_DIR=$2
shift 2

run_with_mounts $(dirname $INPUT_CONFIG_YML_FILE) $OUT_DIR \
exposure -i ./data-raw/$(basename $INPUT_CONFIG_YML_FILE)
