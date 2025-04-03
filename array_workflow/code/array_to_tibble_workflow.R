# this script converts arrays to tibbles

# load libraries
library(pacman)
p_load(tidyverse, here, terra, sf, dplyr, abind, tidyterra, rnaturalearth, pbmcapply)

n_cores <- 7
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

# these analyses are for terrestrial species
# to reduce computational time, we will only keep grid cells over land
world <- ne_countries(scale = "large", returnclass = "sf") %>% 
  st_transform(crs = st_crs(r_template))

r_template_terrestrial <- r_template %>% 
  mask(world) 




# STEP 2: load species data and convert to gridded format -----------
# range_data <- readRDS(here("data-raw/primates_shapefiles.rds"))
species_ranges <- list.files("/Users/andreas/Data/IUCN/rds", recursive = T, full.names = T)[c(1,3,4)]



range_data <- purrr::map(species_ranges, ~ {
  
  data <- readRDS(.x)
  if("terrestial" %in% names(data)) data <- data %>% 
      filter(terrestial == "true")
  
  if("Shape" %in% names(data)) data <- data %>% 
      rename(geometry = Shape)
  
  data <- data %>% 
    filter(presence == 1,
           origin %in% c(1,2),
           seasonal %in% c(1,2)) %>% 
    dplyr::select(sci_name, geometry) 
  
  return(data)
  
}) %>% 
  bind_rows()

species <- sort(unique(range_data$sci_name))



# note that this step requires the raster create above (line 76)


spp_data <- pbmclapply(species, function(.species) {

  spp_range <- range_data[which(range_data$sci_name == .species),]
  spp_range <- st_transform(spp_range, crs = st_crs(r_template))
  spp_range <- vect(spp_range)
  r <- rasterize(spp_range, r_template_terrestrial, field = 1, background = 0, touches = TRUE)
  which(values(r) == 1)
  
}, mc.cores = n_cores) %>% 
  set_names(species)



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

n_out <- 5

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

niche_limits <- pbmclapply(spp_data, 
                          function(.x) get_niche_limits(.x, temp_processed, n_out = n_out), 
                          mc.cores = n_cores) %>% 
  bind_rows(.id = "species")


# STEP 4: calculate exposure ---------------------
  
species_grid_cells <- unlist(spp_data) %>% 
  unique()

# filter the climate data to only include the years after 2000 and grid cells where the species occur
climate_data <- temp_tbl %>% 
  filter(year > 2000,
         world_id %in% species_grid_cells) 


species <- names(spp_data)

exposure_fast <- function(spp, species_range, climate_data, niche, monthly = TRUE){
  
  
  spp_world_id <- species_range[[spp]]
  
  spp_matrix <- climate_data[climate_data$world_id %in% spp_world_id,] %>% drop_na()
  
  spp_niche <- niche[niche$species == spp,]
  
  
  if(monthly){
    
    merged <- merge(spp_matrix, spp_niche, by = "month")
    
    merged$exposure_max <- as.integer(pmax(merged$temp - merged$niche_max, 0))
    merged$exposure_min <- as.integer(pmin(merged$temp - merged$niche_min, 0))
    
    # Convert to integers
    merged$exposure_max <- as.integer(merged$exposure_max)
    merged$exposure_min <- as.integer(merged$exposure_min)
    
    output <- merged[, c("world_id", "year", "month", "exposure_max", "exposure_min")] 
    
   return(output)
    
  } 
  
  if(!monthly){
    
    niche_max <- max(spp_niche$niche_max)
    niche_min <- max(spp_niche$niche_min)
    
    # Vectorized calculations
    spp_matrix$exposure_max <- as.integer(pmax(spp_matrix$temp - niche_max, 0))
    spp_matrix$exposure_min <- as.integer(pmin(spp_matrix$temp - niche_min, 0))
    
    # Select final columns
    output <- spp_matrix[, c("world_id", "year", "month", "exposure_max", "exposure_min")] 
    
    return(output)
    
  }
  
}


exposure_results <- pbmclapply(species, 
                               function(.x) exposure_fast(.x, spp_data, climate_data, niche_limits, monthly = TRUE),
                               mc.cores = n_cores) %>% 
  set_names(species) %>% 
  bind_rows(.id = "species") %>% 
  as_tibble()


print(object.size(exposure_results), units = "Gb")

saveRDS(exposure_results, here("array_workflow/data/exposure_results.rds"))
# indicator 1: at least n months of exposure during the forecast period
# is a Boolean indicator: TRUE or FALSE

# indicator 2: total number of months in the forecast period
# in this case, is between 2001 and 2014

indicator <- exposure_results %>% 
  group_by(species, world_id) %>% 
  summarise(indicator_2 = sum(exposure_max > 0),
            .groups = "drop") %>% 
  mutate(indicator_1 = ifelse(indicator_2 >= 1, TRUE, FALSE)) 
