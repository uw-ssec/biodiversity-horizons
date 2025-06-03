#' Calculate the climate limits for each grid cell
#'
#' @param climate.data Climate tibble
#' @param sd.threshold Optional. A numeric value specifying the number of standard deviations used to define outliers
#' @param temporal.resolution Whether the data comes at yearly or monthly scale
#' @param year.min Minimum year threshold for filtering climate data. When specified, only data from this year onward will be included (inclusive). If NULL, no lower year boundary is applied.
#' @param year.max Maximum year threshold for filtering climate data. When specified, only data up to and including this year will be included. If NULL, no upper year boundary is applied.
#' @return A tibble with five columns: member, world_id, year, month, value
#' @importFrom dplyr filter group_by mutate summarise collect
#' @importFrom dtplyr lazy_dt
#' @export


# data <- readRDS("/Users/andreas/Library/CloudStorage/Dropbox/Projects/biodiversity_dp/data/processed/climate//DCPP_tas_CMCC-CM2-SR5_r10i1p1f1_obs-ERA5_fyear1.rds")
# sd.threshold <- 3
# year.max <- 2000

climate_limits <- function(climate.data, sd.threshold = NULL, temporal.resolution = NULL, year.min = NULL, year.max = NULL){
  
  # Input checks
  if(is.null(temporal.resolution)) stop("Provide the temporal resolution:  'yearly' or 'monthly'", call. = F)
  if(!temporal.resolution %in% c("yearly", "monthly")) stop("Temporal resolution should be 'yearly' or 'monthly'", call. = F)
  
  if(temporal.resolution == "monthly" && !"month" %in% colnames(climate.data)) {
    stop(glue("Missing 'month' column: Required when `temporal.resolution` is 'monthly'.\n",
              "Please check your input data or change the `temporal.resolution` argument."), call. = F)
  }
  
  if(temporal.resolution == "yearly" && "month" %in% colnames(climate.data)) {
    warning(glue("Temporal mismatch: `temporal.resolution` is 'yearly' but a 'month' column exists.\n",
                 "The function will return max and min monthly values"), call. = F)
  }
  
  max_year <- max(climate.data$year)
  min_year <- min(climate.data$year)
  
  if(!is.null(year.min)){
    
    if(!is.numeric(year.min)) stop("'year.min' must be numeric", call. = F)
    if(year.min < min_year || year.min > max_year) stop("'year.min' is outside the range of the data", call. = F)
  }
  
  if(!is.null(year.max)){
    
    if(!is.numeric(year.max)) stop("'year.max' must be numeric", call. = F)
    if(year.max < min_year || year.max > max_year) stop("'year.max' is outside the range of the data", call. = F)
  }
  

  if(!is.null(year.max)) climate.data <- climate.data %>% filter(year <= year.max)
  if(!is.null(year.min)) climate.data <- climate.data %>% filter(year >= year.min)
  
  
  if(temporal.resolution == "monthly"){
    
    if(!is.null(sd.threshold)){
      
      result <- climate.data %>% 
        # group_by(member, world_id, month) %>%
        group_by(world_id, month) %>%
        mutate(mean_val = mean(value, na.rm = TRUE),
               sd_val = sd(value, na.rm = TRUE),
               is_outlier = value > (mean_val + sd.threshold * sd_val) | value < (mean_val - sd.threshold * sd_val)) %>%
        filter(!is_outlier) %>%
        summarise(max_value = max(value, na.rm = TRUE),
                  min_value = min(value, na.rm = TRUE),
                  .groups = "drop") %>% 
        # arrange(member, world_id, month) 
        arrange(world_id, month)
      
      
    } else {
      
      result <- climate.data %>% 
        # group_by(member, world_id, month) %>%
        group_by(world_id, month) %>%
        summarise(max_value = max(value, na.rm = TRUE),
                  min_value = min(value, na.rm = TRUE),
                  .groups = "drop") %>% 
        # arrange(member, world_id, month) 
        arrange(world_id, month)
      
    }
  }
  
  if(temporal.resolution == "yearly"){
    
    if(!is.null(sd.threshold)){
      
      result <- climate.data %>% 
        # group_by(member, world_id, month) %>%
        group_by(world_id) %>%
        mutate(mean_val = mean(value, na.rm = TRUE),
               sd_val = sd(value, na.rm = TRUE),
               is_outlier = value > (mean_val + sd.threshold * sd_val) | value < (mean_val - sd.threshold * sd_val)) %>%
        filter(!is_outlier) %>%
        summarise(max_value = max(value, na.rm = TRUE),
                  min_value = min(value, na.rm = TRUE),
                  .groups = "drop") %>% 
        # arrange(member, world_id, month) 
        arrange(world_id)
      
      
    } else {
      
      result <- climate.data %>% 
        # group_by(member, world_id, month) %>%
        group_by(world_id) %>%
        summarise(max_value = max(value, na.rm = TRUE),
                  min_value = min(value, na.rm = TRUE),
                  .groups = "drop") %>% 
        # arrange(member, world_id, month) 
        arrange(world_id)
      
    }
  }
  
  
  return(result)
  
}

