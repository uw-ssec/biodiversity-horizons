# this script converts arrays to tibbles

# load libraries
if(!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")

pacman::p_load(tidyverse, here, terra, sf, dplyr, purrr, abind, tidyterra, rnaturalearth, here, multiApply, CSTools, zeallot)


# STEP 1: load climate data ---------------------------------------------------

climate <- readRDS("/Users/andreas/Library/CloudStorage/Dropbox/Projects/biodiversity_dp/data/data_raw/climate/HIST_tas_MPI-ESM1-2-LR_r10i1p1f1_obs-ERA5.rds")

# this is how we get the climate data from the Barcelona Supercomputing Center
# it is a list with four elements: data, latitudes, longitudes, years, and config
# since the arrays do not have names in the dimensions, we have to keep track of what each dimension represents.
# that's why we have the latitudes, longitudes, and years vectors in the list

# checking the dimension of the data
# member: ensemble member
# lon: longitude (360 values, from -180 to 180)
# lat: latitude (180 values, from -90 to 90)
# year: from 1961 to 2014

# here I will convert the array into a tibble 

lons <- climate$lon + 0.5
lats <- climate$lat
years <- climate[[names(climate)[str_detect(names(climate), "year")]]]
months <- 1:12
temp_array <- climate[[1]]

n_lon <- length(lons)
n_lat <-  length(lats)
n_year <-  length(years)
n_month <-  length(months)

lon <- rep(lons, times = n_lat * n_year * n_month)
lat <- rep(rep(lats, each = n_lon), times = n_year * n_month)
year <- rep(rep(years, each = n_lon * n_lat), times = n_month)
month <- rep(months, each = n_lon * n_lat * n_year)


# convert array to vector and create tibble

temp_tbl <- tibble(
  lon = lon,
  lat = lat,
  year = as.integer(year),
  month = as.integer(month),
  temp = as.integer(
    round(
      as.vector(temp_array), 3) * 1000
    )
)

# create a raster to get world_ids for each lat and lon combination
r_template <- rast(extent = c(-180, 180, -90, 90), res = 1)
values(r_template) <- 1:ncell(r_template)
names(r_template) <- "world_id"

# create a tibble with the world_id
id_tbl <- r_template %>% 
  as.data.frame(xy = T) %>% 
  as_tibble() %>% 
  rename(lon = x, lat = y) 

# join the world_id to the temp_tbl
temp_tbl <- temp_tbl %>%
  left_join(id_tbl, by = c("lon", "lat")) %>%
  dplyr::select(world_id, year, month, temp)






# STEP 2: load species data and convert to gridded format -----------
range_data <- readRDS(here("data-raw/primates_shapefiles.rds"))

range_data <- range_data %>% 
  filter(presence == 1,
         origin %in% c(1,2),
         seasonal %in% c(1,2))

if("terrestial" %in% names(range_data)) range_data <- range_data %>% 
  filter(terrestial == "true")

species <- sort(unique(range_data$sci_name))

# note that this step requires the raster create above (line 57)
spp_data <- purrr::map(species, safely(function(.species){
  
  print(.species)
  spp_range <- range_data[range_data$sci_name == .species,]
  spp_range <- st_transform(spp_range, crs = st_crs(r_template))
  spp_range <- vect(spp_range)
  r <- rasterize(spp_range, r_template, field = 1, background = 0, touches = T)
  
  id <- c(r_template, r) %>% 
    as.data.frame() %>%
    filter(layer == 1) %>%
    pull(world_id)
  
  return(id)
  
}, quiet = F))

# only select the result from safely
spp_data <- transpose(spp_data)[["result"]]

names(spp_data) <- species



# STEP 3: estimate thermal limits ----------------------------------------------

# function to compute the limits
get_niche_limits <- function(species_ranges, temperature_matrix, n_out){
  
  if(length(species_ranges) == 1) {
    
    data <- temperature_matrix %>% 
      filter(world_id %in% species_ranges) %>% 
      dplyr::select(-world_id) %>% 
      rename(niche_max = max_temp,
             niche_min = min_temp) 
    
  } else {
  
  data <- temperature_matrix %>% 
    filter(world_id %in% species_ranges) %>% 
    dplyr::select(-world_id) %>% 
    drop_na() %>% 
    group_by(month) %>%
    mutate(mean_val_max = mean(max_temp, na.rm = TRUE),
           sd_val_max = sd(max_temp, na.rm = TRUE),
           mean_val_min = mean(min_temp, na.rm = TRUE),
           sd_val_min = sd(min_temp, na.rm = TRUE),
           is_outlier = max_temp > (mean_val_max + n_out * sd_val_max) | min_temp < (mean_val_min - n_out * sd_val_min)) %>%
    filter(!is_outlier) %>%
    summarise(niche_max = max(max_temp, na.rm = TRUE),
              niche_min = min(max_temp, na.rm = TRUE),
              .groups = "drop")
  
  }
  
  return(data)
  
}


# first, remove outliers from the temperature tibble

n_out <- 3

temp_processed <- temp_tbl %>% 
  filter(year <= 2000) %>% 
  group_by(world_id, month) %>%
  mutate(mean_val = mean(temp, na.rm = TRUE),
         sd_val = sd(temp, na.rm = TRUE),
         is_outlier = temp > (mean_val + n_out * sd_val) | temp < (mean_val - n_out * sd_val)) %>%
  filter(!is_outlier) %>%
  summarise(max_temp = max(temp, na.rm = TRUE),
            min_temp = min(temp, na.rm = TRUE),
            .groups = "drop")  


# estimate max and min thermal niche limits
niche_limits <- map_dfr(spp_data, ~ get_niche_limits(.x, temp_processed, n_out = 3), .id = "species", .progress = T)


# STEP 4: calculate exposure ---------------------

climate_data <- temp_tbl %>% 
  filter(year > 2000)
  
species_range <- spp_data

niche <- niche_limits 

species <- names(spp_data)

exposure <- function(spp, species_range, climate_data, niche, monthly = TRUE){
  
  
  spp_world_id <- species_range[[spp]]
  
  spp_matrix <- climate_data %>% 
    filter(world_id %in% spp_world_id) %>% 
    drop_na()
  
  spp_niche <- niche %>%
    filter(species %in% spp)
  
  if(monthly){
    
    output <- purrr::map(1:12, function(.x){
      
      spp_matrix_month <- spp_matrix %>% 
        filter(month == .x)
      
      niche_min <- spp_niche %>% 
        filter(month == .x) %>%
        pull(niche_min)
      
      niche_max <- spp_niche %>%
        filter(month == .x) %>%
        pull(niche_max)
      
      spp_matrix_month <- spp_matrix_month %>%
        mutate(across(temp, ~ case_when(. <= niche_max ~ 0,
                                        . > niche_max ~ 1))) %>% 
        rename(exposure = temp) %>% 
        mutate(exposure = as.integer(exposure))
      
      
      
    }) %>% 
      bind_rows()
    
  }
  
  if(!monthly){
    
    
    niche_max <- max(spp_niche$niche_max)
    
    output <- purrr::map(1:12, function(.x){
      
      spp_matrix_month <- spp_matrix %>% 
        filter(month == .x)
      
      spp_matrix_month <- spp_matrix_month %>%
        mutate(across(temp, ~ case_when(. <= niche_max ~ 0,
                                        . > niche_max ~ 1))) %>% 
        rename(exposure = temp) %>% 
        mutate(exposure = as.integer(exposure))
      
      
      
    }) %>% 
      bind_rows()
    
  }
  
  return(output)
  
}

exposure_results <- purrr::map(species, ~ exposure(.x, species_range, climate_data, niche, monthly = TRUE), .progress = T) %>% 
  set_names(species)


