#' Calculate species exposure to climate changes
#'
#' @param species.names Vector with the name of the species
#' @param species.data List of grid cell IDs for each species
#' @param climate.data Data frame of climate data by grid cell
#' @param niche.data Niche limits for each species
#' @param mode Either 'monthly' or 'extreme'. If 'monthly', the function calculates month-specific exposure. If 'extreme', it will calculate exposure based on the highest monthly value.
#' @param return.magnitude If TRUE, the function returns the numeric difference by which the thermal threshold was exceeded. If FALSE, it returns a binary output: 1 for exposure, 0 otherwise
#' @return A data frame with exposure data
#' @importFrom dplyr group_by summarise
#' @export
#' 



exposure <- function(species.names, species.data, climate.data, niche.data, mode = NULL, return.magnitude = TRUE, long.format = FALSE){
  
  if("month" %in% names(climate.data) != "month" %in% names(niche.data)) stop("`month` present only in one dataset.", call. = FALSE)
  if("month" %in% names(climate.data) && is.null(mode)) stop("`month` column detected. Set `mode` argument.", call. = FALSE)
  if(!(mode %in% c("extreme", "monthly"))) stop("Invalid 'mode' argument. Please use either 'extreme' or 'monthly'.", call. = FALSE)
  
  spp_world_id <- species.data[[species.names]]
  spp_matrix <- climate.data[climate.data$world_id %in% spp_world_id,] %>% na.omit()
  spp_niche <- niche.data[niche.data$species == species.names,]
  
  if(nrow(spp_niche) == 0) return(NULL)
  
  # If the temporal resolution of the climate data is monthly
  if("month" %in% names(climate.data)) {
    
    # if the analyses should be month-specific
    if(mode == "monthly") {
      
      merged <- merge(spp_matrix, spp_niche, by = "month")
      
      merged$exposure_max <- as.integer(pmax(merged$value - merged$niche_max, 0))
      merged$exposure_min <- as.integer(pmin(merged$value - merged$niche_min, 0))
      merged$species <- factor(species.names)
      
      if(!return.magnitude) {
        
        merged$exposure_max <- ifelse(merged$exposure_max == 0, 0L, 1L)
        merged$exposure_min <- ifelse(merged$exposure_min == 0, 0L, 1L)
        
      }
      
      result <- merged[, c("species", "world_id", "year", "month", "exposure_max", "exposure_min")] 
      
      return(result)
      
    } 
    
    if(mode == "extreme") {
      
      niche <- spp_niche %>% 
        summarise(niche_max = max(niche_max),
                  niche_min = min(niche_min))
      
      merged <- merge(spp_matrix, niche)
      
      merged$exposure_max <- as.integer(pmax(merged$value - merged$niche_max, 0))
      merged$exposure_min <- as.integer(pmin(merged$value - merged$niche_min, 0))
      merged$species <- factor(species.names)
      
      if(!return.magnitude) {
        
        merged$exposure_max <- ifelse(merged$exposure_max == 0, 0L, 1L)
        merged$exposure_min <- ifelse(merged$exposure_min == 0, 0L, 1L)
        
      }
      
      result <- merged[, c("species", "world_id", "year", "month", "exposure_max", "exposure_min")] 
      
      return(result)
      
    }
    
  } else {
    
    warning("`month` column not present. Ignoring `mode` argument.", call. = FALSE)
    
    niche <- spp_niche %>% 
      summarise(niche_max = max(niche_max),
                niche_min = min(niche_min))
    
    merged <- merge(spp_matrix, niche)
    
    merged$exposure_max <- as.integer(pmax(merged$value - merged$niche_max, 0))
    merged$exposure_min <- as.integer(pmin(merged$value - merged$niche_min, 0))
    merged$species <- factor(species.names)
    
    if(!return.magnitude) {
      
      merged$exposure_max <- ifelse(merged$exposure_max == 0, 0L, 1L)
      merged$exposure_min <- ifelse(merged$exposure_min == 0, 0L, 1L)
      
    }
    
    result <- merged[, c("species", "world_id", "year", "exposure_max", "exposure_min")] 
    
    if(long.format) {
      
      result <- result %>% 
        select(-exposure_min) %>%
        pivot_wider(values_from = exposure_max, 
        names_from = year) 
      
    }
    
    return(result)
    
  }
    
  
}
