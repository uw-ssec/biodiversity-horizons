library(terra)    # For raster operations
library(logger)   # For logging
library(arrow)    # For reading Parquet files
library(dplyr)    # For data manipulation
library(purrr)    # For functional programming
library(glue)     # For string formatting
library(sf)       # For spatial operations
library(stars)    # For raster operations

#-------------------------------------------------
# Function to convert future BIEN ranges to binary presence/absence.
binRange <- function(rng, full_domain = FALSE) {
  if (nlyr(rng) < 2) {
    log_warn("Raster has less than 2 layers; using first layer.")
    rng1 <- rng[[1]]
  } else {
    rng1 <- rng[[2]]
  }
  if (full_domain) {
    rng1 <- abs(rng1)
  }
  rng1 <- ifel(rng1 >= 3, 1, NA)
  return(rng1)
}

#-------------------------------------------------
# Main function to process BIEN species range data and align with the climate grid.
process_bien_ranges <- function(
  species_name,
  ranges_folder = "~/Desktop/home/bsc23001/projects/bien_ranges/data/oct18_10k/tifs",
  output_folder = "~/Desktop/home/bsc23001/projects/bien_ranges/processed",
  manifest_path = "~/Desktop/home/bsc23001/projects/bien_ranges/data/oct18_10k/manifest/manifest.parquet",
  climate_grid_path = "data-raw/global_grid.tif",
  aggregation_rule = "any"
) {
  log_info("Processing BIEN species: {species_name}")

  if (!dir.exists(output_folder)) {
    dir.create(output_folder, recursive = TRUE)
  }

  # Load manifest and filter for the species
  manifest <- open_dataset(manifest_path)
  species_files <- manifest %>% filter(spp == species_name) %>% collect()
  if (nrow(species_files) == 0) {
    log_error("No BIEN files found for {species_name} in the manifest.")
    return(NULL)
  }
  log_info("Found {nrow(species_files)} BIEN range files for {species_name}")

  # Load the master climate grid
  climate_grid <- rast(climate_grid_path)
  if (!"world_id" %in% names(climate_grid)) {
    log_error("Climate grid does not contain a 'world_id' layer.")
    return(NULL)
  }
  log_info(" Climate Grid: Extent: {ext(climate_grid)}, Resolution: {res(climate_grid)}, CRS: {crs(climate_grid)}, Origin: {origin(climate_grid)}")

  # --- Process PRESENT range ---
  pres_file <- file.path(ranges_folder, species_files$path[grepl("present", species_files$path)])
  if (!file.exists(pres_file)) {
    log_error("No present-day raster found for {species_name}")
    return(NULL)
  }
  log_info("Processing present range for {species_name}")
  pres <- rast(pres_file) - 4 #codespell:ignore pres
  pres <- ifel(pres >= 2, 1, NA) #codespell:ignore pres
  names(pres) <- "present" #codespell:ignore pres
  log_info("Unique values in present raster after binary conversion: {unique(values(pres))}") #codespell:ignore pres

  # --- Process FUTURE ranges ---
  futRngs <- species_files %>%
    filter(scenario != "present") %>%
    rowwise() %>%
    mutate(rast = list({
      fut_rast <- rast(file.path(ranges_folder, path))
      bin_rast <- binRange(fut_rast)
      names(bin_rast) <- glue("rcp{rcp}_{year}")
      bin_rast
    })) %>%
    ungroup()
  future_stack <- rast(futRngs$rast)

  # Combine present and future rasters into a single stack
  final_stack <- trim(c(pres, future_stack)) #codespell:ignore pres

  # --- Reproject to WGS84 ---
  log_info(" Reprojecting BIEN raster to EPSG:4326...")
  final_stack_wgs84 <- project(final_stack, "EPSG:4326", method = "near")
  log_info("Reprojected BIEN Raster: Extent: {ext(final_stack_wgs84)}, Resolution: {res(final_stack_wgs84)}")

  # --- Aggregate to 1° resolution ---
  # Compute the aggregation factor based on the native resolution of the reprojected BIEN raster.
  current_res <- res(final_stack_wgs84)[1]  # assuming square pixels
  agg_factor <- round(1 / current_res)
  log_info("Aggregation factor computed as: {agg_factor}")

  bien_1deg <- aggregate(final_stack_wgs84, fact = c(agg_factor, agg_factor), fun = function(x) {
    if (any(x == 1, na.rm = TRUE)) 1 else NA
  })
  # log_info("🔍 Unique BIEN Raster Values AFTER Aggregation: {unique(values(bien_1deg))}")

  if (all(is.na(values(bien_1deg)))) {
    log_error(" BIEN raster has only NA values after aggregation. Aborting process.")
    return(NULL)
  }

  # --- Resample to match the climate grid exactly ---
  bien_resampled <- resample(bien_1deg, climate_grid, method = "near")
  log_info("🔍 Unique BIEN Raster Values AFTER Resampling: {unique(values(bien_resampled))}")

    # Verify properties of the BIEN raster (before converting to data frame)
  cat("BIEN Raster Properties:\n")
  cat("  Extent:   ", toString(ext(bien_resampled)), "\n")
  cat("  Resolution: ", toString(res(bien_resampled)), "\n")
  cat("  Origin:   ", toString(origin(bien_resampled)), "\n")
  cat("  CRS:      ", toString(crs(bien_resampled)), "\n")


  # --- Convert to DataFrame and assign world_id ---
  bien_df <- as.data.frame(bien_resampled, xy = TRUE)
  # Determine which column contains the aggregated presence values.
  value_col <- if ("present" %in% names(bien_df)) "present" else names(bien_df)[3]

  # Keep only cells with presence (value == 1)
  bien_df <- bien_df %>% filter(.data[[value_col]] == 1)

  # Assign world_id from the climate grid using x, y coordinates.
  bien_df <- bien_df %>%
    mutate(world_id = cellFromXY(climate_grid, cbind(x, y))) %>%
    filter(!is.na(world_id))

  log_info("Final BIEN Raster DataFrame: Extent: {ext(bien_resampled)}, Resolution: {res(bien_resampled)}")
  log_info("Total presence points with valid world_id: {nrow(bien_df)}")

  # --- Save Processed Data ---
  output_file <- file.path(output_folder, paste0(species_name, "_processed.rds"))
  saveRDS(bien_df, output_file)
  log_info("💾 Saved processed BIEN data with world_id to {output_file}")

  return(bien_df)
}

# Example usage:
processed_bien <- process_bien_ranges("Aa mathewsii")
