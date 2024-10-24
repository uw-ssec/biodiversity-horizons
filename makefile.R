#### Template of a master script for the project ####

## Using an advanced tool like {drake} or {targets} is recommended,
## but this can work as a simple alternative.

### if you have written specific functions in R/, load the package:
# library("myproject") # nolint

### Source data cleaning scripts
# source("data-raw/datacleaning.R") # nolint
# rmarkdown::render("data-raw/datacleaning.Rmd") # nolint

### Render manuscript
# rmarkdown::render("manuscript/ms_project.Rmd") # nolint

## Check your code ##
# goodpractice::gp() # nolint

#### Control package dependencies ####
# sessionInfo() # nolint
# renv::init() # nolint
# renv::snapshot() # nolint

## Make a website for your project?
## see https://pkgdown.r-lib.org/
# usethis::use_pkgdown() # nolint
# pkgdown::build_site() # nolint
