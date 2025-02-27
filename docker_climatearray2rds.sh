#!/bin/bash
source run_container.sh

# Check for required arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <input_directory> <output_directory> <extra-args>"
    exit 1
fi

# Convert relative paths to absolute paths
INPUT_DIR=$(realpath "$1")
OUT_DIR=$(realpath "$2")

shift 2

# Run the container with mounted directories
run_with_mounts "$INPUT_DIR" "$OUT_DIR" \
climatearray2rds -i /home/biodiversity-horizons/data-raw \
-o /home/biodiversity-horizons/outputs "$@"
