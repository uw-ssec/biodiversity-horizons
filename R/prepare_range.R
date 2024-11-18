#' Prepare range data to match the grid
#' @param range_data Data frame of species ranges
#' @param grid Grid data frame for spatial matching
#' @return A list of matched ranges
#' @importFrom dplyr filter mutate select pull slice
#' @importFrom sf st_geometry st_intersects
#' @importFrom purrr discard possibly
#' @importFrom future plan availableCores
#' @importFrom furrr future_map
#' @export
prepare_range <- function(range_data, grid) {
  # Filter presence (extant), origin (native and reintroduced),
  # and seasonal (resident and breeding)
  range_filtered <- range_data %>%
    dplyr::filter(
      presence == 1,
      origin %in% c(1, 2),
      seasonal %in% c(1, 2)
    )

  # Enable parallel processing
  plan("multisession", workers = availableCores() - 1)

  res <- future_map(
    st_geometry(range_filtered),
    possibly(function(x) {
      y <- st_intersects(x, grid)
      y <- unlist(y)
      y <- grid %>%
        slice(y) %>%
        pull(world_id)
      y
    }, quiet = TRUE),
    .progress = TRUE
  )

  names(res) <- range_filtered$sci_name
  res <- discard(res, is.null)

  # Combine elements with the same name
  res_final <- tapply(unlist(res, use.names = FALSE),
                      rep(names(res), lengths(res)), FUN = c)

  return(res_final)
}
