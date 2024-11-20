# Load necessary libraries
library(tidyverse)
library(furrr)
library(terra)
library(exactextractr)
library(pbapply)
library(sf)
library(parallel)
library(logger)

# Initialize logger
log_threshold(INFO)
log_info("Starting VISS Sample Data script.")

# Set the folder containing the files as the working directory
path <- "data-raw/"
log_info("Data path set to: {path}")

# Load data
log_info("Loading data...")
historical_climate <- readRDS(paste0(path, "historical_climaate_data.rds"))
future_climate <- readRDS(paste0(path, "future_climaate_data.rds"))
grid <- readRDS(paste0(path, "grid.rds"))
primates_shp <- readRDS(paste0(path, "primates_shapefiles.rds"))
log_info("Data loaded successfully.")

# Log data details
log_info("Historical climate data has {nrow(historical_climate)} rows.")
log_info("Future climate data has {nrow(future_climate)} rows.")
log_info("Grid data contains {nrow(grid)} rows.")
log_info("Primates shapefile contains {nrow(primates_shp)} rows.")

# Source the functions from the /R directory
log_info("Loading functions...")
source("R/prepare_range.R")
source("R/extract_climate_data.R")
source("R/get_niche_limits.R")
source("R/exposure.R")
source("R/exposure_times.R")
log_info("Functions loaded successfully.")

# 1. Transform the distribution polygons to match the grid
log_info("Transforming distribution polygons to match the grid.")
primates_range_data <- prepare_range(primates_shp, grid)
log_info("Transformation complete. Processed {length(primates_range_data)} species.")

# 2. Extract climate data using the grid
log_info("Extracting historical climate data...")
historical_climate_df <- extract_climate_data(historical_climate, grid)
log_info("Historical climate data extraction complete. Dataframe contains {nrow(historical_climate_df)} rows.")

log_info("Extracting future climate data...")
future_climate_df <- extract_climate_data(future_climate, grid)
log_info("Future climate data extraction complete. Dataframe contains {nrow(future_climate_df)} rows.")

# Rename columns
log_info("Renaming columns for climate data.")
colnames(historical_climate_df) <- c("world_id", 1850:2014)
colnames(future_climate_df) <- c("world_id", 2015:2100)
log_info("Column renaming complete.")

# 3. Compute the thermal limits for each species
log_info("Computing thermal limits for each species.")
plan("multisession", workers = availableCores() - 1)
niche_limits <- future_map_dfr(primates_range_data, ~ get_niche_limits(.x, historical_climate_df),
                               .id = "species", .progress = TRUE)
log_info("Thermal limit computation complete.")

# 4. Calculate exposure
log_info("Calculating exposure for each species.")
exposure_list <- future_map(1:length(primates_range_data), ~ exposure(.x, primates_range_data, future_climate_df, niche_limits), .progress = TRUE) # nolint
names(exposure_list) <- names(primates_range_data)
log_info("Exposure calculation complete.")

# 5. Calculate exposure times
log_info("Calculating exposure times.")
exposure_df <- exposure_list %>%
  bind_rows() %>%
  mutate(sum = rowSums(select(., starts_with("2")))) %>%
  filter(sum < 82) %>%  # Select only cells with less than 82 suitable years
  select(-sum)

cl <- makeCluster(availableCores() - 1)
log_info("Parallel cluster created with {availableCores() - 1} workers.")
clusterEvalQ(cl, library(dplyr))
clusterExport(cl, "exposure_times")

res_final <- pbapply(
  X = exposure_df,
  MARGIN = 1,
  FUN = function(x) exposure_times(data = x, original_state = 1, consecutive_elements = 5),
  cl = cl
)

res_final <- res_final %>%
  bind_rows() %>%
  na.omit()

log_info("Exposure time calculation complete.")

stopCluster(cl)
log_info("Cluster stopped.")

# Final data frame with exposure times for each species at each grid cell
log_info("Final data frame contains {nrow(res_final)} rows.")
print(res_final)

# Reset parallel processing plan
future::plan("sequential")
log_info("VISS Sample Data script completed successfully.")
