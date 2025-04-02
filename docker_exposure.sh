#!/bin/bash
source run_container.sh

if [ $# -lt 2 ]; then
    echo "usage: $0 <input_config_yml_file_path> <output_dir> [extra_args]"
    exit 1
fi

INPUT_CONFIG_YML_FILE=$1
OUT_DIR=$2
shift 2

DATA_DIR=$(dirname "$INPUT_CONFIG_YML_FILE")
BASENAME_YML=$(basename "$INPUT_CONFIG_YML_FILE")

run_with_mounts "$DATA_DIR" "$OUT_DIR" \
  exposure \
  -i /home/biodiversity-horizons/data-raw/"$BASENAME_YML" \
  "$@"
