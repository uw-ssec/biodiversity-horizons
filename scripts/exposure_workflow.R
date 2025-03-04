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
log_info("Starting exposure workflow")
exposure_time_workflow <- function(
  historical_climate_filepath,
  future_climate_filepath,
  species_filepath,
  plan_type,
  workers,
  exposure_result_file
) {
  if (is.null(workers)) {
    workers <- availableCores() - 1
    log_info("Number of workers not provided. Using {workers} workers.")
  }
# Load data
log_info("Loading data...")
historical_climate_df <- readRDS(historical_climate_filepath)
future_climate_df     <- readRDS(future_climate_filepath)
primates_range_data   <- readRDS(species_filepath)
log_info("Data loaded successfully.")

# Load all functions from the package
log_info("Loading package functions...")
devtools::load_all()
log_info("Package functions loaded successfully.")

log_info("Primate Range Data has {length(primates_range_data)} species.")
log_info("Historical climate Data has {nrow(historical_climate_df)} rows.")
log_info("Future climate Data has {nrow(future_climate_df)} rows.")


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
  file.path(output_dir, exposure_result_file)
)
log_info("Saved results to {file.path(output_dir, exposure_result_file)}")

# Reset parallel processing plan
future::plan("sequential")
log_info("Exposure Workflow completed successfully.")
}
