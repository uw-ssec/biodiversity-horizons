# Base Image
FROM rocker/r-ver:4.3.0

# Copy package files
COPY . /app
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libgit2-dev \
    pandoc


# Set CRAN mirror to a fast and reliable one
RUN R -e "options(repos = c(CRAN = 'https://packagemanager.posit.co/cran/__linux__/latest'))"

# Install R package dependencies
RUN R -e "install.packages(c('devtools', 'roxygen2', 'testthat'))"

# Install the R package
RUN R -e "devtools::install('.')"

# Default command
CMD ["R"]
