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

COPY . .

RUN Rscript -e "remotes::install_local('.', dependencies=TRUE)"

# The default CMD uses "data-raw/" as the data path (can be overridden at runtime)
CMD ["Rscript", "scripts/VISS_Sample_Data.R", "data-raw/"]
