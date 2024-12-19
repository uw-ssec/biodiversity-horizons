check_parallelization <- function() {
  # Check the number of physical cores
  num_cores <- parallel::detectCores(logical = FALSE)  # Use physical cores only
  
  # If there are fewer than 2 physical cores, parallelization is not possible
  if (num_cores < 2) {
    return(FALSE)
  }
  
  # Check if multicore parallelization is supported using parallelly package
  # This accounts for the platform and RStudio environment
  if (!parallelly::supportsMulticore()) {
    return(FALSE)
  }
  
  # If the system has multiple cores and supports multicore parallelization, return TRUE
  return(TRUE)
}

# Example usage:
check_parallelization()