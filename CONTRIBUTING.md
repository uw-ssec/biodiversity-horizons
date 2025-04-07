# Contributing to Biodiversity Horizons

Thank you for your interest in contributing to **Biodiversity Horizons**! This
guide provides step-by-step instructions to set up the project locally, run the
R scripts, and use Docker for containerized execution. Follow these guidelines
to get started.

Read our
[Code of Conduct](https://github.com/uw-ssec/code-of-conduct/blob/main/CODE_OF_CONDUCT.md)
to keep our community approachable and respectable.

## Getting Started

### Prerequisites

Ensure the following tools are installed on your system:

- **R** (version >= 4.0.0)
- **RStudio** (optional, but recommended for development)
- **Docker** (if you want to use the Docker setup)
- **Git** (for version control)

### Step 1: Clone the Repository

To start using the package, clone the repository and navigate into the project
directory:

```bash
git clone https://github.com/uw-ssec/biodiversity-horizons.git
cd biodiversity-horizons
```

### Step 2: Install Dependencies

The package requires several dependencies to function. Use the following
commands in your **R console** or **RStudio** to install them:

1. Install devtools if you don't already have it:

```r
install.packages("devtools", dependencies=TRUE)
```

2. Install all dependencies from the DESCRIPTION file:

```r
devtools::install_deps()
```

## Using the Package Locally

The primary script for running the project is located at `scripts/main.R`.
Follow these steps to use it.

### Step 1: Execute the Script Locally

Run the script using the Rscript command in your terminal. Here are examples of
how to use it:

```bash
Rscript scripts/main.R   # will show the sub-commands supported
Rscript scripts/main.R exposure --help # help for the exposure workflow
```

Ensure that your terminal is at the correct directory level.

#### Running exposure calculation workflow:

- Identify your directories:
  - A data folder with the shp_config.yml (for shapefile-derived species data)
    or bien_config.yml (for BIEN species data) and relevant .rds files (either
    your own or from the cloned data-raw/)
  - An outputs directory for script results
  - You can update arguments by updating the shp_config.yml or bien_config.yml.
  - If you face error running the below command - try updating the "workers" to
    1 in the corresponding `yml` file and rerun below command.

##### For SHP:

```bash
Rscript scripts/main.R exposure -i data-raw/shp_config.yml
```

##### For BIEN:

```bash
Rscript scripts/main.R exposure -i data-raw/bien_config.yml
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
  Rscript scripts/main.R shp2rds -i "./data-raw/tier_1/data/species_ranges/subset_amphibians.shp" -o "./outputs/species_test_op.rds"
  ```

- .tif to .rds

  ```
  Rscript scripts/main.R tif2rds -i "./data-raw/tier_1/data/climate/historical.tif" -o "./outputs/historical_data_op.rds"
  ```

  or (if range is an argument)

  ```
  Rscript scripts/main.R tif2rds -i "./data-raw/tier_1/data/climate/ssp585.tif" -o "./outputs/future_data_op.rds" -y "2015:2100"
  ```

- BIEN Climate .tif to .rds

```
Rscript scripts/main.R bienclimate2rds \
  -i ./data-raw/tier_1/data/climate/ssp585.tif \
  -o ./data-raw/test_future.rds \
  -y "2015:2100"
```

- BIEN Species Ranges Conversion

```
Rscript scripts/main.R convert_bienranges \
  -m ~/Desktop/home/bsc23001/projects/bien_ranges/data/oct18_10k/manifest/manifest.parquet \ #replace with your local path
  -r ~/Desktop/home/bsc23001/projects/bien_ranges/data/oct18_10k/tifs \ #replace with your local path
  -g ./data-raw/global_grid.tif \
  -o ./data-raw/bien_ranges/processed \
  -a any \
  -p FALSE \
  -w 4
```

or Subset of species

```
Rscript scripts/main.R convert_bienranges \
  -m ~/Desktop/home/bsc23001/projects/bien_ranges/data/oct18_10k/manifest/manifest.parquet \ #replace with your local path
  -r ~/Desktop/home/bsc23001/projects/bien_ranges/data/oct18_10k/tifs \ #replace with your local path
  -g ./data-raw/global_grid.tif \
  -o ./data-raw/bien_ranges/processed \
  -a any \
  -p FALSE \
  -w 4 \
  -s "Aa mathewsii"
```

### Step 2: Output Files

The script processes the data and saves the output files in the `outputs/`
directory. The primary result file is `exposure_result.rds`.

## Using the Package with Docker

If you prefer a containerized setup, you can use Docker to run the project.

### Step 1: Build the Docker Image

Use the provided `Dockerfile` to build the image and update the CONTAINER
variable with built image name in run_container.sh:

```bash
docker build -t biodiversityhorizons .
```

### Step 2a: Run the commands on the docker container using run_container.sh

#### Running exposure workflow:

- Identify your directories:
  - A data folder with the shp_config.yml (for shapefile-derived species data)
    or bien_config.yml (for BIEN species data) and relevant .rds files (either
    your own or from the cloned data-raw/)
  - An outputs directory for script results
  - You can update arguments by updating the config.yml.

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

## Pull Requests

We welcome contributions! Please follow these guidelines when submitting a Pull
Request:

- It may be helpful to review
  [this tutorial](https://www.dataschool.io/how-to-contribute-on-github/) on how
  to contribute to open source projects. A typical task workflow is:

  - [Fork](https://docs.github.com/en/get-started/quickstart/fork-a-repo) the
    code repository specified in the task and
    [clone](https://docs.github.com/en/repositories/creating-and-managing-repositories/cloning-a-repository)
    it locally.
  - Review the repo's README.md and CONTRIBUTING.md files to understand what is
    required to run and modify this code.
  - Create a branch in your local repo to implement the task.
  - Commit your changes to the branch and push it to the remote repo.
  - Create a pull request, adding the task owner as the reviewer.

- Please follow the
  [Conventional Commits](https://github.com/uw-ssec/rse-guidelines/blob/main/conventional-commits.md)
  naming for pull request titles.

Your contributions make this project better—thank you for your support! 🚀

### Configuring Precommit

PRs will fail style and formatting checks as configured by [precommit](), but
you can set up your local repository such that precommit runs every time you
commit. This way, you can fix any errors before you send out pull requests!!

To do this, install [Pixi](https://pixi.sh/latest/) using either the
[instructions on their website](https://pixi.sh/latest/#installation), or the
commands below:

**MacOS/Linux:**

```
curl -fsSL https://pixi.sh/install.sh | bash
```

**Windows:** [Check the website](https://pixi.sh/latest/#installation)

#### Configure Precommit to run on every commit

Then, once Pixi is installed, run the following command to set up precommit
checks on every commit

```
pixi run precommit-install
```

#### Manually run precommit on non-committed files

```
pixi run precommit
```

#### Manually run precommit on all files

```
pixi run precommit-all
```
