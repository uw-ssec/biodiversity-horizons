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
#' @return The function returns the saved result that is also stored in the output RDS file path.
prepare_range_data_from_shp_file <- function(input_file_path, grid, realm, use_parallel = TRUE, rds_output_file_path = "gridded_ranges.rds") {
  
  log_info("Reading the Input .shp File...")
  range_data <- st_read(here(input_file_path))

  # Set Up Parallel Processing
  if (use_parallel) {
    plan("multisession", workers = availableCores() - 1)
  } else {
    plan("sequential")
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
  log_info("Filtering Range Data Based on Realm ANUJ SINHA...")
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

  intersected_data <- future_map(st_geometry(range_filtered), possibly(function(x) {
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
  res <- discard(res, is.null)

  # Combine elements with the same name
  unlisted_res <- unlist(res, use.names = FALSE)
  repeated_names <- rep(names(res), lengths(res))
  res <- tapply(unlisted_res, repeated_names, FUN = c)

  return(res)
}
