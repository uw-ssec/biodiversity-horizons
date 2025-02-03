FROM rocker/r-ver:4.2.0

RUN apt-get update && apt-get install -y \
    build-essential \
    libgit2-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    zlib1g-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    libudunits2-dev \
    && rm -rf /var/lib/apt/lists/*

RUN Rscript -e "install.packages('terra', repos='https://cloud.r-project.org')"
RUN Rscript -e "install.packages('remotes', repos='https://cloud.r-project.org')"
RUN Rscript -e "install.packages('devtools', repos='https://cloud.r-project.org', dependencies=TRUE)"

WORKDIR /home/biodiversity-horizons

COPY DESCRIPTION .
COPY NAMESPACE .

# by braking this up into two steps, we can cache the installation of dependencies
# and the image builds much faster when changing code
RUN Rscript -e "remotes::install_local('.', dependencies=TRUE)" # Install dependencies
COPY R ./R
RUN Rscript -e "remotes::install_local('.', dependencies=TRUE)" # install package code

COPY scripts ./scripts

# Run the script with "data-raw/" as path since that is where, run_container.sh will mount the data
# We'll also use "multisession", and (availableCores()-1) workers as default
# The user can override by passing in arguments at runtime, e.g.: "multisession" 4
ENTRYPOINT ["Rscript", "scripts/VISS_Sample_Data.R", "data-raw/"]
