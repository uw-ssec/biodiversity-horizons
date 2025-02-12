# this script includes 6 main steps:
# 1. load the climate data
# 2. create a grid from the data
# 3. convert the species' geographic range data to the gridded format
# 4. convert climate data to the gridded format
# 5. estimate thermal limits
# 6. estimate exposure (0 and 1 matrices)

# let's start:

if(!requireNamespace("pacman", quietly = TRUE)) install.packages("pacman")
pacman::p_load(terra, tidyverse, sf, here, stars, tidyterra, furrr, exactextractr, parallel, pbapply)


################## step 1: read climate data ####################

# the climate data comes in three main formats: netcdfs, rasters (e.g. geotiffs), and arrays
# netctdfs and rasters are the most common formats.
# arrays are a peculiar type of data used by the folks at the Barcelona Computing Centre

# first, an example with a raster (the code would be similar for a netcdf)
# load climate data (mean annual temperature)
# historical (1850-2014) and future high-emissions scenarios ssp5-8.5 (2015-2100)
historical <- rast(here("tier_1/data/climate/historical.tif"))
future <- rast(here("tier_1/data/climate/ssp585.tif"))

plot(historical[[1]])
plot(future[[1]])


# when the climate data is an array, we have to create the rasters ourselves
# here is an example using historical climate data for Africa

array_data <- readRDS(here("tier_1/data/climate/historical_array.rds"))
dim(array_data) # the data spans 54 years (1960-2014). in this case, data is monthly, not yearly. member = 10 means that the array has data from 10 different climate models.


# top build the raster, we first need to get longitude and latitude range
lon_range <- range(attributes(array_data)$Variables$common$lon[1:length(attributes(array_data)$Variables$common$lon)])
lat_range <- range(attributes(array_data)$Variables$common$lat[1:length(attributes(array_data)$Variables$common$lat)])
my_extent <- c(lon_range, lat_range)

# array_to_raster returns a list where each element represents a year,
# and contains a raster stack with 12 rasters, one for each month (jan-dec)
array_to_raster <- function(data, start_year, members = F, raster.extent){

  n_years <- 1:dim(data)[["year"]]
  n_months <- 1:dim(data)[["month"]]

  if(isFALSE(members)){

    r <- map(n_years, function(year){

      month_list <- map(n_months, function(month){

        r <- flip(
          rast(
            t(
              data[,,year,month]), extent = ext(raster.extent),
            crs = "+proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0"
          ))

        # names(r) <- lubridate::month(month, label = T)
        names(r) <- month
        r
      })

      r <- rast(month_list)
      r <- r - 273.15
      r

    })

    names(r) <- (start_year - 1) + n_years

    return(r)

  } else {

    n_members <- 1:dim(data)[["member"]]


    r_final <- map(n_members, function(member){

      year_list <- map(n_years, function(year){

        month_list <- map(n_months, function(month){

          r <- flip(
            rast(
              t(
                data[,,year,month,member]), extent = ext(raster.extent),
              crs = "+proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0"
            ))

          names(r) <- month
          r


        })

        r <- rast(month_list)
        r <- r - 273.15
        r

      })

      names(year_list) <- (start_year - 1) + n_years
      return(year_list)
    })


    names(r_final) <- paste0("member_", n_members)
    return(r_final)

  }

}

historical_array <- array_to_raster(array_data, start_year = 1961, members = T, raster.extent = my_extent)
plot(historical_array$member_1$`1961`[[1]])

################## step 2: create a grid from the data ####################

# climate data always comes in gridded formats. biodiversity data no. therefore, we have to
# create a grid so we can transform the biodiversity data to the gridded format.
# one approach is use the climate data to create the grid.

sf_use_s2(FALSE)

grid <- historical %>%
  st_as_stars() %>%
  st_as_sf() %>%
  mutate(world_id = 1:nrow(.)) %>%
  select(world_id)

# check if the grid overlaps with the climate data
ggplot() +
  geom_spatraster(data = historical[[1]]) +
  geom_sf(data = grid, fill = NA, linewidth = 0.2) +
  scale_fill_viridis_c(na.value = NA)


################## step 3: convert the geographic range data to the gridded format ####################

# now we transform the species' range polygons into a gridded format.
# for this, I use the function below.
# the function returns a list, where each element represent a different species.
# each element is a vector containing the ids of the grid cells where the species occur.

prepare_range <- function(range_data, grid, realm){


  # filter range data
  # presence = 1: extant
  # origin = 1: native, 2: reintroduced,
  # seasonal = 1: resident, 2: breeding

  range_filtered <- range_data %>%
    dplyr::filter(presence == 1,
                  origin %in% c(1,2),
                  seasonal %in% c(1,2))

  # realm is used to separate terrestrial an marine species
  if(realm == "terrestrial"){

    range_filtered <- range_filtered %>%
      dplyr::filter(terrestial == "true") #codespell:ignore terrestial

  }

  if(realm == "marine"){

    range_filtered <- range_filtered %>%
      dplyr::filter(marine == "true")

  }

  # i usually run this in parallel
  plan("multisession", workers = availableCores() - 1)

  # this function intersects the grid with the individual ranges
  # identify which grid cells overlap with the range
  # an return the ids of the grid cells
  res <- future_map(st_geometry(range_filtered), possibly(function(x){
    y <- st_intersects(x, grid)
    y <- unlist(y)
    y <- grid %>%
      slice(y) %>%
      pull(world_id)

    return(y)

  }, quiet = T), .progress = TRUE)


  names(res) <- range_filtered$sci_name

  # if a range don't overlap with the grid, it gets removed
  res <- discard(res, is.null)

  # combining elements with same name
  res_final <- tapply(unlist(res, use.names = FALSE), rep(names(res), lengths(res)), FUN = c)

  return(res_final)

}

# load geographic range data
# these are range maps of 120 amphibians species in shapefile format
species_ranges <- st_read(here("tier_1/data/species_ranges/subset_amphibians.shp"))

# run
gridded_ranges <- prepare_range(species_ranges, grid, realm = "terrestrial")


################## step 4: extract climate data to the gridded format ####################

# i use tibbles as the main data format for the analyses.
# therefore, one of the step of our workflow is to transform the climate data into a tibble.
# this is done by extracting the climate data using the grid.

historical_grid <- exact_extract(historical, grid, fun = "mean") - 273.15 # - 273.15 transforms the climate data from Kelvin to Celsius
future_grid <- exact_extract(future, grid, fun = "mean") - 273.15

# rename and make a tibble
historical_grid <- historical_grid %>%
  rename_with(~ as.character(1850:2014)) %>%
  mutate(world_id = grid$world_id) %>%
  relocate(world_id) %>%
  as_tibble()

future_grid <- future_grid %>%
  rename_with(~ as.character(2015:2100)) %>%
  mutate(world_id = grid$world_id) %>%
  relocate(world_id) %>%
  as_tibble()


# in these tibbles, each row represent a grid cell, and each column represents a time step
# this works pretty well when time steps are years and  grid cells have 100 x 100 km resolution.
# but if the climate data had 1 x 1 km resolution, these tibbles would have over 177 million rows (!)
# including the ocean in the analyses would add an extra 400 million rows (at 1 km resolution).




################## step 5: estimate thermal limits ####################

# now that we have both the climate data and range data in gridded formats,
# we can now estimate the thermal limits of the species.

# this is one of the functions we use to estimate niche limits.

get_niche_limits <- function(spp_data, climate_data){


  res <- climate_data %>%
    filter(world_id %in% spp_data) %>%
    select(-world_id) %>%
    summarise(niche_max = max(c_across(everything())),
              niche_99th = quantile(c_across(everything()), probs = .99, type = 7),
              niche_95th = quantile(c_across(everything()), probs = .95, type = 7))

  return(res)

}

plan("multisession", workers = 2)
niche_limits <- future_map_dfr(gridded_ranges, ~ get_niche_limits(.x, historical_grid), .id = "species")
niche_limits

################## step 6: estimate exposure ####################

# from this point, i am using the same code i shared previously, which is in the repository already

# function to calculate exposure
exposure <- function(data, species_range, climate_data, niche){

  spp_data <- species_range[[data]]
  spp_name <- names(species_range)[[data]]

  spp_matrix <- climate_data %>%
    filter(world_id %in% spp_data) %>%
    na.omit()

  spp_niche <- niche %>%
    filter(species %in% spp_name)


  spp_matrix <- spp_matrix %>%
    mutate(across(2:ncol(spp_matrix), ~ case_when(. <= spp_niche$niche_max ~ 1,
                                                  . > spp_niche$niche_max ~ 0)))

  spp_matrix$species <- spp_name
  spp_matrix <- spp_matrix %>%
    relocate(species)

  return(spp_matrix)

}

# run
plan("multisession", workers = availableCores() - 1)
exposure_list <- future_map(1:length(gridded_ranges), ~ exposure(.x, gridded_ranges, future_grid, niche_limits), .progress = T)
names(exposure_list) <- names(gridded_ranges)
exposure_list

# calculate exposure times
exposure_times <- function(data, original.state, consecutive.elements){

  species <- data[1]
  world_id <- data[2]

  n <- as.numeric(data[-c(1,2)])

  # Calculate shift sequences
  rle_x <- data.frame(unclass(rle(n)))

  # Add year
  rle_x$year <- 2015 + cumsum(rle_x$lengths) - rle_x$lengths

  # Select only shifts with n or more consecuitve elements
  rle_x <- rle_x[rle_x$lengths >= consecutive.elements,]

  # Add line with original state
  rle_x <- rbind(c(1, original.state, 2000), rle_x)

  # Remove lines with shifts that are not separated for n consecutive elements
  rle_x <- rle_x[c(TRUE, diff(rle_x$values) != 0),]

  # Remove first line because the first line is either the original state
  # or the same value as the original state
  rle_x <- rle_x[-1,]

  # if there are no rows in rle_x, it means no exposure
  if(nrow(rle_x) == 0) {

    exposure <- NA
    deexposure <- NA
    duration <- NA

    return(tibble(species, world_id, exposure, deexposure, duration))

  }


  # if the only value in x$values is 0, it means that there was a single exposure event
  # with no de-exposure

  if(length(unique(rle_x$values)) == 1){
    if(unique(rle_x$values) == 0){

      exposure <- rle_x$year[1]
      deexposure <- 2101 # if deexposure = 2101 it means that deexposure did not occur
      duration <- deexposure - exposure
      return(tibble(species, world_id, exposure, deexposure, duration))
    }
  }

  # the remaining data will always have 0 and 1 on rle_x$values
  if(length(unique(rle_x$values)) == 2){

    exposure <- rle_x %>%
      filter(values == 0) %>%
      pull(year)

    deexposure <- rle_x %>%
      filter(values == 1) %>%
      pull(year)

    # if(length(deexposure) == 0) deexposure <- 2201
    if(length(exposure) > length(deexposure))  deexposure[length(exposure)] <- 2101

    duration <- deexposure - exposure

    return(tibble(species, world_id, exposure, deexposure, duration))

  }
}

# run
exposure_df <- exposure_list %>%
  bind_rows() %>%
  mutate(sum = rowSums(select(., starts_with("2")))) %>%
  filter(sum < 82) %>%  # Select only cells with < 82 suitable years (>= 82 years means no exposure).This is done to improve computational time by avoiding calcluting exposure for species that are not exposed.
  select(-sum)

cl <- makeCluster(availableCores() - 1)
clusterEvalQ(cl, library(dplyr))
clusterExport(cl, "exposure_times")



res_final <- pbapply(X = exposure_df,
                     MARGIN = 1,
                     FUN = function(x) exposure_times(data = x, original.state = 1, consecutive.elements = 5),
                     cl = cl)


res_final <- res_final %>%
  bind_rows() %>%
  na.omit()


stopCluster(cl)

# final tibble with exposure times for each species at each grid cell
res_final
