#' Transform climate data in raster format to tibble format
#' @param climate.data Climate data in raster format
#' @param temporal.resolution Whether the data represent months or years
#' @param year.min Minimum year of the time series
#' @param year.max Maximum year of the time series
#' @param format Whether the output should be in long or wide format
#' @param mask Shape file that would be used to mask the raster
#' @param data.as.integer If TRUE the climate data would be converted from double to integer to reduce file size 
#' @return A tibble with cell ids and associated climate data
#' @importFrom tibble as_tibble
#' @importFrom terra rast values ncell mask ext res crs
#' @importFrom dplyr rename_with rename left_join relocate select drop_na mutate across pivot_longer
#' @export



raster_to_tibble <- function(climate.data, 
                             temporal.resolution = NULL, 
                             year.min = NULL,
                             year.max = NULL,
                             format = "wide",
                             mask = NULL, 
                             data.as.integer = TRUE){
  
  if(is.null(year.min) | is.null(year.max)) stop("Provide year.min and year.max")
  if(is.null(temporal.resolution)) stop("Provide the temporal resolution of the climate data: years or months")
  
  .r <- climate.data[[1]]
  raster.template <- rast(extent = ext(.r), resolution = res(.r), crs = crs(.r))
  values(raster.template) <- 1:ncell(raster.template)
  
  # should the data be masked?
  if(!is.null(mask)){
    
    raster.template <- raster.template %>% 
      terra::mask(world, touches = TRUE) 
    
  }
  
  # create a tibble with the world_id
  id_tbl <- raster.template %>% 
    as.data.frame(xy = T) %>% 
    as_tibble() %>% 
    rename_with(~c("lon", "lat", "world_id")) 
  
  r <- climate.data %>% 
    as.data.frame(xy = T) %>% 
    as_tibble() %>% 
    rename(lon = x, lat = y) %>% 
    left_join(id_tbl, by = c("lon", "lat")) %>% 
    relocate(world_id) %>% 
    select(-c(lon, lat)) %>% 
    drop_na(world_id) 
  
  if(data.as.integer) r <- r %>% 
    mutate(across(-world_id, ~ as.integer(round(., 3) * 1000)))
  
  
  if(temporal.resolution == "years") {
    
    r <- r %>% 
      rename_with(~paste0(year.min:year.max), .cols = -world_id)
    
    if(format == "wide") return(r)
    if(format == "long") {
      
      r <- r %>% 
        pivot_longer(cols = -world_id,
                     names_to = "year", 
                     values_to = "value") %>%
        mutate(year = as.integer(year))
      
      return(r)
      
    }
  }
  
  if(temporal.resolution == "months") {
    
    r <- r %>% 
      rename_with(~paste0(
        rep(year.min:year.max, each = 12), 
        "_", 
        rep(1:12, times = year.max-year.min+1)
      ), .cols = -world_id) 
    
    
    if(format == "wide") return(r)
    if(format == "long") {
      
      r <- r %>%
        pivot_longer(
          cols = -world_id,  
          names_to = c("year", "month"),  
          names_sep = "_",  
          values_to = "value") %>%
        mutate(year = as.integer(year),
               month = as.integer(month))
      
      return(r)
      
    }
  }
}