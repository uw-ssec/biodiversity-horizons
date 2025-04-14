library(sf)
library(terra)
library(dplyr)
library(future)
library(furrr)
library(here)
library(stars)
library(logger)
library(arrow)
library(glue)
library(purrr)
library(parallel)


source("utility/bien_processing_util.R")


#' Prepare Species Range Data by Intersecting with Grid
#'
#' This function filters species range data based on presence,
#' origin, and seasonal criteria.
#' It intersects the species ranges with a specified grid, and
#' returns the overlapping grid cells. The results are saved as an RDS file.
#'
#' @param range_data A data frame containing species range data with geometry.
#' @param grid A spatial grid object (e.g., sf object).
#' @param realm A character string,
#'          indicating whether the species is ("terrestrial" or "marine").
#' @param use_parallel A boolean,
#'          indicating whether to use parallel processing (default is TRUE).
#' @param output_file A character string,
#'          indicating the file path to save the results as an RDS.
#' @return The function returns the saved result,
#' the result is also stored in the output RDS file path.
#' @export
prepare_range_data_from_shp_file <- function(input_file_path, grid, realm="abcd", use_parallel = TRUE,
 number_of_workers = availableCores() - 1, rds_output_file_path = "gridded_ranges.rds") {

  log_info(paste("Reading the Input .shp File at path: ", input_file_path))
  range_data <- st_read(here(input_file_path))

  # Set Up Parallel Processing
  if (use_parallel) {
    log_info("Using parallel processing...")
    plan(multisession, workers = number_of_workers)
  } else {
    log_info("Using sequential processing...")
    plan(sequential)
  }

  # 1. Filter Range Data
  log_info("Filtering Range Data...")
  range_filtered <- filter_range_data(range_data, realm)

  # 2. Perform Grid Intersections
  log_info("Perform Grid Intersections...")
  res <- intersect_ranges_with_grid(range_filtered, grid)

  # 3. Assign scientific names as names of the list elements
  names(res) <- range_filtered$sci_name

  # 4. Clean and Combine Results
  log_info("Clean Results...")
  res_final <- clean_results(res)

  # 5. Save the results to an RDS file
  saveRDS(res_final, rds_output_file_path)

  # 5. Return the final result
  return(res_final)
}


# Helper Function: Filter Range Data Based on Realm
filter_range_data <- function(range_data, realm) {
  log_info("Filtering Range Data Based on Realm...")
  range_filtered <- range_data %>%
    dplyr::filter(presence == 1, origin %in% c(1, 2), seasonal %in% c(1, 2)) %>%
    dplyr::filter(
      if (realm == "terrestial") terrestial == "true" #codespell:ignore terrestial
      else if (realm == "marine") marine == "true"
      else TRUE
    )

  return(range_filtered)
}


# Helper Function: Intersect Range Data with Grid
intersect_ranges_with_grid <- function(range_filtered, grid) {

  intersected_data <- future_map(st_geometry(range_filtered), purrr::possibly(function(x) {
    y <- st_intersects(x, grid)
    y <- unlist(y)
    y <- grid %>%
      slice(y) %>%
      pull(world_id)
    return(y)
  }, otherwise = NULL), .progress = TRUE)
  return(intersected_data)
}

# Helper Function: Clean and Combine Results
clean_results <- function(res) {

  # Remove NULL results
  res <- purrr::discard(res, is.null)

  # Combine elements with the same name
  unlisted_res <- unlist(res, use.names = FALSE)
  repeated_names <- rep(names(res), lengths(res))
  res <- tapply(unlisted_res, repeated_names, FUN = c)

  return(res)
}


#' Process Climate Grid Data
#'
#' This function processes climate data from a raster file,
#' extracts mean temperature values for each grid cell over a specified
#' range of years, converts temperatures from Kelvin to Celsius,
#' and stores the result in a `.rds` file.
#'
#' @param input_file A character string specifying the path to the
#'                   input `.tif` file.
#'                   The file should contain climate data.
#' @param output_file A character string specifying the path and
#'                    name of the output `.rds` file to save the
#'                    processed grid data.
#' @param year_range A numeric vector specifying the range of years
#'                   to be used as column names in the output
#'                   data. The default is `1850:2014`.
#'                   The length of `year_range` should match the number of
#'                   time series data points in the raster.
#'
#' @return A tibble containing the processed climate data:
#'         - `world_id`: A unique identifier for each grid cell.
#'         - Columns representing the specified range of years
#'           with mean temperature data for each grid cell.
#' @export
prepare_climate_data_from_tif <- function(input_file,
                                          output_file,
                                          year_range = 1850:2014) {
  log_info(paste("Reading the Input .tif File at path: ", input_file))
  input_data <- rast(here(input_file))

  log_info("Convert raster to spatial grid with world IDs...")
  grid <- input_data %>%
    rotate() %>%
    st_as_stars() %>%
    st_as_sf() %>%
    mutate(world_id = 1:nrow(.)) %>%
    select(world_id)

  log_info("Extract mean temperature and convert from Kelvin to Celsius...")
  updated_grid <- exactextractr:::exact_extract(input_data, grid, fun = "mean") - 273.15

  # Tidy up the data
  updated_grid <- updated_grid %>%
    rename_with(~ as.character(year_range)) %>%
    mutate(world_id = grid$world_id) %>%
    relocate(world_id)

  log_info(paste("Save the result as an .rds file at path: ", output_file))
  saveRDS(updated_grid, here(output_file))

  return(updated_grid)
}

#' Create a Spatial Grid (Raster for BIEN, sf for Shapefiles)
#'
#' Generates a grid with specified extent, resolution, and CRS.
#' Returns either a SpatRaster with world_id (for BIEN climate use) or
#' an sf object (for shapefile intersection).
#'
#' @param extent_vals Numeric vector: xmin, xmax, ymin, ymax. Default: global
#' @param resolution Numeric. Default: 1
#' @param crs CRS string. Default: EPSG:4326
#' @param for_bien Logical. If TRUE, returns SpatRaster. If FALSE, returns sf.
#'
#' @return Either a `SpatRaster` (if for_bien = TRUE) or `sf` grid.
#' @export
create_grid <- function(extent_vals = c(-180, 180, -90, 90),
                        resolution = 1,
                        crs = "EPSG:4326",
                        for_bien = FALSE) {
  r <- rast(
    extent = ext(extent_vals[1], extent_vals[2],
                 extent_vals[3], extent_vals[4]),
    resolution = resolution,
    crs = crs
  )

  world_id_layer <- r
  values(world_id_layer) <- 1:ncell(world_id_layer)
  names(world_id_layer) <- "world_id"

  if (for_bien) {
    return(world_id_layer)
  }

  # SHP use-case: return sf grid with geometry
  r <- c(world_id_layer, r)
  names(r) <- c("world_id", "geometry")

  grid <- r %>%
    st_as_stars() %>%
    st_as_sf()

  return(grid)
}

#' Prepare BIEN Climate Data from .tif
#' Supports both historical and future input
#'
#' @param input_file path to input .tif
#' @param output_file path to save .rds
#' @param year_range year sequence (default: historical 1850:2014)
#' @return processed tibble
#' @export
prepare_bien_climate_data_from_tif <- function(input_file,
                                               output_file,
                                               year_range = 1850:2014) {
  log_info("Reading climate .tif: {input_file}")
  climate_raster <- rast(here(input_file))

  world_grid <- create_grid(for_bien = TRUE)

  log_info("Extending climate raster to match world grid...")
  extended <- extend(climate_raster, world_grid)

  combined <- c(world_grid, extended)

  log_info("Converting raster to tibble...")
  dat <- as.data.frame(combined, xy = TRUE) %>%
    as_tibble() %>%
    rename_with(~ c("world_id", as.character(year_range)), .cols = -c(x, y)) %>%
    relocate(world_id) %>%
    select(-x, -y) %>%
    mutate(across(all_of(as.character(year_range)), ~ . - 273.15))  # Kelvin to Celsius

  saveRDS(dat, here(output_file))
  log_info("Saved processed climate data to {output_file}")
  return(dat)
}

#' Preprocess BIEN Species Ranges
#'
#' This function processes all BIEN species from a manifest by converting their raster ranges
#' to binary presence/absence format, aligned with a global climate grid, and saves the result
#' as Parquet files. It supports parallel execution for large-scale batch processing.
#'
#' @param manifest_path Path to the manifest Parquet file containing all species info.
#' @param processed_dir Directory to save the processed BIEN Parquet outputs.
#' @param ranges_folder Directory containing the raw raster files (.tif).
#' @param climate_grid_path Path to the climate grid raster to align with.
#' @param aggregation_rule Aggregation rule used in `process_bien_ranges()`. Default is `"any"`.
#' @param species_subset Optional vector of species names to process. If `NULL`, processes all species.
#' @param use_parallel Logical indicating whether to use parallel processing. Default is `TRUE`.
#' @param number_of_workers Number of parallel workers to use. Default is 4.
#'
#' @return No return value. Processed species are saved as Parquet files in the specified directory.
#' @export
preprocess_all_bien_species <- function(manifest_path,
                                        processed_dir,
                                        ranges_folder,
                                        climate_grid_path,
                                        aggregation_rule = "any",
                                        species_subset = NULL,
                                        use_parallel = TRUE,
                                        number_of_workers = 4,
                                        plan_type = "multisession") {
  if (!dir.exists(processed_dir)) {
    dir.create(processed_dir, recursive = TRUE)
  }

  manifest <- open_dataset(manifest_path)
  species_list <- manifest %>%
    select(spp) %>%
    distinct() %>%
    collect() %>%
    pull(spp)

  if (!is.null(species_subset)) {
    species_list <- intersect(species_list, species_subset)
  }

  log_info("Preparing to process {length(species_list)} species...")


  processing_function <- function(species_name) {
    tryCatch({
      log_info("Processing {species_name}")
      source("utility/bien_processing_util.R")

      result <- process_bien_ranges(
        species_name       = species_name,
        ranges_folder      = ranges_folder,
        output_folder      = processed_dir,
        manifest_path      = manifest_path,
        climate_grid_path  = climate_grid_path,
        aggregation_rule   = aggregation_rule
      )

      if (is.null(result)) {
        log_warn("Species {species_name} returned NULL.")
      } else {
        log_info("Successfully processed and saved: {species_name}")
      }
    }, error = function(e) {
      log_error("Failed for {species_name}: {e$message}")
    })
  }

  if (use_parallel) {
    log_info("Using parallel::mclapply with {number_of_workers} workers")
    parallel::mclapply(species_list, processing_function, mc.cores = number_of_workers)
  } else {
    log_info("Using sequential lapply")
    lapply(species_list, processing_function)
  }
  
  log_info("BIEN range pre-processing completed.")
}
