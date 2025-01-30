# Load necessary libraries
library(tidyverse)
library(furrr)
library(terra)
library(exactextractr)
library(pbapply)
library(sf)
library(parallel)
library(logger)
library(future)

# Initialize logger
log_threshold(INFO)
log_info("Starting VISS Sample Data script.")

# Parse command-line arguments
args <- commandArgs(trailingOnly = TRUE)

# Set Data path
if (length(args) >= 1) {
  path <- args[1]
} else {
  # Default to data-raw/ if not provided
  if (interactive()) {
    path <- "data-raw/"
    message("No data path argument provided. Using default: ", path)
  } else {
    stop("No data folder argument provided.\nUsage: Rscript VISS_Sample_Data.R /path/to/data [plan_type] [workers]")
  }
}
log_info("Data path set to: {path}")

# Plan type
if (length(args) >= 2) {
  plan_type <- args[2]
} else {
  plan_type <- "multisession"
}

# Number of workers
if (length(args) >= 3) {
  workers <- as.numeric(args[3])
} else {
  workers <- availableCores() - 1
}

# Load data
log_info("Loading data...")
historical_climate <- readRDS(file.path(path, "historical_climaate_data.rds"))
future_climate     <- readRDS(file.path(path, "future_climaate_data.rds"))
grid               <- readRDS(file.path(path, "grid.rds"))
primates_shp       <- readRDS(file.path(path, "primates_shapefiles.rds"))
log_info("Data loaded successfully.")

# Log data details
log_info("Historical climate data has {nrow(historical_climate)} rows.")
log_info("Future climate data has {nrow(future_climate)} rows.")
log_info("Grid data contains {nrow(grid)} rows.")
log_info("Primates shapefile contains {nrow(primates_shp)} rows.")

# Load all functions from the package
log_info("Loading package functions...")
devtools::load_all()
log_info("Package functions loaded successfully.")

# 1. Transform the distribution polygons to match the grid
log_info("Transforming distribution polygons to match the grid.")
primates_range_data <- prepare_range(primates_shp, grid)
log_info("Processed {length(primates_range_data)} species.")

# 2. Extract climate data using the grid
log_info("Extracting historical climate data...")
historical_climate_df <- extract_climate_data(historical_climate, grid)
log_info(
  "Historical climate extraction done: {nrow(historical_climate_df)} rows."
)

log_info("Extracting future climate data...")
future_climate_df <- extract_climate_data(future_climate, grid)
log_info("Future climate extraction done: {nrow(future_climate_df)} rows.")

# Rename columns
log_info("Renaming columns for climate data.")
colnames(historical_climate_df) <- c("world_id", 1850:2014)
colnames(future_climate_df) <- c("world_id", 2015:2100)
log_info("Column renaming complete.")

# 3. Compute the thermal limits for each species
log_info("Computing thermal limits for each species using {workers} workers and a '{plan_type}' parallelization plan.")
plan(plan_type, workers = workers)

niche_limits <- future_map_dfr(
  primates_range_data,
  ~ get_niche_limits(.x, historical_climate_df),
  .id = "species",
  .progress = TRUE
)
log_info("Thermal limit computation complete.")

# 4. Calculate exposure
log_info("Calculating exposure for each species.")
exposure_list <- future_map(
  seq_along(primates_range_data),
  ~ exposure(.x, primates_range_data, future_climate_df, niche_limits),
  .progress = TRUE
)
names(exposure_list) <- names(primates_range_data)
log_info("Exposure calculation complete.")

# 5. Calculate exposure times
log_info("Calculating exposure times.")
exposure_df <- exposure_list %>%
  bind_rows() %>%
  mutate(sum = rowSums(select(., starts_with("2")))) %>%
  filter(sum < 82) %>% # Select only cells with < 82 suitable years
  select(-sum)

cl <- future::makeClusterPSOCK(workers, port = 12000, outfile = NULL, verbose = TRUE)
clusterEvalQ(cl, library(dplyr))
clusterExport(cl, "exposure_times")

res_final <- pbapply(
  X = exposure_df,
  MARGIN = 1,
  FUN = function(x) {
    exposure_times(
      data = x,
      original_state = 1,
      consecutive_elements = 5
    )
  },
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

# 6. Save the output to "outputs/" directory
output_dir <- "outputs"
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

saveRDS(
  res_final,
  file.path(output_dir, "res_final.rds")
)
log_info("Saved results to {file.path(output_dir, 'res_final.rds')}")

# Reset parallel processing plan
future::plan("sequential")
log_info("VISS Sample Data script completed successfully.")
