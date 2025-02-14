library(optparse)
library(terra)
library(future)
source("scripts/VISS_Sample_Data.R")

check_not_null <- function(x, name) {
  if (is.null(x)) {
    cat(sprintf("Argument '--%s' is required.", name), "\n")
    quit(status = 1)
  }
}

parse_extent <- function(extent) {
  extent <- strsplit(extent, ",")[[1]]
  if (length(extent) != 4) {
    stop("Extent must be a comma separated string with 4 values.")
  }
  extent <- as.numeric(extent)
  return(ext(extent))
}  
# sprintf("ex: %s", parse_extent("-180,180,-90,90"))

run_shp2rds <- function(args) {
  option_list <- list(
    make_option(c("-i", "--input"), type = "character",
                help = "The input .shp file"),
    make_option(c("-o", "--output"), type = "character",
                help = "The output .rds file",),    
    make_option(c("-e", "--extent"), type = "character",
                help = "The extent as comma separated values, e.g. -180,180,-90,90)",
               default = "-180,180,-90,90"),
    make_option(c("-r", "--resolution"), type = "numeric",
                help = "Resolution",
               default = 1),
    make_option(c("-c", "--crs"), type = "character",
                help = "The CRS",
               default = "EPSG:4326")
  )

  opt_parser <- OptionParser(option_list = option_list)
  opt <- parse_args(opt_parser, args = args[-1])
  check_not_null(opt$input, "input")
  check_not_null(opt$output, "output")

  extent <- parse_extent(opt$extent)
  
  # Access the arguments
  print("Converting shapefile to rds using the following options:")
  cat("Input:", opt$input, "\n")
  cat("Output:", opt$output, "\n")
  cat("Extent:", sprintf("%s", extent), "\n")
  cat("Resolution:", opt$resolution, "\n")
  cat("CRS:", opt$crs, "\n")

  # TODO Ishika/Anuj: call the function to convert the shapefile to rds
}


run_exposure <- function(args) {
  option_list <- list(
    make_option(c("-d", "--data_path"), type = "character",
                help = "Data path with input files"),
    make_option(c("-p", "--plan_type"), type = "character",
                help = "The plan type to use to parallel processing",
                default = "multisession"),    
    make_option(c("-w", "--workers"), type = "numeric",
                help = "Number of workers to use (uses availableCores()-1 if not provided)",
               default = NULL)
  )  
  
  opt_parser <- OptionParser(option_list = option_list)
  opt <- parse_args(opt_parser, args = args[-1])
  check_not_null(opt$data_path, "data_path")  

  print("Calculating exposure using the following options:")
  cat("Data path:", opt$data_path, "\n")
  cat("Plan type:", opt$plan_type, "\n")
  cat("Workers:", opt$workers, "\n")
  exposure_time_workflow(opt$data_path, opt$plan_type, opt$workers)
}

args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0) {
  stop("No command provided. Use 'shp2rds', 'tiff2rds' or 'exposure'.")
}
cmd = args[1]
if (cmd == "shp2rds") {
  run_shp2rds(args)
} else if (cmd == "exposure") {
  run_exposure(args)
} else {
  stop("Invalid command. Use 'shp2rds', 'tiff2rds' or 'exposure'.")
}
