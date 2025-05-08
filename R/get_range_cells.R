#' Prepare range data to match the climate data
#' @param species.names Vector with the name of the species
#' @param species.ranges Species range data
#' @param raster.template Raster used as template to transform the array data
#' @return A list of matched ranges
#' @importFrom terra vect rasterize
#' @importFrom sf st_transform st_crs
#' @export

get_range_cells <- function(species.names, species.ranges, raster.template){
  
  spp_range <- species.ranges[which(species.ranges$sci_name == species.names),]
  spp_range <- st_transform(spp_range, crs = st_crs(raster.template))
  spp_range <- vect(spp_range)
  r <- rasterize(spp_range, raster.template, field = 1, background = 0, touches = TRUE)
  result <- which(values(r) == 1)
  return(result)
  
}
