library(terra)  # For raster operations

#' Create a Spatial Grid as a Raster
#'
#' Generates a raster grid with unique world IDs, a specified extent, resolution,
#' and coordinate reference system (CRS).
#'
#' @param extent_vals A numeric vector of four values specifying the extent
#' in the format `c(xmin, xmax, ymin, ymax)`. Default is `c(-180, 180, -90, 90)`.
#' @param resolution A numeric value defining grid resolution. Default is `1`.
#' @param crs A character string specifying the coordinate reference system
#' (CRS) in EPSG format. Default is `"EPSG:4326"`.
#'
#' @return A raster (`SpatRaster`) representing the spatial grid.
#' @export
create_climate_raster_grid <- function(extent_vals = c(-180, 180, -90, 90),
                        resolution = 1, crs = "EPSG:4326") {

  # Create a raster with the specified extent, resolution, and CRS
  r <- rast(xmin = extent_vals[1], xmax = extent_vals[2],
            ymin = extent_vals[3], ymax = extent_vals[4],
            resolution = resolution, crs = crs)

  world_id_layer <- r  # Copy the raster structure
  values(world_id_layer) <- 1:ncell(world_id_layer)

  r <- world_id_layer

  names(r) <- "world_id"

  return(r)
}

# Example Usage:
global_grid <- create_climate_raster_grid()
writeRaster(global_grid, "data-raw/global_grid.tif", overwrite = TRUE)  # Save raster
