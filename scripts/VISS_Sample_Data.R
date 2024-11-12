library(tidyverse)
library(furrr)
library(terra)
library(pbapply)
library(parallel)

# Source functions from the /R folder
source("R/prepare_range.R")
source("R/extract_climate_data.R")
source("R/get_niche_limits.R")
source("R/exposure.R")
source("R/exposure_times.R")

# Set the folder containing the files as the working directory
path <- "data-raw/"

# Load input data
historical_climate <- readRDS(paste0(path, "historical_climaate_data.rds"))
future_climate <- readRDS(paste0(path, "future_climaate_data.rds"))
grid <- readRDS(paste0(path, "grid.rds"))
primates_shp <- readRDS(paste0(path, "primates_shapefiles.rds"))

# Prepare range data
primates_range_data <- prepare_range(primates_shp, grid)

# Extract climate data for historical and future datasets
historical_climate_df <- extract_climate_data(historical_climate, grid)
future_climate_df <- extract_climate_data(future_climate, grid)

# Compute thermal niche limits for each species
plan("multisession", workers = availableCores() - 1)
niche_limits <- future_map_dfr(
  primates_range_data,
  ~ get_niche_limits(.x, historical_climate_df),
  .id = "species",
  .progress = TRUE
)

# Calculate exposure for each species and grid cell
exposure_list <- future_map(
  1:length(primates_range_data),
  ~ exposure(.x, primates_range_data, future_climate_df, niche_limits),
  .progress = TRUE
)
names(exposure_list) <- names(primates_range_data)

# Combine exposure data into a single data frame
exposure_df <- bind_rows(exposure_list) %>%
  mutate(sum = rowSums(select(., starts_with("2")))) %>%
  filter(sum < 82) %>%  # Exclude species with no exposure
  select(-sum)

# Calculate exposure times (using parallel processing)
cl <- makeCluster(availableCores() - 1)
clusterEvalQ(cl, library(dplyr))
clusterExport(cl, "exposure_times")

res_final <- pbapply(
  X = exposure_df,
  MARGIN = 1,
  FUN = function(x) exposure_times(data = x, original.state = 1, consecutive.elements = 5),
  cl = cl
)

stopCluster(cl)  # Stop the parallel cluster

# Combine results and clean up
res_final <- bind_rows(res_final) %>%
  na.omit()

res_final
