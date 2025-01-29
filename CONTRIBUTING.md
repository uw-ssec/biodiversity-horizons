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
install.packages("devtools")
```

2. Install all dependencies from the DESCRIPTION file:

```r
devtools::install_deps()
```

## Using the Package Locally

The primary script for running the project is located at
`scripts/VISS_Sample_Data.R`. Follow these steps to use it.

### Step 1: Execute the Script Locally

Run the script using the Rscript command in your terminal. Here are examples of
how to use it:

```bash
Rscript scripts/VISS_Sample_Data.R
```

This will use:

- **path** ="data-raw/"
- **plan_type** ="multisession"
- **workers** =availableCores() - 1

#### Pass Custom Arguments: Specify custom arguments (path, plan, workers):

```bash
Rscript scripts/VISS_Sample_Data.R /path/to/data multicore 4
```

### Step 2: Output Files

The script processes the data and saves the output files in the `outputs/`
directory. The primary result file is `res_final.rds`.

## Using the Package with Docker

If you prefer a containerized setup, you can use Docker to run the project.

### Step 1: Build the Docker Image

Use the provided `Dockerfile` to build the image:

```bash
docker build -t biodiversity-horizons .
```

### Step 2: Run the Docker Container

#### Run with Defaults

Run the container and mount your local data directory to the container’s
`data-raw/` directory:

```bash
docker run --rm \
  -v /path/to/data-raw/:/home/biodiversity-horizons/data-raw/ \
  biodiversity-horizons
```

This will:

- Mount your local data-raw/ directory to
  `/home/biodiversity-horizons/data-raw/` inside the container.
- Execute the script using the default arguments.

#### Pass Custom Arguments

You can pass custom arguments to the script by appending them to the docker run
command. For example:

```bash
docker run --rm \
  -v /path/to/data-raw/:/home/biodiversity-horizons/data-raw/ \
  -v /path/to/outputs/:/home/biodiversity-horizons/outputs/ \
  biodiversity-horizons \
  Rscript scripts/VISS_Sample_Data.R /home/biodiversity-horizons/data-raw multicore 4
```

This command:

- Mounts local `data-raw/` directory to `/home/biodiversity-horizons/data-raw/`
  inside the container.
- Mounts local `outputs/` directory to `/home/biodiversity-horizons/outputs/`
  inside the container.
- Passes custom arguments to the script:
  - `/home/biodiversity-horizons/data-raw`: Path to the data directory.
  - `multicore`: Parallelization plan.
  - `4`: Number of workers.

### Note:

If your current working directory already contains the `data-raw/` folder, you
can simplify the command by replacing `/path/to/data-raw/` with
`$(pwd)/data-raw/`:

Example:

```bash
docker run --rm \
  -v $(pwd)/data-raw/:/home/biodiversity-horizons/data-raw/ \
  biodiversity-horizons
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
