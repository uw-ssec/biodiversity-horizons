#!/bin/bash
# This script runs the Docker container with the provided directories for input and output data

# Check if two arguments are provided
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <data dir> <output dir>"
    exit 1
fi

# Assign arguments to variables
DATA_DIR=$1
OUT_DIR=$2
shift 2

# Check if directories exist
if [ ! -d "$DATA_DIR" ]; then
    echo "Error: Directory $DATA_DIR does not exist."
    exit 1
fi

if [ ! -d "$OUT_DIR" ]; then
    echo "Warning: Directory $OUT_DIR does not exist, creating it ..."
    mkdir -p "$OUT_DIR"
fi

# Run the Docker container with the provided directories mounted as volumes
# TODO: Replace with the published Docker image name
docker run -v "$DATA_DIR":/home/biodiversity-horizons/data-raw \
-v "$OUT_DIR":/home/biodiversity-horizons/outputs \
biodiv $* # Pass any additional arguments to the Docker container