#' Prepare range data to match the grid
#' @param range_data Polygon data of species distribution
#' @param grid Grid data (100 km x 100 km)
#' @return A list of grid cell IDs for each species
prepare_range <- function(range_data, grid) {
    # Filter presence (extant), origin (native and reintroduced), and seasonal (resident and breeding)
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
    res_final <- tapply(unlist(res, use.names = FALSE), rep(names(res), lengths(res)), FUN = c)

    return(res_final)
}
