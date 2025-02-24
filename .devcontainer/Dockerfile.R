# Base Image
FROM rocker/r-ver:4.3.0

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    build-essential \
    git \
    curl && \
    rm -rf /var/lib/apt/lists/*

# Set working directory to /app
WORKDIR /app

# Copy the R package or the current directory into the container
COPY . /app

# Install R package dependencies
RUN R -e "install.packages(c('devtools', 'roxygen2', 'testthat'))"

# Install the R package
RUN R -e "devtools::install('.', dependencies=TRUE, keep_source=TRUE)"

# Default command
CMD ["R"]
