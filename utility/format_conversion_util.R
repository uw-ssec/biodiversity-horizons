library(sf)
library(terra)
library(dplyr)
library(future)
library(furrr)
library(here)
library(stars)
library(logger)


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

#' Create a Spatial Grid as an sf Object
#'
#' This function generates a raster grid with a specified extent, resolution,
#' and coordinate reference system (CRS),
#' assigns unique IDs to each cell,
#' and converts it into a simple feature (`sf`) object.
#'
#' @param extent_vals A numeric vector of four values specifying the extent
#' in the format `c(xmin, xmax, ymin, ymax)`. Default is `c(-180, 180, -90, 90)`
#' @param resolution A numeric value defining grid resolution. Default is `1`
#' @param crs A character string specifying the coordinate reference system
#' (CRS) in EPSG format. Default is `"EPSG:4326"`.
#'
#' @return An `sf` object representing the spatial grid.
#' @export
create_grid <- function(extent_vals = c(-180, 180, -90, 90),
                        resolution = 1, crs = "EPSG:4326") {

  # Create a raster with the specified extent, resolution, and CRS
  r <- rast(extent = ext(extent_vals[1],
                         extent_vals[2],
                         extent_vals[3],
                         extent_vals[4]),
            resolution = resolution,
            crs = crs)

  # Create a new layer for world_id
  world_id_layer <- r  # Copy the raster structure
  values(world_id_layer) <- 1:ncell(world_id_layer)  # Assign unique IDs

  # Combine layers into a multi-layer raster
  r <- c(world_id_layer, r)

  # Rename layers
  names(r) <- c("world_id", "geometry")

  # Convert raster to an sf object
  grid <- r %>%
    st_as_stars() %>%
    st_as_sf()

  return(grid)
}
