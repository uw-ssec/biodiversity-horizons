# Load necessary libraries
library(tidyverse)
library(furrr)
library(terra)
library(exactextractr)
library(pbapply)
library(sf)
library(parallel)

# Set the folder containing the files as the working directory
path <- "data-raw/"

# Load data
historical_climate <- readRDS(paste0(path, "historical_climaate_data.rds"))
future_climate <- readRDS(paste0(path, "future_climaate_data.rds"))
grid <- readRDS(paste0(path, "grid.rds"))
primates_shp <- readRDS(paste0(path, "primates_shapefiles.rds"))

devtools::load_all()

# 1. Transform the distribution polygons to match the grid
primates_range_data <- prepare_range(primates_shp, grid)

# 2. Extract climate data using the grid
historical_climate_df <- extract_climate_data(historical_climate, grid)
future_climate_df <- extract_climate_data(future_climate, grid)

# Rename columns
colnames(historical_climate_df) <- c("world_id", 1850:2014)
colnames(future_climate_df) <- c("world_id", 2015:2100)

# 3. Compute the thermal limits for each species
plan("multisession", workers = availableCores() - 1)

niche_limits <- future_map_dfr(
  primates_range_data,
  ~ get_niche_limits(.x, historical_climate_df),
  .id = "species",
  .progress = TRUE
)

# 4. Calculate exposure
plan("multisession", workers = availableCores() - 1)
exposure_list <- future_map(1:length(primates_range_data), ~ exposure(.x, primates_range_data, future_climate_df, niche_limits), .progress = TRUE) #nolint
names(exposure_list) <- names(primates_range_data)

# 5. Calculate exposure times
exposure_df <- exposure_list %>%
  bind_rows() %>%
  mutate(sum = rowSums(select(., starts_with("2")))) %>%
  filter(sum < 82) %>%  # Select only cells with less than 82 suitable years
  select(-sum)

cl <- makeCluster(availableCores() - 1)
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
  }
)

res_final <- res_final %>%
  bind_rows() %>%
  na.omit()

stopCluster(cl)

# Final data frame with exposure times for each species at each grid cell
print(res_final)

future::plan("sequential")
