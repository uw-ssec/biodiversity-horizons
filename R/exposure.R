#' Calculate species exposure to climate changes
#'
#' @param data Data for a single species
#' @param species_range List of grid cell IDs for each species
#' @param climate_data Data frame of climate data by grid cell
#' @param niche Niche limits for each species
#' @return A data frame with exposure data
#' @importFrom dplyr filter mutate across relocate case_when
#' @export
exposure <- function(data, species_range, climate_data, niche) {
  # Get data for the current species
  spp_data <- species_range[[data]]
  spp_name <- names(species_range)[[data]]

  # Filter climate data for the species' grid cells
  spp_matrix <- climate_data %>%
    filter(world_id %in% spp_data) %>%
    na.omit()

  # Extract niche limits for the species
  spp_niche <- niche %>%
    filter(species %in% spp_name)

  # Compute exposure (1 if suitable, 0 if unsuitable)
  spp_matrix <- spp_matrix %>%
    mutate(across(2:ncol(spp_matrix), ~ case_when(
      . <= spp_niche$niche_max ~ 1,
      . > spp_niche$niche_max ~ 0
    )))

  # Add species column and rearrange
  spp_matrix$species <- spp_name
  spp_matrix <- spp_matrix %>%
    relocate(species)

  return(spp_matrix)
}
