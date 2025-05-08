#' Remove outliers from the climate data
#'
#' @param data Climate output from array_to_tibble function
#' @param sd.threshold Number of standard deviations used to define outliers
#' @param year.min Minimum year threshold for filtering climate data. When specified, only data from this year onward will be included (inclusive). If NULL, no lower year boundary is applied.
#' @param year.max Maximum year threshold for filtering climate data. When specified, only data up to and including this year will be included. If NULL, no upper year boundary is applied.
#' @return A tibble with five columns: member, world_id, year, month, temp
#' @importFrom dplyr filter group_by mutate summarise collect
#' @importFrom dtplyr lazy_dt
#' @export


remove_outliers <- function(data, sd.threshold, year.min = NULL, year.max = NULL){
  

  if(!is.null(year.max)) data <- data %>% filter(year <= year.max)
  if(!is.null(year.min)) data <- data %>% filter(year >= year.min)

  
  result <- data %>% 
  lazy_dt() %>%
    group_by(member, world_id, month) %>%
    mutate(mean_val = mean(temp, na.rm = TRUE),
           sd_val = sd(temp, na.rm = TRUE),
           is_outlier = temp > (mean_val + sd.threshold * sd_val) | temp < (mean_val - sd.threshold * sd_val)) %>%
    filter(!is_outlier) %>%
    summarise(max_temp = max(temp, na.rm = TRUE),
              min_temp = min(temp, na.rm = TRUE),
              .groups = "drop") %>% 
    collect()
  
  return(result)
  
}

