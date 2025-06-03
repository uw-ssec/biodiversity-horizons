
exposure_times <- function(x, consecutive.elements = NULL, first.year = NULL){
  
  if(!is.numeric(first.year)) stop("`first.year` must be numeric.", call. = FALSE)
  if(!is.numeric(first.year)) stop("`consecutive.elements` must be numeric.", call. = FALSE)
  if(first.year < 2) stop("`consecutive.elements` cannot be smaller than 2.", call. = FALSE)
  
  species <- factor(x[1])
  world_id <- as.integer(x[2])
  n <- as.numeric(x[-c(1,2)])
  
  # compute rle of the time series
  rle_result <- rle(n)
  
  # calculate start positions and years for each run
  start_positions <- cumsum(c(1L, rle_result$lengths))[seq_along(rle_result$lengths)]
  start_years <- as.integer(first.year) + start_positions - 1L
  
  # filter runs with length >= consecutive.elements
  keep <- rle_result$lengths >= consecutive.elements
  filtered_values <- rle_result$values[keep]
  filtered_starts <- start_years[keep]
  
  # check if any runs remain after filtering
  if(length(filtered_values) == 0){
    return(tibble(species = species, world_id = world_id, exposure = NA_integer_, deexposure = NA_integer_))
  }
  
  # merge consecutive same runs in filtered_values
  merged_rle <- rle(filtered_values)
  group <- rep(seq_along(merged_rle$lengths), merged_rle$lengths)
  merged_starts <- sapply(split(filtered_starts, group), min)
  merged_values <- merged_rle$values
  
  # find indices of 1s and 0s in merged_values
  ones_idx <- which(merged_values == 1)
  zeros_idx <- which(merged_values == 0)
  
  if(length(ones_idx) == 0){
    return(tibble(species = species, world_id = world_id, exposure = NA_integer_, deexposure = NA_integer_))
  }
  
  # for each 1, find the next 0 after it
  next_zero <- sapply(ones_idx, function(i) {
    candidates <- zeros_idx[zeros_idx > i]
    if(length(candidates) == 0) NA_integer_ else candidates[1]
  })
  
  exposure <- merged_starts[ones_idx]
  deexposure <- ifelse(is.na(next_zero), NA_integer_, merged_starts[next_zero])
  
  # create the result tibble
  result <- tibble(
    species = species,
    world_id = world_id,
    exposure = exposure,
    deexposure = deexposure)

  
  return(result)
  
}
