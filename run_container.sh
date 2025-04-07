#!/bin/bash

# CONTAINER=biodiversityhorizons # for development, change this to your local Docker build name
CONTAINER=ghcr.io/uw-ssec/biodiversityhorizons

function run_with_mounts() {
    # run the container with the given directories mounted as volumes
    # and then pass any additional arguments to the container
    DATA_DIR=$1
    OUT_DIR=$2
    shift 2

    # Optional: Accept extra paths to mount for use cases like BIEN (e.g., manifest dir, tifs dir)
    EXTRA_MOUNTS=()

    while [[ "$1" == "--mount" ]]; do
        shift
        MOUNT_PATH=$1
        shift
        if [ -d "$MOUNT_PATH" ]; then
            ABS_PATH=$(realpath "$MOUNT_PATH")
            EXTRA_MOUNTS+=("-v" "$ABS_PATH:/mnt/$(basename "$ABS_PATH")")
        else
            echo "Warning: Extra mount path $MOUNT_PATH does not exist"
        fi
    done

    if [ ! -d "$DATA_DIR" ]; then
        echo "Error: Directory $DATA_DIR does not exist."
        exit 1
    fi

    if [ ! -d "$OUT_DIR" ]; then
        echo "Warning: Directory $OUT_DIR does not exist, creating it ..."
        mkdir -p "$OUT_DIR"
    fi

    docker run --rm -it \
        -v "$(realpath "$DATA_DIR")":/home/biodiversity-horizons/data-raw \
        -v "$(realpath "$OUT_DIR")":/home/biodiversity-horizons/outputs \
        "${EXTRA_MOUNTS[@]}" \
        $CONTAINER "$@"
}
