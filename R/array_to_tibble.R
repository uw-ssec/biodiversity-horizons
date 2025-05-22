#' Transform climate data in array format to tibble format
#' @param array.data Multidimensional climate array 
#' @param raster.template Raster used as template to transform the array data
#' @param temporal.resolution Whether the data comes at daily or monthly scale
#' @param latitude Name of the latitude variable in the array data
#' @param longitude Name of the longitude variable in the array data
#' @param mask Shape file that would be used to mask the raster
#' @param data.as.integer If TRUE the climate data would be converted from double to integer to reduce file size 
#' @return A tibble with five columns: member, world_id, year, month, temp
#' @importFrom stringr str_detect
#' @importFrom tibble tibble as_tibble
#' @importFrom terra mask
#' @importFrom dplyr select left_join arrange rename
#' @importFrom stats na.omit
#' @export

array_to_tibble <- function(array.data, 
                            raster.template,
                            temporal.resolution = "months", 
                            latitude = "lat",
                            longitude = "lon",
                            mask = NULL, 
                            data.as.integer = TRUE){
  
  if(!all(c(latitude, longitude) %in% names(array.data))) stop("Latitude and longitude names do not match the names in the array")
  
  lons <- array.data[[longitude]] + 0.5
  lats <- array.data[[latitude]]
  years <- array.data[[names(array.data)[str_detect(names(array.data), "year")]]]
  months <- 1:12
  # if(temporal.resolution != "months") days <- 1:365
  temp_array <- array.data[[1]]
  if("member" %in% names(dim(temp_array))){
    members <- 1:dim(temp_array)[["member"]]
  } else {
    members <- 1
  }
  
  n_lon <- length(lons)
  n_lat <-  length(lats)
  n_year <-  length(years)
  n_month <-  length(months)
  n_member <- length(members)
  
  # if(temporal.resolution != "months") n_day <- length(days)
  
  lon <- rep(lons, times = n_lat * n_year * n_month)
  lon <- rep(lon, times = n_member)
  
  lat <- rep(rep(lats, each = n_lon), times = n_year * n_month)
  lat <- rep(lat, times = n_member)
  
  year <- rep(rep(years, each = n_lon * n_lat), times = n_month)
  year <- rep(year, times = n_member)
  
  month <- rep(months, each = n_lon * n_lat * n_year)
  month <- rep(month, times = n_member)
  
  member <- rep(members, each = n_lon * n_lat * n_year * n_month)
  
  
  
  
  # convert array to vector and create tibble
  if(data.as.integer){
    
    temp_tbl <- tibble(
      member = member,
      lon = lon,
      lat = lat,
      year = as.integer(year),
      month = as.integer(month),
      temp = as.integer(
        round(
          as.vector(temp_array), 3) * 1000)
    )
    
  } else {
    
    temp_tbl <- tibble(
      member = member,
      lon = lon,
      lat = lat,
      year = as.integer(year),
      month = as.integer(month),
      temp = as.vector(temp_array))
    
  }
  
  
  # should the data be masked?
  if(!is.null(mask)){
    
    raster.template <- raster.template %>% 
      terra::mask(world, touches = TRUE) 
    
  }
  
  # create a tibble with the world_id
  id_tbl <- raster.template %>% 
    as.data.frame(xy = T) %>% 
    as_tibble() %>% 
    rename(lon = x, lat = y) 
  
  # join the world_id to the temp_tbl
  temp_tbl <- temp_tbl %>%
    left_join(id_tbl, by = c("lon", "lat")) %>%
    dplyr::select(member, world_id, year, month, temp) %>% 
    dplyr::arrange(member, world_id, year, month) %>% 
    na.omit()
  
  return(temp_tbl)
  
}



