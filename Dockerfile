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
    squashfs-tools \
    && rm -rf /var/lib/apt/lists/*

RUN Rscript -e "install.packages('terra', repos='https://cloud.r-project.org')"
RUN Rscript -e "install.packages('remotes', repos='https://cloud.r-project.org')"
RUN Rscript -e "install.packages('devtools', repos='https://cloud.r-project.org', dependencies=TRUE)"

WORKDIR /home/biodiversity-horizons

COPY DESCRIPTION .
COPY NAMESPACE .

# by breaking this up into two steps, we can cache the installation of dependencies
# and the image builds much faster when changing code
RUN Rscript -e "remotes::install_local('.', dependencies=TRUE)" # Install dependencies
COPY R ./R
COPY utility ./utility
RUN Rscript -e "remotes::install_local('.', dependencies=TRUE)" # install package code

COPY scripts ./scripts

# Run the main script, which can take arguments to determine the workflow to run
ENTRYPOINT ["Rscript", "scripts/main.R"]
