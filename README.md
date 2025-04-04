<!-- README.md is generated from README.Rmd. Please edit that file -->

# Biodiversity Horizons

<!-- badges: start -->

[![codecov](https://codecov.io/gh/uw-ssec/biodiversity-horizons/graph/badge.svg?token=ee1oeNuMlb)](https://codecov.io/gh/uw-ssec/biodiversity-horizons)

<!-- badges: end -->

**Biodiversity Horizons** is an R-based project for processing climate data and
analyzing primate distributions. It can be used locally (in R/RStudio) or run
inside a Docker container for consistent dependencies across systems.

## Installation

You can install the development version of biodiversityhorizons like so:

```r
# Install devtools if not already installed
install.packages("devtools")

# Install biodiversityhorizons package
devtools::install_github("uw-ssec/biodiversity-horizons")
```

## Example

This is a basic example which shows you how to solve a common problem:

```r
library(biodiversityhorizons)
## basic example code
```

#### For more advanced usage, refer to our [**Contributing Guidelines**](./Contributing.md)

## Docker Usage

We provide a Docker image so you can run the data processing scripts in a
containerized environment, ensuring consistent R dependencies.

### 1. Prerequisites

- #### Install Docker: Refer to [**Install Docker Desktop Guide**](https://docs.docker.com/desktop/)

### 2. Pull the Docker Image

```
docker pull ghcr.io/uw-ssec/biodiversityhorizons:latest
```

If this succeeds, the image is downloaded locally.

#### (Optional) GitHub Container Registry Authentication:

If pulling fails with a `“denied”` error, generate a
[Personal Access Token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)
(classic) with `read:packages` scope and run:

```
echo YOUR_TOKEN | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
```

### 3. Obtain or Prepare your `data-raw/` and `outputs/` folders

- #### Option A: Using Your Own Data

  If you already have .rds files:

  - Create a local folder (e.g., ~/my_data) and place your .rds files there.
  - That folder will be mounted as `/home/biodiversity-horizons/data-raw` in the
    container.

- #### Option B: Cloning This Repo for Sample Data

  If you need sample .rds files provided by this project (in data-raw/):

  **1. Clone this repository:**

  ```
  git clone https://github.com/uw-ssec/biodiversity-horizons.git
  ```

  ```
  cd biodiversity-horizons
  ```

  **2. Use the included data-raw/ folder. It contains sample .rds files.**

  **3. [Optional: If the folder does not exist] Run:** `mkdir -p outputs`

### 4. Run the commands on the docker container using run_container.sh

#### Running exposure workflow:

- Identify your directories:
  - A data folder with the shp_config.yml (for shapefile-derived species data)
    or bien_config.yml (for BIEN species data) and relevant .rds files (either
    your own or from the cloned data-raw/)
  - An outputs directory for script results
  - Example command shown below:

##### For SHP:

```
sh docker_exposure.sh "./data-raw/shp_config.yml" "./outputs"
```

##### For BIEN:

```
sh docker_exposure.sh "./data-raw/bien_config.yml" "./outputs"
```

#### Running conversion utilities:

- .shp to .rds (see below on how to pass additional arguments)
  - use -e or --extent for extent
  - use -r or --resolution for resolution
  - use -c or --crs for crs
  - use -m or --realm for realm
  - use -p or --parallel for parallel
  - use -w or --workers for workers
  ```
  sh docker_shp2rds.sh  "./data-raw/tier_1/data/species_ranges/subset_amphibians.shp" "./data-raw/species_new.rds"
  ```
- .tif to .rds

  ```
  sh docker_tif2rds.sh "./data-raw/tier_1/data/climate/historical.tif" "./data-raw/historical_climate_data_new.rds"
  ```

  or (if range is an argument)

  ```
  sh docker_tif2rds.sh "./data-raw/tier_1/data/climate/ssp585.tif" "./data-raw/future_climate_data_new.rds" -y "2015:2100"
  ```

- BIEN Climate .tif to .rds

```
sh docker_bienclimate2rds.sh "./data-raw/tier_1/data/climate/historical.tif" "./outputs/bien_historical_climate_data.rds"
```

- BIEN Species Ranges Conversion

```
sh docker_convert_bienranges.sh \
  --manifest ~/Desktop/home/bsc23001/projects/bien_ranges/data/oct18_10k/manifest \ #replace with your local path
  --ranges ~/Desktop/home/bsc23001/projects/bien_ranges/data/oct18_10k/tifs \ #replace with your local path
  --grid ./data-raw/global_grid.tif \
  --output ./data-raw/bien_ranges/processed \
  --parallel FALSE \
  --workers 4
```

or subset of species

```
sh docker_convert_bienranges.sh \
  --manifest ~/Desktop/home/bsc23001/projects/bien_ranges/data/oct18_10k/manifest \ #replace with your local path
  --ranges ~/Desktop/home/bsc23001/projects/bien_ranges/data/oct18_10k/tifs \ #replace with your local path
  --grid ./data-raw/global_grid.tif \
  --output ./data-raw/bien_ranges/processed \
  --parallel FALSE \
  --workers 4 \
  --species "Aa mathewsii"

```

## Setup and Run Apptainer

**Step 1: Navigate to the biodiversity-horizons project directory**

```
cd ~/Desktop/biodiversity-horizons  # Adjust this path as needed
```

**Step 2: Run Docker with Apptainer inside an AMD64 environment**

```
docker run --rm -it --privileged \
  --platform linux/amd64 \
  -v $(pwd):/mnt \
  godlovedc/apptainer bash
```

### Inside Docker Container:

**Step 3: Pull and convert the Docker image into a .sif file for Apptainer**

```
apptainer pull /mnt/biodiversityhorizons.sif docker://ghcr.io/uw-ssec/biodiversityhorizons:latest
```

**Step 4: Verify the .sif file was created**

```
ls -l /mnt/biodiversityhorizons.sif
```

**Step 5: Run Apptainer shell and mount required directories**

```
apptainer shell --bind /mnt/data-raw:/home/biodiversity-horizons/data-raw,/mnt/outputs:/home/biodiversity-horizons/outputs /mnt/biodiversityhorizons.sif
```

### Inside Apptainer Shell:

**Step 6: Move to the correct working directory**

```
cd /home/biodiversity-horizons
```

Inside the Apptainer shell, verify the `data-raw/` and `outputs/` folders are
available:

```
ls -l /home/biodiversity-horizons/data-raw/
```

```
ls -l /home/biodiversity-horizons/outputs/
```

**Step 7: Run the R exposure calculation script (you can modify the arguments by
updating the shp_config.yml or bien_config.yml file)**

##### For SHP:

```bash
Rscript scripts/main.R exposure -i data-raw/shp_config.yml
```

##### For BIEN:

```bash
Rscript scripts/main.R exposure -i data-raw/bien_config.yml
```

## Running and Developing

Instructions to run and contribute to the portal can be found in
[**Contributing Guidelines**](./CONTRIBUTING.md)

Please follow our [**UW-SSEC Code of Conduct**](./CODE_OF_CONDUCT.md) in all
interactions. For questions or issues, open an
[**Issue**](https://github.com/uw-ssec/biodiversity-horizons/issues) or contact
the maintainers.
