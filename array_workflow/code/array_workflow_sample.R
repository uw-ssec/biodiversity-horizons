# this script is used to transform species shapefiles into an array format, 
# that would then be integrated with the climate data arrays from BSC to run the exposure analyses

# load libraries
if(!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")

pacman::p_load(terra, sf, dplyr, purrr, abind, tidyterra, rnaturalearth, here, multiApply, CSTools, slam)

# pacman::p_load(exactextractr, furrr, glue, here, rnaturalearth, terra, tidyverse, sf, 
#                stars, multiApply, CSTools, tictoc, s2dv, abind, tidyterra, arrow, SparseArray)

# function to transform shapefiles into an array format
# the function takes two inputs: data and raster.template
# data is the shapefile, and raster.template is a raster object that will be used to rasterize the shapefile
shp_to_array <- function(data, raster.template){
  
  # first I got the species names
  species <- sort(unique(data$sci_name))
  
  # then for each species I
  # 1. subset the data
  # 2. transform the sf object into a terra::SpatVect object
  # 3. transform the SpatVect object into a raster object. This will result in a 1° raster with two values: 0 and 1 (0 for species absence, 1 for presence) 
  # 4. transform the raster object into a matrix
  # note: the rasterize function has the global extent as default (i.e. lat min = -90, lat max = 90, lon min = -180, lon max = 180)
  #       therefore all rasters produced will have a global extent.
  
  res <- purrr::map(species, function(.species){
    
    spp_range <- data[data$sci_name == .species,]
    spp_range <- vect(spp_range)
    r <- rasterize(spp_range, raster.template, field = 1, background = 0, touches = T)
    m <- as.matrix(r, wide = TRUE)
    return(m)
    
  }, .progress = T)
  
  # I used the abind::abind to tranform the list into an array
  species_array <- abind(res, along = 3)
  
  # however, this array does not have dimnames, so I have to remake the array to add them
  # these names are needed to keep track of what each array dimension represents

  species_array <- array(species_array, dim = list(
    lat = 180,
    lon = 360,
    species = length(species)
  ))
  
  # the output is a list with the array, the lat and lon values, and the species names
  
  result <- list(data = species_array,
                 lat = unique(crds(raster.template)[,2]),
                 lon = unique(crds(raster.template)[,1]),
                 species = species
  )
  
  return(result)
  
}


# create template raster
r_template <- rast(res = 1, crs = "EPSG:4326")


# load sample range data (you can use the primates shapefile)

# amphibians ----

ranges <- st_read("/Users/andreas/Library/CloudStorage/Dropbox/Projects/species-overshoot/raw_data/species_data/range_maps_iucn/AMPHIBIANS/AMPHIBIANS.shp")

# filter ranges based on pre-defined attributes
ranges <- ranges %>% 
  filter(presence == 1,
         origin %in% c(1,2),
         seasonal %in% c(1,2),
         terrestial == "true") 

# transform the shapefile into an array
# I am doing this only for a few species to test the function
species_arrays <- shp_to_array(ranges[1:30,], r_template)

# the output is a list with the array, the lat and lon values, and the species names
dim(species_arrays$data)


# if you want to see the output is correct, you can use the following code

# transform the species shapefile in SpatVect object
species_vector <- vect(ranges[1:30,])

# select a given species
species_number <- 10

# subset the SpatVect based on the species number
species <- species_vector %>%
  tidyterra::filter(sci_name == species_arrays$species[species_number])

# world map
world <- ne_countries(scale = "medium", returnclass = "sf")

# tranform the array back into a raster object
species_raster <- rast(species_arrays$data[,,species_number],
                       extent = c(-180, 180, -90, 90),
                       crs = "EPSG:4326")

plot(species_raster)
plot(world$geometry, col = NA, border = "white", add=T)
plot(species, add=T, border = "red", lwd = 3)


# if we load the climate data, we can see that how the species array and the climate data have the lat and lon dimensions
climate <- readRDS(here("data/data_raw/climate/HIST_tas_MPI-ESM1-2-LR_r10i1p1f1_obs-ERA5.rds"))
dim(climate$hist)
dim(species_arrays$data)



######################################################################################

# now let's see how the arrays work in practice
# I will use the climate data and the species arrays to estimate species thermal limits using the climate data loaded above 

# these are the functions

SpecieThreshold <- function(climate_data, species_array, lon_dim = 'lon', lat_dim = 'lat', 
                            time_dims = 'year', mask_true_value = 1, 
                            percentiles = 0.95, ncores = 1){
  
  ## Checks
  stopifnot(identical(dim(climate_data)[lon_dim],dim(species_array)[lon_dim]))
  stopifnot(identical(dim(climate_data)[lat_dim],dim(species_array)[lat_dim]))
  stopifnot(is.character(lon_dim))
  stopifnot(is.character(lat_dim))
  stopifnot(is.character(time_dims))
  stopifnot(is.vector(percentiles))
  stopifnot(is.numeric(percentiles))
  stopifnot(all(percentiles>=0) & all(percentiles<=1))
  
  ## Merging time dimensions
  if (length(time_dims) > 1){
    climate_data <- CSTools::MergeDims(data = climate_data, 
                                       merge_dims = time_dims, 
                                       rename_dim = 'time_dim',
                                       na.rm = FALSE)
  } else {
    names(dim(climate_data))[which(names(dim(climate_data)) == time_dims)] <- 'time_dim'
  }
  
  ## Parallel computation
  thresholds <- multiApply::Apply(data = list(climate_data = climate_data, 
                                              species_array = species_array),
                                  target_dims = list(climate_data = c(lon_dim, 
                                                                      lat_dim, 
                                                                      'time_dim'),
                                                     species_array = c(lon_dim,
                                                                     lat_dim)),
                                  output_dims = 'percentile',
                                  fun = .SpecieThreshold,
                                  mask_true_value = mask_true_value,
                                  percentiles = percentiles,
                                  ncores = ncores)$output1
  return(thresholds)
}

.SpecieThreshold <- function(climate_data, species_array, mask_true_value, percentiles){
  
  ## climate_data [lon, lat, time_dim]
  ## species_array [lon, lat]
  
  # Expand species_array along the time dimension
  species_array <- array(rep(species_array, times = dim(climate_data)[3]), dim = dim(climate_data))
  
  # Apply the mask
  climate_data <- ifelse(species_array == mask_true_value, climate_data, NA)
  
  # Distribution of climate_data
  climate_data <- as.vector(climate_data)
  climate_data <- climate_data[!is.na(climate_data)]
  
  # Threshold
  thresholds <- as.array(quantile(climate_data, probs = percentiles, type = 7))
  
  return(thresholds)
}




# now let's run the function
thresholds <- SpecieThreshold(climate$hist, species_arrays$data, ncores = 7, time_dims = c("year", "month"))

# the output is an array with the three dimensions: percentile, member, species
# in this case, percentile is the 95th percentile of the climate data across the range of each species
# and member is the ensemble member of the climate data


# we have also functions to calculate species exposure using the climate data and the species arrays, but I will stop here. 

################################################################################

# FOR FURTHER DISCUSSION
# the array framework is efficient, but it has a problem with memory usage.
# that's because the species_array is a 3D array with the dimensions lat, lon, and species.
# therefore for each species we have 360 * 180 = 64800 values. Even if a species has a small range, the array will have 64800 values.
# this is not a problem for a few species, but it can be a problem for many species.
# one way to solve this problem is to use a sparse array. this can drastically reduce the memory usage.

# transform species_array into a sparse array:
species_arrays_sparse <- slam::as.simple_sparse_array(species_arrays$data)

# compare object sizes:
print(object.size(species_arrays$data), units = "Kb")
print(object.size(species_arrays_sparse), units = "Kb")

# but the problem with sparse arrays is that they are not supported by the multiApply function.
# therefore we should either modify the multiApply function to support sparse arrays or write our own functions to calculate exposure using the sparse arrays.