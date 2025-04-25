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
library(glue)
library(devtools)
library(arrow)
library(pbdMPI)

# Initialize logger
log_threshold(INFO)
log_info("Starting unified exposure workflow")

BIEN_PARQUET_SUFFIX <- "_processed\\.parquet"

exposure_workflow <- function(
    historical_climate_filepath,
    future_climate_filepath,
    species_filepath,
    species_type,
    plan_type,
    workers,
    exposure_result_file) {
  # TODO: REMOVE THIS
  # workers <- NULL
  # species_type <- "shp"
  # plan_type <- "multisession"
  # historical_climate_filepath <- "/Users/carlosg/repos/biodiversity-horizons/data-raw/historical_climate_data_new.rds"
  # future_climate_filepath <- "/Users/carlosg/repos/biodiversity-horizons/data-raw/future_climate_data_new.rds"
  # species_filepath <- "/Users/carlosg/repos/biodiversity-horizons/data-raw/species_new.rds"
  if (is.null(workers)) {
    workers <- availableCores() - 1
    log_info("Number of workers not provided. Using {workers} workers.")
  }

  pbdMPI::init()
  mpi_rank <- comm.rank()
  mpi_size <- comm.size()
  log_info("MPI size: {mpi_size}, MPI rank: {mpi_rank}")


  # Load climate data
  log_info("Loading historical and future climate data...")
  historical_climate_df <- readRDS(historical_climate_filepath)
  future_climate_df <- readRDS(future_climate_filepath)
  log_info("Historical climate data: {nrow(historical_climate_df)} rows")
  log_info("Future climate data: {nrow(future_climate_df)} rows")

  # Load species data based on species_type
  if (species_type == "shp") {
    log_info("Loading Shapefile-derived species data from {species_filepath}")
    species_list <- readRDS(species_filepath)
    log_info("Loaded {length(species_list)} species.")
    # Split the species list into chunks based on the number of ranks
    species_chunks <- split(species_list, seq_along(species_list) %% mpi_size)

    # Assign the chunk corresponding to the current rank
    species_list <- species_chunks[[mpi_rank + 1]]
  } else if (species_type == "bien") {
    log_info("Loading BIEN species data from directory: {species_filepath}")
    species_files <- list.files(
      species_filepath,
      pattern = BIEN_PARQUET_SUFFIX,
      full.names = TRUE
    )
    log_info("Found {length(species_files)} BIEN species files.")
    species_file_chunks <- split(species_files, seq_along(species_files) %% mpi_size)

    # Assign the chunk corresponding to the current rank
    species_files <- species_file_chunks[[mpi_rank + 1]]

    log_info("Rank {mpi_rank} processing {length(species_files)} BIEN species files.")
    species_list <- list()
    # TODO: For BIEN it may be better to split the files by mpi rank
    for (file in species_files) {
      species_name <- gsub(BIEN_PARQUET_SUFFIX, "", basename(file))
      bien_data <- arrow::read_parquet(file)

      if (nrow(bien_data) == 0) {
        log_warn("No data found for {species_name}; skipping.")
        next
      }

      species_list[[species_name]] <- bien_data
    }
  } else {
    stop("Unsupported species_type: must be 'shp' or 'bien'")
  }


  log_info("Rank {mpi_rank} processing {length(species_list)} species.")

  # Load functions
  log_info("Loading package functions...")
  devtools::load_all()
  log_info("Package functions loaded successfully.")

  # Compute niche limits
  log_info("Computing thermal limits using {workers} workers and '{plan_type}' plan...")
  plan(plan_type, workers = workers)

  if (species_type == "bien") {
    niche_limits <- future_map_dfr(
      species_list,
      ~ get_niche_limits(.x$world_id, historical_climate_df),
      .id = "species",
      .progress = TRUE
    )
  } else {
    niche_limits <- future_map_dfr(
      species_list,
      ~ get_niche_limits(.x, historical_climate_df),
      .id = "species",
      .progress = TRUE
    )
  }
  log_info("Thermal limit computation complete. {nrow(niche_limits)} niche_limits.")

  # Calculate exposure
  log_info("Calculating exposure...")
  exposure_list <- future_map(
    seq_along(species_list),
    ~ exposure(.x, species_list, future_climate_df, niche_limits),
    .progress = TRUE
  )
  names(exposure_list) <- names(species_list)
  log_info("Exposure calculation complete. {length(exposure_list)} species processed.")

  # Calculate exposure times
  log_info("Calculating exposure times...")
  exposure_df <- exposure_list %>%
    bind_rows() %>%
    mutate(sum = rowSums(select(., starts_with("2")))) %>%
    filter(sum < 82) %>% # Select only cells with < 82 suitable years. TODO: Make this a parameter.
    select(-sum)
  log_info("{nrow(exposure_df)} rows in exposure_df.")

  cl <- future::makeClusterPSOCK(workers, port = 12000 + mpi_rank, outfile = NULL, verbose = FALSE)
  clusterEvalQ(cl, suppressPackageStartupMessages(library(dplyr)))
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
  ) %>%
    bind_rows() %>%
    na.omit()

  stopCluster(cl)
  log_info("Exposure time calculation complete.")

  combined_results <- list(res_final) # Include rank 0's results
  if (mpi_rank != 0) {
    # Other ranks: Send results to rank 0
    log_info("Rank {mpi_rank} sending results to rank 0")
    pbdMPI::send(res_final, rank.dest = 0, tag = mpi_rank)
  } else {
    # Rank 0: Receive results from all other ranks
    log_info("Rank 0 has {nrow(res_final)} results")
    for (rank in seq_len(mpi_size - 1)) {
      log_info("Rank 0 waiting to receive results from rank {rank}")
      received_result <- pbdMPI::recv(rank.source = rank, tag = rank)
      combined_results[[rank + 1]] <- received_result
      log_info("Rank 0 received {nrow(received_result)} results from rank {rank}")
    }
    # Combine all results into a single data frame
    final_combined_result <- bind_rows(combined_results) %>% na.omit()

    # Save the combined result
    output_dir <- "outputs"
    if (!dir.exists(output_dir)) {
      dir.create(output_dir, recursive = TRUE)
    }

    saveRDS(
      final_combined_result,
      file.path(output_dir, exposure_result_file)
    )

    log_info("Saved {nrow(final_combined_result)} results to {file.path(output_dir, exposure_result_file)}")
  }

  pbdMPI::finalize() # Finalize MPI

  future::plan("sequential")
  log_info("Exposure Workflow completed successfully.")

  return(res_final)
}
