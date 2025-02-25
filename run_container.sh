#!/bin/bash
# CONTAINER=biodiv # for development, change this to the name of your local Docker ccontainer build
CONTAINER=ghcr.io/uw-ssec/biodiversity-horizons

function run_with_mounts() {

    # run the container with the given directories mounted as volumes
    # and then pass any additional arguments to the container
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

    docker run -v "$DATA_DIR":/home/biodiversity-horizons/data-raw \
    -v "$OUT_DIR":/home/biodiversity-horizons/outputs \
    $CONTAINER $* # Pass any additional arguments to the Docker container
}
