# Load processed BIEN data
bien_data <- readRDS("~/Desktop/home/bsc23001/projects/bien_ranges/processed/Aa mathewsii_processed.rds")
str(bien_data)
print(head(bien_data))

# Load the climate grid (master grid)
climate_grid <- rast("data-raw/global_grid.tif")
print(ext(climate_grid))
print(res(climate_grid))
print(crs(climate_grid))

historical_climate_df <- readRDS("data-raw/historical_climate_data_new.rds")
future_climate_df <- readRDS("data-raw/future_climate_data_new.rds")
print(class(historical_climate_df))
# print(head(historical_climate_df))
world_id_range_hist <- range(historical_climate_df$world_id, na.rm = TRUE)
world_id_range_future <- range(future_climate_df$world_id, na.rm = TRUE)

print(paste("BIEN world_id range:", paste(range(bien_data$world_id, na.rm = TRUE), collapse = " to ")))
print(paste("Climate grid world_id range:", paste(range(values(climate_grid), na.rm = TRUE), collapse = " to ")))
print(paste("Historical climate world_id range:", paste(world_id_range_hist, collapse = " to ")))
print(paste("Future climate world_id range:", paste(world_id_range_future, collapse = " to ")))



# Plot the climate grid and overlay BIEN presence points
plot(climate_grid, main = "BIEN Presence Points on Climate Grid")
points(bien_data$x, bien_data$y, col = "red", pch = 16)
