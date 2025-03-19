library(tidyverse)
library(furrr)
library(terra)
library(exactextractr)
library(pbapply)
library(sf)
library(parallel)
library(logger)
library(future)
library(glue)

# Initialize logger
log_threshold(INFO)
log_info("Starting BIEN exposure workflow")

bien_exposure_workflow <- function(
  historical_climate_filepath,
  future_climate_filepath,
  bien_species_filepath,
  plan_type,
  workers,
  bien_exposure_result_file
) {
  # If number of workers is not provided, use available cores minus one.
  if (is.null(workers)) {
    workers <- availableCores() - 1
    log_info("Number of workers not provided. Using {workers} workers.")
  }

  # --- 1. Load Climate Data ---
  log_info("Loading historical and future climate data...")
  historical_climate_df <- readRDS(historical_climate_filepath)
  future_climate_df     <- readRDS(future_climate_filepath)
  log_info("Historical climate Data has {nrow(historical_climate_df)} rows.")
  log_info("Future climate Data has {nrow(future_climate_df)} rows.")
  climate_grid <- rast("data-raw/global_grid.tif")
  # --- 2. Load BIEN Species Data (Processed) ---
  log_info("Loading BIEN species data from {bien_species_filepath} ...")
  bien_data <- readRDS(bien_species_filepath)
  log_info("BIEN species data loaded with {nrow(bien_data)} presence points.")

  species_list <- list(bien_data)
  names(species_list) <- "Aa mathewsii"  # Use the function input species_name

  bien_world_ids <- unique(bien_data$world_id)
  historical_world_ids <- unique(historical_climate_df$world_id)

# Find missing world_id values in historical data
  missing_from_historical <- setdiff(bien_world_ids, historical_world_ids)
  print("BIEN world_id missing in historical_climate_df:")
  print(missing_from_historical)

# Find missing world_id values in climate grid
  climate_world_ids <- unique(as.vector(climate_grid))
  missing_from_climate <- setdiff(bien_world_ids, climate_world_ids)
  print("BIEN world_id missing in climate_grid:")
  print(missing_from_climate)


  # --- 3. Load Package Functions ---
  log_info("Loading package functions...")
  devtools::load_all()  # Assumes your helper functions are in your package
  log_info("Package functions loaded successfully.")

  log_info("BIEN Range Data has {length(species_list)} species.")

  # --- 4. Compute Thermal Limits ---
  log_info("Computing thermal limits for BIEN species using {workers} workers and a '{plan_type}' plan...")
  plan(plan_type, workers = workers)

  Here we use get_niche_limits on each species element in the list.
  niche_limits <- future_map_dfr(
    species_list,
    ~ get_niche_limits(.x, historical_climate_df),
    .id = "species",
    .progress = TRUE
  )

  log_info("Thermal limit computation complete.")
  print(bien_niche_limits)

  # --- 5. Calculate Exposure ---
  log_info("Calculating exposure for BIEN species...")
  exposure_list <- future_map(
    seq_along(species_list),
    # # ~ exposure(.x, species_list, future_climate_df, niche_limits),
    # tmp <- exposure(.x, species_list, future_climate_df, niche_limits)
    # log_info("Exposure result for species {.x}: {nrow(tmp)} rows")
    # .progress = TRUE
    function(i) {
    res <- exposure(i, species_list, future_climate_df, niche_limits)
    if (nrow(res) == 0) {
      log_warn("Exposure result for species index {i} is empty; assigning NA.")
      return(data.frame())  # or return a data frame with NA values if appropriate
    } else {
      return(res)
    }
  },
  )
  names(exposure_list) <- names(species_list)
  log_info("Exposure calculation complete.")

  # --- 6. Calculate Exposure Times ---
  log_info("Calculating exposure times.")
  exposure_df <- exposure_list %>%
    bind_rows() %>%
    mutate(sum = rowSums(select(., starts_with("2")))) %>%
    filter(sum < 82) %>%  # Select only cells with < 82 suitable years
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

  log_info("Final BIEN exposure data frame contains {nrow(res_final)} rows.")
  print(res_final)

  # --- 7. Save Processed Exposure Results ---
  output_dir <- "outputs"
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  saveRDS(
    res_final,
    file.path(output_dir, bien_exposure_result_file)
  )
  log_info("Saved BIEN exposure results to {file.path(output_dir, bien_exposure_result_file)}")

  # Reset parallel processing plan
  future::plan("sequential")
  log_info("BIEN Exposure Workflow completed successfully.")

  return(res_final)
}

# Example usage:
bien_exposure_results <- bien_exposure_workflow(
  historical_climate_filepath = "data-raw/historical_climate_bien_data.rds",
  future_climate_filepath     = "data-raw/future_climate_data_new.rds",
  bien_species_filepath       = "~/Desktop/home/bsc23001/projects/bien_ranges/processed/Aa mathewsii_processed.rds",
  plan_type                   = "multisession",
  workers                     = 3,
  bien_exposure_result_file   = "Aa_mathewsii_bien_exposure_results.rds"
)
