#' Calculate thermal niche limits for each species
#'
#' @param species.data A vector of grid cell IDs for each species
#' @param climate.data  A tibble or data frame with climate data
#' @param sd.threshold Optional. A numeric value specifying the number of standard deviations used to define outliers
#' @return A tibble with upper and lower niche limits
#' @importFrom dplyr filter select rename group_by mutate summarise
#' @importFrom stats na.omit sd
#' @export


# climate.data <- climate_data %>% select(-member)
# species.data <- readRDS(here("data/processed/species/range_maps_grid_cells/spp_data.rds"))
# species.data <- species_data[[1]]
# sd.threshold <- 3

niche_limits <- function(species.data, 
                         climate.data, 
                         sd.threshold = NULL, 
                         percentiles = c(0, 1), 
                         type = 7){

  # Check if percentiles argument is valid
  if(!is.numeric(percentiles) || length(percentiles) != 2) {
    stop("'percentiles' must be a numeric vector of length 2 e.g., c(0.01, 0.99).", call. = F)
  }
  # Ensure lower percentile is first
  percentiles <- sort(percentiles)
  
  # If the species occur in a single grid cell, the function returns the monthly value
    if(length(species.data) == 1) {
    
    result <- climate.data %>% 
      filter(world_id %in% species.data) %>% 
      dplyr::select(-world_id) %>% 
      rename(niche_max = max_value,
             niche_min = min_value)
    
    return(result)
    
    } 
  
  if("month" %in% names(climate.data)){
    
    if(is.null(sd.threshold)){
      
      result <- climate.data %>% 
        filter(world_id %in% species.data) %>% 
        dplyr::select(-world_id) %>% 
        na.omit() %>% 
        # group_by(member, month) %>%
        group_by(month) %>%
        summarise(niche_max = quantile(max_value, probs = percentiles[2], na.rm = TRUE, type = type), 
                  niche_min = quantile(min_value, probs = percentiles[1], na.rm = TRUE, type = type),
                  .groups = "drop") 
      
    } else {
      
      result <- climate.data %>% 
        filter(world_id %in% species.data) %>% 
        dplyr::select(-world_id) %>% 
        na.omit() %>% 
        # group_by(member, month) %>%
        group_by(month) %>%
        mutate(mean_val_max = mean(max_value, na.rm = TRUE),
               sd_val_max = sd(max_value, na.rm = TRUE),
               mean_val_min = mean(min_value, na.rm = TRUE),
               sd_val_min = sd(min_value, na.rm = TRUE),
               is_outlier = max_value > (mean_val_max + sd.threshold * sd_val_max) | min_value < (mean_val_min - sd.threshold * sd_val_min)) %>%
        filter(!is_outlier) %>%
        summarise(niche_max = quantile(max_value, probs = percentiles[2], na.rm = TRUE, type = type), 
                  niche_min = quantile(min_value, probs = percentiles[1], na.rm = TRUE, type = type),
                  .groups = "drop") 
    }
    
    
  } else {
    
    if(is.null(sd.threshold)){
      
      result <- climate.data %>% 
        filter(world_id %in% species.data) %>% 
        dplyr::select(-world_id) %>% 
        na.omit() %>% 
        summarise(niche_max = quantile(max_value, probs = percentiles[2], na.rm = TRUE, type = type), 
                  niche_min = quantile(min_value, probs = percentiles[1], na.rm = TRUE, type = type),
                  .groups = "drop") 
      
    } else {
      
      result <- climate.data %>% 
        filter(world_id %in% species.data) %>% 
        dplyr::select(-world_id) %>% 
        na.omit() %>% 
        mutate(mean_val_max = mean(max_value, na.rm = TRUE),
               sd_val_max = sd(max_value, na.rm = TRUE),
               mean_val_min = mean(min_value, na.rm = TRUE),
               sd_val_min = sd(min_value, na.rm = TRUE),
               is_outlier = max_value > (mean_val_max + sd.threshold * sd_val_max) | min_value < (mean_val_min - sd.threshold * sd_val_min)) %>%
        filter(!is_outlier) %>%
        summarise(niche_max = quantile(max_value, probs = percentiles[2], na.rm = TRUE, type = type), 
                  niche_min = quantile(min_value, probs = percentiles[1], na.rm = TRUE, type = type),
                  .groups = "drop") 
    }
    
  }
  
  return(result)
  
}

