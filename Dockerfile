FROM ghcr.io/uw-ssec/r-bio-div-base:1.2



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
