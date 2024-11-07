library(tidyverse)
library(furrr)
library(terra)
library(exactextractr)
library(pbapply)
library(sf)
library(parallel)

# set the folder containing the files as the working directory
path <- "data-raw/"

# load data
historical_climate <- readRDS(paste0(path, "historical_climaate_data.rds"))
future_climate <- readRDS(paste0(path, "future_climaate_data.rds"))
grid <- readRDS(paste0(path, "grid.rds"))
primates_shp <- readRDS(paste0(path, "primates_shapefiles.rds"))

# historical_climate : spatraster containing monthly climate simulations of surface mean temperature from 1850 to 2014.
# future_climate : spatraster containing monthly climate simulations  of surface mean temperature from 2015 to 2100.
# primates_shp : distribution polygons of world primates
# grid : 100 km x 100 km grid used to extract and match climate and distribution data

############################################################
# 1. Transform the distribution polygons to match the grid
# The function prepare_range transform the polygons to the grid format.
# It returns a list in which each elements contains a vector of integers,
# which represents the IDs of the grid cells that overlap with the polygons

# function
prepare_range <- function(range_data, grid){


  # filter presence (extant), origin (native and reintroduced), and seasonal (resident and breeding)
  range_filtered <- range_data %>%
    dplyr::filter(presence == 1,
                  origin %in% c(1,2),
                  seasonal %in% c(1,2))


  plan("multisession", workers = availableCores() - 1)

  res <- future_map(st_geometry(range_filtered), possibly(function(x){
    y <- st_intersects(x, grid)
    y <- unlist(y)
    y <- grid %>%
      slice(y) %>%
      pull(world_id)
    y

  }, quiet = T), .progress = TRUE)


  names(res) <- range_filtered$sci_name

  res <- discard(res, is.null)

  # combining elements with same name
  res_final <- tapply(unlist(res, use.names = FALSE), rep(names(res), lengths(res)), FUN = c)

  return(res_final)

}

# run
primates_range_data <- prepare_range(primates_shp, grid)

############################################################
# 2. Extract climate data using the grid
# The function extract_climate_data extract the climate data associate with each cell in the grid.
# It creates a data frame (tibble) in which each row
# represents a grid cell, and each columns a time step

# function
extract_climate_data <- function(climate_data, grid){

  climate <- project(climate_data, "+proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0")
  climate <- rotate(climate)
  climate <- climate - 273.15

  df <- exact_extract(climate, grid, fun = "mean", weights = "area")
  df <- as_tibble(df) %>%
    mutate(world_id = grid$world_id) %>%
    relocate(world_id)

  return(df)

}

# run
historical_climate_df <- extract_climate_data(historical_climate, grid)
future_climate_df <- extract_climate_data(future_climate, grid)

# rename columns
colnames(historical_climate_df) <- c("world_id", 1850:2014)
colnames(future_climate_df) <- c("world_id", 2015:2100)

############################################################
# 3. Compute the thermal limits for each species
# The function get_niche_limits calculates upper and lower niche limits.
# It creates a data frame with maximum and minimum niche estimates for each species

# functions
get_niche_limits <- function(species_ranges, climate_df){

  data <- climate_df %>%
    filter(world_id %in% species_ranges) %>%
    select(-world_id) %>%
    na.omit()

  # when the range don't overlap with the climate data, return NA
  if(nrow(data) == 0) return(tibble(niche_max = NA, niche_min = NA))

  means <- apply(data, 1, mean)
  sds <- apply(data, 1, sd) * 3

  upper_limit <- means + sds
  lower_limit <- means - sds

  upper_outliers <- sweep(data ,1, upper_limit)
  lower_outliers <- sweep(data ,1, lower_limit)

  data[upper_outliers > 0] <- NA
  data[lower_outliers < 0] <- NA

  row_max <- apply(data, 1, max, na.rm = T)
  row_min <- apply(data, 1, min, na.rm = T)

  row_max_mean <- mean(row_max)
  row_max_sd <- sd(row_max) * 3

  row_min_mean <- mean(row_min)
  row_min_sd <- sd(row_min) * 3

  if(!is.na(row_max_sd)){

    row_max_upper <- row_max_mean + row_max_sd
    row_max_lower <- row_max_mean - row_max_sd

    row_min_upper <- row_min_mean + row_min_sd
    row_min_lower <- row_min_mean - row_min_sd

    pre_max <- row_max[which(row_max <= row_max_upper & row_max >= row_max_lower)]
    pre_min <- row_min[which(row_min <= row_min_upper & row_min >= row_min_lower)]

    niche_max <- max(pre_max)
    niche_min <- min(pre_min)

    res <- data.frame(niche_max,niche_min)

  } else {

    niche_max <- apply(data, 1, max, na.rm = T)
    niche_min <- apply(data, 1, min, na.rm = T)

    res <- data.frame(niche_max,niche_min)

  }

  return(as_tibble(res))

}

# run
plan("multisession", workers = availableCores() - 1)
niche_limits <- future_map_dfr(primates_range_data, ~ get_niche_limits(.x, historical_climate_df), .id = "species", .progress = T)


############################################################
# 4. Calculate exposure
# The function exposure calculates the years in which climate change exceeds the
# niche limits of the species. The code produce data frames in which rows
# represent the species occurring in a grid cell and columns are the years in the time series.
# The cell is assigned with 1 if the climate is suitable for the species in a given year (i.e. below the maximum niche limit),
# and 0 if the climate is unsuitable (above the maximum niche limit)

# function
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
exposure_list <- future_map(1:length(primates_range_data), ~ exposure(.x, primates_range_data, future_climate_df, niche_limits), .progress = T)
names(exposure_list) <- names(primates_range_data)


############################################################
# 4. Calculate exposure
# The function exposure calculates the years in which climate change exceeds the
# niche limits of the species. The code produce data frames in which rows
# represent the species occurring in a grid cell and columns are the years in the time series.
# The cell is assigned with 1 if the climate is suitable for the species in a given year (i.e. below the maximum niche limit),
# and 0 if the climate is unsuitable (above the maximum niche limit)

# function
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
exposure_list <- future_map(1:length(primates_range_data), ~ exposure(.x, primates_range_data, future_climate_df, niche_limits), .progress = T)
names(exposure_list) <- names(primates_range_data)


############################################################
# 5. Calculate exposure times
# The function calculates in which year exposure occurs. A population (i.e. a species occurrence in a grid cell)
# is classified as exposed when the temperature exceeds the upper niche limit for at least
# five consecutive years. The function returns a data frame containing the species name,
# the ID of the grid cell (world_id), the year of exposure, the year of de-exposure, and duration of exposure.
# To become de-exposed, the same species must experience five consecutive years under
# temperatures within the thermal limits.

# function
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

# Final data frame with exposure times for each species at each grid cell
res_final
