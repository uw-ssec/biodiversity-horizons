raster_to_tibble <- function(climate.data, 
                             raster.template,
                             temporal.resolution = NULL, 
                             year.min = NULL,
                             year.max = NULL,
                             format = "long",
                             mask = NULL, 
                             data.as.integer = TRUE){
  
  if(is.null(year.min) | is.null(year.max)) stop("Provide 'year.min' and 'year.max'", call. = FALSE)
  if(!is.numeric(year.min) | !is.numeric(year.max)) stop("'year.min' and 'year.max' must be numeric", call. = FALSE)
  if(is.null(temporal.resolution)) stop("Provide the temporal resolution of the climate data: 'yearly' or 'monthly'", call. = FALSE)
  if(!temporal.resolution %in% c("yearly", "monthly")) stop("Temporal resolution should be 'yearly' or 'monthly'", call. = FALSE)
  if(ext(climate.data) != ext(raster.template)) stop("The extent of 'climate.data' must match the extent of 'raster.template'", call. = FALSE)
  
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
  
  
  if(temporal.resolution == "yearly") {
    
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
  
  if(temporal.resolution == "monthly") {
    
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