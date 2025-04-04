#!/bin/bash
source run_container.sh

# Initialize default values
MANIFEST_DIR=""
RANGES_DIR=""
GRID_FILE=""
OUT_DIR=""
SPECIES=""
PARALLEL="FALSE"
WORKERS=4

# Parse named arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --manifest) MANIFEST_DIR="$2"; shift ;;
    --ranges) RANGES_DIR="$2"; shift ;;
    --grid) GRID_FILE="$2"; shift ;;
    --output) OUT_DIR="$2"; shift ;;
    --species) SPECIES="$2"; shift ;;
    --parallel) PARALLEL="$2"; shift ;;
    --workers) WORKERS="$2"; shift ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

# Check required arguments
if [[ -z "$MANIFEST_DIR" || -z "$RANGES_DIR" || -z "$GRID_FILE" || -z "$OUT_DIR" ]]; then
  echo "Usage: $0 --manifest <manifest_dir> --ranges <ranges_dir> --grid <grid_file> --output <output_dir> [--species <name>] [--parallel <TRUE/FALSE>]"
  exit 1
fi

# Build optional species flag
SPECIES_ARG=()
if [ -n "$SPECIES" ]; then
  SPECIES_ARG=(-s "$SPECIES")
fi

# Run with mounts
run_with_mounts "./data-raw" "$OUT_DIR" \
  --mount "$MANIFEST_DIR" \
  --mount "$RANGES_DIR" \
  convert_bienranges \
  -m /mnt/$(basename "$MANIFEST_DIR")/manifest.parquet \
  -r /mnt/$(basename "$RANGES_DIR") \
  -g ./data-raw/$(basename "$GRID_FILE") \
  -o ./outputs \
  -a any \
  -p "$PARALLEL" \
  -w "$WORKERS" \
  "${SPECIES_ARG[@]}"
