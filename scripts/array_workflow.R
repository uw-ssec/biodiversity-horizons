# this script runs the whole array workflow

# load libraries
library(pacman)
p_load(tidyverse, here, terra, sf, dplyr, abind, tidyterra, rnaturalearth, parallel, arrow, glue)

source("R/array_to_tibble.R")
source("R/get_range_cells.R")
source("R/remove_outliers.R")

n_cores <- 7

# STEP 1: create raster template  ---------------------------------------------------
# The raster will serve as a grid template for all analyses

r_template <- rast(extent = c(-180, 180, -90, 90), res = 1, crs = "EPSG:4326")
values(r_template) <- 1:ncell(r_template)
names(r_template) <- "world_id"

# STEP 2: prepare the climate data  ---------------------------------------------------

clim_file <- readRDS("HIST_tas_MPI-ESM1-2-LR_r10i1p1f1_obs-ERA5.rds") # this data is in the Sample Data folder in the sharepoint
clim_data <- array_to_tibble(clim_file, r_template)

# results should be saved
saveRDS("results/clim_data.rds")

# STEP 3: load species data and convert to gridded format -----------

species_ranges <- list.files(pattern = ".rds", recursive = F, full.names = T) # these data is also in the Sample Data folder in the sharepoint

# reading and preprocessing of the data. user should do this by themselves beforehand

range_data <- purrr::map(species_ranges[1], ~ {
  
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


spp_data <- mclapply(species, 
                     function(.x) get_range_cells(species.names = .x, 
                                                  species.ranges = range_data, 
                                                  raster.template = r_template), 
                     mc.cores = 7) 

names(spp_data) <- species

# results should be saved
saveRDS("results/spp_data.rds")


# STEP 4: estimate thermal limits ----------------------------------------------
clim_data <- readRDS("results/clim_data.rds")
spp_data <-  readRDS("results/spp_data.rds")

# first, remove outliers from the climate data
sd.threshold <- 5 
clim_processed <- remove_outliers(clim_data, sd.threshold = sd.threshold, year.max = 2000)


# estimate max and min thermal niche limits

niche_lim <- mclapply(spp_data, 
                      function(.x) niche_limits(.x, 
                                                climate.data = clim_processed, 
                                                sd.threshold = sd.threshold), 
                      mc.cores = 7) 


niche_lim <- niche_lim %>% 
  bind_rows(.id = "species")

# results should be saved
saveRDS(niche_lim, "results/niche_limits.rds")


# STEP 4: calculate exposure ---------------------
clim_data <- readRDS("results/clim_data.rds")
niche_lim <- readRDS("results/niche_lim.rds")
spp_data <-  readRDS("results/spp_data.rds")

species_grid_cells <- unlist(spp_data) %>% 
  unique()

# filter the climate data to only include the years after 2000 and grid cells where the species occur
forecast_clim_data <- clim_data %>% 
  filter(year > 2000,
         world_id %in% species_grid_cells) 

species <- names(spp_data)


chunk_size <- 1000
species_chunks <- split(species, ceiling(seq_along(species) / chunk_size))

for(i in seq_along(species_chunks)){
  
  exposure_results <- mclapply(species_chunks[[i]], 
                               function(.x) exposure_fast(.x, 
                                                          spp_data, 
                                                          forecast_clim_data, 
                                                          niche_lim, 
                                                          monthly = TRUE),
                               mc.cores = n_cores) 
  
  exposure_results <- as_tibble(bind_rows(exposure_results))
  
  file_name <- glue("results/exposure_chunk_{sprintf('%03d', i)}.parquet")
  write_parquet(exposure_results, file_name)
  
}
