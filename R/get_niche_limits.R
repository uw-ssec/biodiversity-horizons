#' Calculate thermal niche limits for each species
#'
#' @param species_ranges List of grid cell IDs for each species
#' @param climate_df Data frame of climate data by grid cell
#' @return A tibble with upper and lower niche limits
#' @importFrom dplyr filter select
#' @importFrom tibble tibble
#' @importFrom stats na.omit sd
#' @export
get_niche_limits <- function(species_ranges, climate_df) {
  # Filter climate data for the species ranges
  data <- climate_df %>%
    filter(world_id %in% species_ranges) %>%
    select(-world_id) %>%
    na.omit()

  # Return NA when no data is available
  if (nrow(data) == 0) {
    return(tibble(niche_max = NA, niche_min = NA))
  }

  # Calculate mean and standard deviation
  means <- apply(data, 1, mean)
  sds <- apply(data, 1, sd) * 3

  # Define upper and lower limits
  upper_limit <- means + sds
  lower_limit <- means - sds

  # Remove outliers
  upper_outliers <- sweep(data, 1, upper_limit)
  lower_outliers <- sweep(data, 1, lower_limit)
  data[upper_outliers > 0] <- NA
  data[lower_outliers < 0] <- NA

  # Compute max and min for each row
  row_max <- apply(data, 1, max, na.rm = TRUE)
  row_min <- apply(data, 1, min, na.rm = TRUE)

  # Calculate overall niche limits
  row_max_mean <- mean(row_max)
  row_max_sd <- sd(row_max) * 3

  row_min_mean <- mean(row_min)
  row_min_sd <- sd(row_min) * 3

  if (!is.na(row_max_sd)) {
    # Handle outlier removal for max and min
    row_max_upper <- row_max_mean + row_max_sd
    row_max_lower <- row_max_mean - row_max_sd

    row_min_upper <- row_min_mean + row_min_sd
    row_min_lower <- row_min_mean - row_min_sd

    pre_max <- row_max[
      which(row_max <= row_max_upper & row_max >= row_max_lower)
    ]

    pre_min <- row_min[
      which(row_min <= row_min_upper & row_min >= row_min_lower)
    ]

    niche_max <- max(pre_max)
    niche_min <- min(pre_min)
  } else {
    # Fallback calculation
    niche_max <- apply(data, 1, max, na.rm = TRUE)
    niche_min <- apply(data, 1, min, na.rm = TRUE)
  }

  # Return results as a tibble
  return(tibble(niche_max, niche_min))
}
