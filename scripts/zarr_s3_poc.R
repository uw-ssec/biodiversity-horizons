# This script explores three different ways to read Zarr files in R from an S3 bucket.

# Option 1: Using stars package
# from https://www.r-bloggers.com/2022/09/reading-zarr-files-with-r-package-stars/
install.packages("sf")
install.packages("stars")
library(stars)
# dsn <- 'ZARR:"/vsicurl/https://ncsa.osn.xsede.org/Pangeo/pangeo-forge/gpcp-feedstock/gpcp.zarr"'
bounds <- c(longitude = "lon_bounds", latitude = "lat_bounds")
dsn <- 'ZARR:"/vsis3/cmip6-pds/CMIP3/CCCMA/cccma_cgcm3_1/1pctCO2/r1i1p1f1/Amon/pr/lat/"'
r <- read_mdim(dsn, bounds = bounds)
# results in:
# Error: file not found
# In addition: Warning messages:
# 1: In CPL_read_mdim(file, array_name, options, o

# From online chatter this appears to be a Mac specific issue and related to GDAL being compiled without blosc compression support.


# Option 2: Using reticulate
install.packages("reticulate")
library(reticulate)
# By default a r-reticulate virtualenv is created, others can be created with virtualenv_create()
virtualenv_list()
env <- "r-reticulate"
use_virtualenv(env)
virtualenv_install(env, "zarr")
virtualenv_install(env, "s3fs")

zarr <- import("zarr")
s3fs <- import("s3fs")

# Path to the Zarr dataset directory on S3
url <- "s3://cmip6-pds/CMIP3/CCCMA/cccma_cgcm3_1/1pctCO2/r1i1p1f1/Amon/pr"

# Open the Zarr array stored in the directory
zgrp <- zarr$open(url, mode = "r", storage_options = list(anon = TRUE))

# some interop issues, eg keys here is a python generator, so we need to iterate over it in a loop
keys <- zgrp$array_keys()
n <- ""
while (!is.null(n)) {
    n <- iter_next(keys, completed = NULL)
    print(n)
}

# This works but seems generally slow
z_lat_arr <- zgrp["lat"]
# Read a data slice
data <- z_lat_arr[0:10]
df <- as.data.frame(data)
print(df)

# Option 3: Using Rarr
# https://www.bioconductor.org/packages/release/bioc/vignettes/Rarr/inst/doc/Rarr.html
# See limitations:
#    https://www.bioconductor.org/packages/release/bioc/vignettes/Rarr/inst/doc/Rarr.html#limitations-with-rarr
if (!require("BiocManager", quietly = TRUE)) {
    install.packages("BiocManager")
}
BiocManager::install("Rarr")
library(Rarr)

url <- "https://s3.amazonaws.com/cmip6-pds/CMIP3/CCCMA/cccma_cgcm3_1/1pctCO2/r1i1p1f1/Amon/pr/lat/"
zarr_overview(url)
as.data.frame(read_zarr_array(url, list(1:10)))
