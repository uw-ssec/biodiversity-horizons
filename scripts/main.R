library(optparse)

check_not_null <- function(x, name) {
  if (is.null(x)) {
    cat(sprintf("Argument '--%s' is required.", name), "\n")
    quit(status = 1)
  }
}

parse_extent <- function(extent) {
  library(terra)
  extent <- strsplit(extent, ",")[[1]]
  if (length(extent) != 4) {
    stop("Extent must be a comma separated string with 4 values.")
  }
  extent <- as.numeric(extent)
  return(ext(extent))
}  

run_shp2rds <- function(args) {
  option_list <- list(
    make_option(c("-i", "--input"), type = "character",
                help = "The input .shp file"),
    make_option(c("-o", "--output"), type = "character",
                help = "The output .rds file",),    
    make_option(c("-e", "--extent"), type = "character",
                help = "The extent as comma separated values. Default is -180,180,-90,90.",
               default = "-180,180,-90,90"),
    make_option(c("-r", "--resolution"), type = "numeric",
                help = "Resolution. Default is 1.",
               default = 1),
    make_option(c("-c", "--crs"), type = "character",
                help = "The CRS, default is EPSG:4326.",
               default = "EPSG:4326")
  )

  opt <- safe_parse_opts(OptionParser(option_list = option_list), args[-1])  
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

safe_parse_opts <- function(opt_parser, args) {
  # Function to safely parse the options. Shows the help if there's an error.
  opt <- tryCatch({
    opt <- parse_args(opt_parser, args = args)
    opt
  }, error = function(e) {
    cat("Error parsing arguments:", e$message, "\n")
    opt <- parse_args(opt_parser, args=c("--help"))
    FALSE
  })
  return(opt)
}

run_exposure <- function(args) {
  source("scripts/exposure_workflow.R")
  option_list <- list(
    make_option(c("-d", "--data_path"), type = "character",
                help = "Data path with input files"),
    make_option(c("-p", "--plan_type"), type = "character",
                help = "The plan type to use to parallel processing. Default is multisession.",
                default = "multisession"),    
    make_option(c("-w", "--workers"), type = "numeric",
                help = "Number of workers to use (uses availableCores()-1 if not provided).",
               default = NULL)
  )  
  
  opt <- safe_parse_opts(OptionParser(option_list = option_list), args[-1])  
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
