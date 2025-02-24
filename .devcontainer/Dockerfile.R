# Base Image
FROM rocker/r-ver:4.3.0

# Enable source repositories and install dependencies
RUN sed -i 's/^#\s*\(deb-src .* main\)$/\1/' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    build-essential \
    git \
    curl \
    make \
    libcurl4-gnutls-dev && \
    rm -rf /var/lib/apt/lists/*

# Install R package dependencies
RUN R -e "install.packages(c('devtools', 'roxygen2', 'testthat'))"

# Set working directory to /app
WORKDIR /app

# Copy the R package or the current directory into the container
COPY . /app

# Install the R package
RUN R -e "devtools::install('.')"

# Default command
CMD ["R"]
