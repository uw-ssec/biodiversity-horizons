#' Calculate thermal niche limits for each species
#'
#' @param species.data List of grid cell IDs for each species
#' @param climate.data Data frame of climate data by grid cell
#' @param sd.threshold Number of standard deviations used to define outliers
#' @param year.min Minimum year threshold for filtering climate data. When specified, only data from this year onward will be included (inclusive). If NULL, no lower year boundary is applied.
#' @param year.max Maximum year threshold for filtering climate data. When specified, only data up to and including this year will be included. If NULL, no upper year boundary is applied.
#' @return A tibble with upper and lower niche limits
#' @importFrom dplyr filter select rename group_by mutate summarise
#' @importFrom stats na.omit sd
#' @export

niche_limits <- function(species.data, climate.data, sd.threshold = NULL, year.min = NULL, year.max = NULL){
  
  if(!is.null(year.max)) climate.data <- climate.data %>% filter(year <= year.max)
  if(!is.null(year.min)) climate.data <- climate.data %>% filter(year >= year.min)
  
  if(length(species.data) == 1) {
    
    result <- climate.data %>% 
      filter(world_id %in% species.data) %>% 
      dplyr::select(-world_id) %>% 
      rename(niche_max = max_temp,
             niche_min = min_temp)
    
  } else {
    
    if(is.null(sd.threshold)){
      
      result <- climate.data %>% 
        filter(world_id %in% species.data) %>% 
        dplyr::select(-world_id) %>% 
        na.omit() %>% 
        group_by(member, month) %>%
        summarise(niche_max = max(max_temp, na.rm = TRUE),
                  niche_min = min(max_temp, na.rm = TRUE),
                  .groups = "drop") 
      
    } else {
      
      result <- climate.data %>% 
        filter(world_id %in% species.data) %>% 
        dplyr::select(-world_id) %>% 
        na.omit() %>% 
        group_by(member, month) %>%
        mutate(mean_val_max = mean(max_temp, na.rm = TRUE),
               sd_val_max = sd(max_temp, na.rm = TRUE),
               mean_val_min = mean(min_temp, na.rm = TRUE),
               sd_val_min = sd(min_temp, na.rm = TRUE),
               is_outlier = max_temp > (mean_val_max + sd.threshold * sd_val_max) | min_temp < (mean_val_min - sd.threshold * sd_val_min)) %>%
        filter(!is_outlier) %>%
        summarise(niche_max = max(max_temp, na.rm = TRUE),
                  niche_min = min(max_temp, na.rm = TRUE),
                  .groups = "drop") 
    }
  }
  
  return(result)
  
}

