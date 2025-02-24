# Base Image
FROM r-base:4.3.0

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    build-essential \
    git \
    curl \
    make \
    libgnutls28-dev && \
    rm -rf /var/lib/apt/lists/*


# Set working directory to /app
WORKDIR /app

# Copy the R package or the current directory into the container
COPY . /app

RUN R -e "install.packages(c('devtools', 'roxygen2', 'testthat')); \
          remotes::install_deps(dependencies=TRUE); \
          devtools::install('.', dependencies=TRUE, keep_source=TRUE)"

# Default command
CMD ["R"]
