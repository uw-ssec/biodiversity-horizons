#' Calculate species exposure to climate changes
#'
#' @param species.names Vector with the name of the species
#' @param species.data List of grid cell IDs for each species
#' @param climate.data Data frame of climate data by grid cell
#' @param niche.data Niche limits for each species
#' @param monthly If TRUE, the function will calculate monthly exposure. If FALSE, it will calculate extreme exposure
#' @return A data frame with exposure data
#' @importFrom dplyr group_by summarise
#' @export
#' 

exposure_fast <- function(species.names, species.data, climate.data, niche.data, monthly = TRUE){
  
  spp_world_id <- species.data[[species.names]]
  spp_matrix <- climate.data[climate.data$world_id %in% spp_world_id,] %>% na.omit()
  spp_niche <- niche.data[niche.data$species == species.names,]
  
  
  if(monthly){
    
    merged <- merge(spp_matrix, spp_niche, by = c("member", "month"))
    
    merged$exposure_max <- as.integer(pmax(merged$temp - merged$niche_max, 0))
    merged$exposure_min <- as.integer(pmin(merged$temp - merged$niche_min, 0))
    merged$species <- factor(species.names)
    result <- merged[, c("species", "world_id", "year", "month", "exposure_max", "exposure_min", "member")] 
    
    return(result)
    
  } else {
    
    niche <- spp_niche %>% 
      group_by(member) %>% 
      summarise(niche_max = max(niche_max),
                niche_min = min(niche_min))
    
    merged <- merge(spp_matrix, niche, by = "member")
    
    merged$exposure_max <- as.integer(pmax(merged$temp - merged$niche_max, 0))
    merged$exposure_min <- as.integer(pmin(merged$temp - merged$niche_min, 0))
    merged$species <- factor(species.names)
    result <- merged[, c("species", "world_id", "year", "month", "exposure_max", "exposure_min", "member")] 
    
    return(result)

    
  }
}
