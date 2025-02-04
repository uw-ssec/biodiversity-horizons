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
docker pull ghcr.io/uw-ssec/biodiversity-horizons:latest
```

If this succeeds, the image is downloaded locally.

#### (Optional) GitHub Container Registry Authentication:

If pulling fails with a `“denied”` error, generate a Personal Access Token
(classic) with `read:packages` scope and run:

```
echo YOUR_TOKEN | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
```

### 3. Obtain or Prepare your `data-raw/` folder

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

### 4. Run the Container Using run_container.sh

We recommend using the script `run_container.sh` for simplicity. It mounts your
data and output folders to the container and executes the main R script.

- Ensure the script is executable:

  ```
  chmod +x run_container.sh
  ```

- Identify your directories:

  - A data folder with .rds files (either your own or the cloned data-raw/)
  - An outputs directory for script results

- Run the container:

  ```
  ./run_container.sh /absolute/path/to/data-raw /absolute/path/to/outputs
  ```

  - Replace `/absolute/path/to/data-raw` or `/absolute/path/to/data-outputs`
    with the paths on your machine.

  - This mounts your local data-raw folder into the container and runs the
    default script.

### 5. Passing Additional Arguments

You can pass custom arguments (e.g., parallel plan, workers), example:

```
./run_container.sh /absolute/path/to/data-raw /absolute/path/to/outputs multisession 4
```

These extra arguments are forwarded to the R script inside the container.

### Running and Developing

Instructions to run and contribute to the portal can be found in
[**Contributing Guidelines**](./Contributing.md)

Please follow our [**UW-SSEC Code of Conduct**](./CODE_OF_CONDUCT.md) in all
interactions. For questions or issues, open an
[**Issue**](https://github.com/uw-ssec/biodiversity-horizons/issues) or contact
the maintainers.
