# test_array <- readRDS("data-raw/tier_1/data/climate/historical_array.rds")
# str(test_array)

# Load necessary libraries
library(terra)
library(tidyverse)
library(furrr)
library(logger)

#' @param data A multidimensional climate array (4D: year, month, lat, lon or 5D: member, year, month, lat, lon).
#' @param start_year An integer specifying the starting year for naming convention.
#' @param members A boolean indicating if the array has multiple climate model members (5D).
#' @param raster_extent A numeric vector specifying the geographic extent (min/max longitude and latitude).
#' @param input_dir A character string specifying the directory containing `.rds` climate files.
#' @param output_dir A character string specifying the directory to save processed raster files.
#' @param use_parallel A boolean indicating if parallel processing should be enabled.
#' @param number_of_workers An integer specifying the number of workers for parallel processing (default: `availableCores() - 1`).
#' @return A list of processed raster objects.

# Process all .rds files in the input directory and save outputs
process_climate_array_data <- function(input_dir, output_dir, start_year, use_parallel = TRUE, number_of_workers = availableCores() - 1) {
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

  files <- list.files(input_dir, pattern = "\\.rds$", full.names = TRUE)

  log_info("Found {length(files)} array files to process...")

  # Setup parallel processing
  if (use_parallel) {
    plan(multisession, workers = number_of_workers)
    log_info("Using {number_of_workers} parallel workers")
  } else {
    plan(sequential)
    log_info("Running sequentially")
  }

  processed_rasters <- map(files, function(file) {
    log_info("Processing: {basename(file)}")

    # Load array
    array_data <- readRDS(file)
    dims <- dim(array_data)

    log_info("Array dimensions detected: {paste(dims, collapse = ' x ')}")

    # Auto-detect if data has 5 dimensions (includes 'member')
    if (length(dims) == 5) {
      log_info("Detected 5D array, setting members = TRUE")
      members <- TRUE
    } else if (length(dims) == 4) {
      log_info("Detected 4D array, setting members = FALSE")
      members <- FALSE
    } else {
      stop("Error: Expected a 4D or 5D array but got ", length(dims), "D array.")
    }


    # Get raster extent from metadata
    lon_range <- range(attributes(array_data)$Variables$common$lon)
    lat_range <- range(attributes(array_data)$Variables$common$lat)
    raster_extent <- c(lon_range, lat_range)

    # Convert array to raster
    raster_data <- array_to_raster(array_data, start_year, members, raster_extent)

    # Define output file path
    output_file <- file.path(output_dir, paste0(tools::file_path_sans_ext(basename(file)), "_raster.rds"))

    # Save the raster list as .rds
    saveRDS(raster_data, output_file)

    log_info("Saved: {output_file}")

    return(raster_data)
  })

  # # If only one file, return its processed data directly
  # if (length(files) == 1) {
  #   processed_rasters <- processed_rasters[[1]]
  # }

  log_info("All files processed successfully!")
  return(processed_rasters)
}

# Define array-to-raster conversion function
array_to_raster <- function(data, start_year, members = FALSE, raster_extent) {
  n_years <- 1:dim(data)[["year"]]
  n_months <- 1:dim(data)[["month"]]

  if (!members) {
    # 4D Case (year, month, lat, lon)
    r <- map(n_years, function(year) {
      month_list <- map(n_months, function(month) {
        r <- flip(
          rast(
            t(data[, , year, month]),
            extent = ext(raster_extent),
            crs = "+proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0"
          )
        )
        names(r) <- month
        r
      })

      r <- rast(month_list)  # Stack months into a raster
      r <- r - 273.15        # Convert Kelvin to Celsius
      r
    })

    names(r) <- (start_year - 1) + n_years
    return(r)

  } else {
    # 5D Case (member, year, month, lat, lon)
    n_members <- 1:dim(data)[["member"]]

    r_final <- map(n_members, function(member) {
      year_list <- map(n_years, function(year) {
        month_list <- map(n_months, function(month) {
          r <- flip(
            rast(
              t(data[, , year, month, member]),
              extent = ext(raster_extent),
              crs = "+proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0"
            )
          )
          names(r) <- month
          r
        })

        r <- rast(month_list)  # Stack months into a raster
        r <- r - 273.15        # Convert Kelvin to Celsius
        r
      })

      names(year_list) <- (start_year - 1) + n_years
      return(year_list)
    })

    names(r_final) <- paste0("member_", n_members)
    return(r_final)
  }
}

# # Run the script
input_directory <- "data-raw/tier_1/data/climate"
output_directory <- "data-raw/tier_1/data/climate/outputs"

# # Test both cases
# # members_flag <- TRUE  # Set to TRUE or FALSE to test different scenarios

# log_info("Starting test run with members = {members_flag}...")
# processed_raster <- process_climate_array_data(input_directory, output_directory, 1961)

# # Check overall structure
# log_info("Processed raster structure:")
# print(str(processed_raster, max.level = 2))  # Display high-level structure

# # If members = TRUE → Expect "member_1", "member_2", etc.
# if (members_flag) {
#   log_info("Checking file names in processed raster (members = TRUE):")
#   print(names(processed_raster))  # Should return a list of members

#   if ("member_1" %in% names(processed_raster)) {
#     log_info("Checking member_1 structure:")
#     print(names(processed_raster$member_1))  # Should return a list of years

#     if ("1961" %in% names(processed_raster$member_1)) {
#       log_info("Checking 1961 structure:")
#       print(str(processed_raster$member_1$'1961', max.level = 2))  # Should return a list of months

#       # Plot first month's data
#       log_info("Plotting first month's raster (members = TRUE):")
#       plot(processed_raster$member_1$`1961`[[1]])
#     } else {
#       log_error("1961 not found in processed data!")
#     }
#   } else {
#     log_error("member_1 not found in processed data!")
#   }
# } else {
#   # If members = FALSE → Expect a list indexed by years
#   log_info("Checking file names in processed raster (members = FALSE):")
#   print(names(processed_raster))  # Should return a list of years (1961, 1962, ...)

#   if ("1961" %in% names(processed_raster)) {
#     log_info("Checking 1961 structure:")
#     print(str(processed_raster$'1961', max.level = 2))  # Should return a list of months

#     # Plot first month's data
#     log_info("Plotting first month's raster (members = FALSE):")
#     plot(processed_raster$`1961`[[1]])
#   } else {
#     log_error("1961 not found in processed data!")
#   }
# }

