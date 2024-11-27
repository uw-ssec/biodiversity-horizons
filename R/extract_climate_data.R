#' Extract climate data for each grid cell
#'
#' @param climate_data Raster data of climate variables
#' @param grid Grid data frame
#' @return A tibble with climate data by grid cell
#' @importFrom dplyr mutate relocate
#' @importFrom tibble as_tibble
#' @importFrom terra project rotate
#' @importFrom exactextractr exact_extract
#' @export
extract_climate_data <- function(climate_data, grid) {
  climate <- project(
    climate_data,
    "+proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0"
  )
  climate <- rotate(climate)
  climate <- climate - 273.15

  df <- exact_extract(climate, grid, fun = "mean", weights = "area")
  df <- as_tibble(df) %>%
    mutate(world_id = grid$world_id) %>%
    relocate(world_id)

  return(df)
}
