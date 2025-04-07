library(terra)
library(logger)
library(arrow)
library(dplyr)
library(purrr)
library(glue)
library(sf)
library(stars)

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

# Main function to process BIEN species range data and align with the climate grid.
process_bien_ranges <- function(
  species_name,
  ranges_folder,
  output_folder,
  manifest_path,
  climate_grid_path,
  aggregation_rule
)
 {
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

  # --- Aggregate to 1° resolution ---
  # Compute the aggregation factor based on the native resolution of the reprojected BIEN raster.
  current_res <- res(final_stack_wgs84)[1]  # assuming square pixels
  agg_factor <- round(1 / current_res)

  bien_1deg <- aggregate(final_stack_wgs84, fact = c(agg_factor, agg_factor), fun = function(x) {
    if (any(x == 1, na.rm = TRUE)) 1 else NA
  })


  if (all(is.na(terra::values(bien_1deg)))) {
    log_error(" BIEN raster has only NA values after aggregation. Aborting process.")
    return(NULL)
  }

  # --- Resample to match the climate grid exactly ---
  bien_resampled <- resample(bien_1deg, climate_grid, method = "near")

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

  bien_df$species_name <- species_name

  # --- Save Processed Data as Parquet ---
  output_file_parquet <- file.path(output_folder, paste0(species_name, "_processed.parquet"))
  write_parquet(bien_df, output_file_parquet)
  if (!file.exists(output_file_parquet)) {
  log_error("Parquet file was not written for {species_name}")
}

  log_info("Saved processed BIEN data to {output_file_parquet}")

  return(bien_df)
}
