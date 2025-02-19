library(testthat)
library(dplyr)
library(purrr)
library(sf)
library(future)
library(furrr)

# Source the utility file with filter_range_data() definition
# source("utility/format_conversion_util.R")
source("utility/format_conversion_util.R")  # Path to the utility script

# Test for filter_range_data()
test_that("filter_range_data() filters correctly based on realm", {

  # Mock data
  range_data <- data.frame(
    presence = c(1, 1, 2, 1, 1),
    origin = c(1, 2, 1, 3, 2),
    seasonal = c(1, 2, 3, 1, 2),
    terrestial = c("true", "false", "true", "true", "true"), #codespell:ignore terrestial
    marine = c("false", "true", "false", "false", "true")
  )

  # Test for terrestrial realm
  result <- filter_range_data(range_data, "terrestial") #codespell:ignore terrestial
  expect_equal(nrow(result), 2)

  # Test for marine realm
  result <- filter_range_data(range_data, "marine")
  expect_equal(nrow(result), 2)

  # Test for invalid realm
  result <- filter_range_data(range_data, "unknown")
  expect_equal(nrow(result), 3)
})


# Test for clean_results()
test_that("clean_results() cleans and combines correctly", {

  # Mock data
  res <- list(
    species1 = c(1, 2, 3),
    species2 = NULL,
    species3 = c(4, 5),
    species1 = c(6, 7)
  )

  # Test cleaning and combining
  result <- clean_results(res)
  expect_type(result, "list")
  expect_equal(names(result), c("species1", "species3"))
  expect_equal(result$species1, c(1, 2, 3, 6, 7))
  expect_equal(result$species3, c(4, 5))
})
