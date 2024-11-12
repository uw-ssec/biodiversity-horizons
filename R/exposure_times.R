#' Calculate exposure and de-exposure times for species
#' @param data A row of exposure data (species, world_id, and years)
#' @param original.state Initial exposure state (0 or 1)
#' @param consecutive.elements Number of consecutive years for state change
#' @return A tibble with exposure times and durations for the species
exposure_times <- function(data, original.state, consecutive.elements) {
    # Extract species and world_id
    species <- data[1]
    world_id <- data[2]

    # Extract year data as numeric vector
    n <- as.numeric(data[-c(1, 2)])

    # Calculate shift sequences
    rle_x <- data.frame(unclass(rle(n)))

    # Add year column to represent time steps
    rle_x$year <- 2015 + cumsum(rle_x$lengths) - rle_x$lengths

    # Filter sequences with sufficient consecutive elements
    rle_x <- rle_x[rle_x$lengths >= consecutive.elements,]

    # Add a line for the original state to ensure valid transitions
    rle_x <- rbind(c(1, original.state, 2000), rle_x)

    # Remove unnecessary state repetitions
    rle_x <- rle_x[c(TRUE, diff(rle_x$values) != 0),]

    # Remove the first line (original state or duplicate)
    rle_x <- rle_x[-1,]

    # Handle cases with no valid exposure sequences
    if (nrow(rle_x) == 0) {
        return(tibble(species, world_id, exposure = NA, deexposure = NA, duration = NA))
    }

    # Handle cases where all values are 0 (exposure with no de-exposure)
    if (length(unique(rle_x$values)) == 1 && unique(rle_x$values) == 0) {
        exposure <- rle_x$year[1]
        deexposure <- 2101  # Indicates de-exposure did not occur
        duration <- deexposure - exposure
        return(tibble(species, world_id, exposure, deexposure, duration))
    }

    # Handle cases with both exposure (0) and de-exposure (1)
    if (length(unique(rle_x$values)) == 2) {
        exposure <- rle_x %>%
            filter(values == 0) %>%
            pull(year)

        deexposure <- rle_x %>%
            filter(values == 1) %>%
            pull(year)

        # If there are more exposures than deexposures, add a placeholder for deexposure
        if (length(exposure) > length(deexposure)) {
            deexposure[length(exposure)] <- 2101
        }

        # Calculate duration of exposure
        duration <- deexposure - exposure

        return(tibble(species, world_id, exposure, deexposure, duration))
    }
}
