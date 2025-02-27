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

safe_parse_opts <- function(opt_parser, args) {
  # Function to safely parse the options. Shows the help if there's an error.
  opt <- tryCatch(
    {
      opt <- parse_args(opt_parser, args = args)
      opt
    },
    error = function(e) {
      cat("Error parsing arguments:", e$message, "\n")
      parse_args(opt_parser, args = c("--help"))
      FALSE
    }
  )
  return(opt)
}


run_tif2rds <- function(args) {
  source("utility/format_conversion_util.R")
  option_list <- list(
    make_option(c("-i", "--input"),
      type = "character",
      help = "Path to the input .tif file"
    ),
    make_option(c("-o", "--output"),
      type = "character",
      help = "Path to save the output .rds file"
    ),
    make_option(c("-y", "--year_range"),
      type = "character",
      default = "1850:2014",
      help = "Year range as a sequence (e.g., '1850:2014')"
    )
  )
  opt <- safe_parse_opts(OptionParser(option_list = option_list), args[-1])
  check_not_null(opt$input, "input")
  check_not_null(opt$output, "output")

  year_range <- eval(parse(text = opt$year_range))
  print("Converting tif to rds using the following options:")
  cat("Input:", opt$input, "\n")
  cat("Output:", opt$output, "\n")
  cat("Year range:", opt$year_range, "\n")

  climate_data <- prepare_climate_data_from_tif(
    input_file = opt$input,
    output_file = opt$output,
    year_range = year_range
  )
  print("File converted successfully!")
}


run_shp2rds <- function(args) {
  source("utility/format_conversion_util.R")
  option_list <- list(
    make_option(c("-i", "--input"),
      type = "character",
      help = "The input .shp file"
    ),
    make_option(c("-o", "--output"),
      type = "character",
      help = "The output .rds file",
    ),
    make_option(c("-e", "--extent"),
      type = "character",
      help = "The extent as comma separated values (e.g -180,180,-90,90)",
      default = "-180,180,-90,90"
    ),
    make_option(c("-r", "--resolution"),
      type = "numeric",
      help = "Resolution. Default is 1.",
      default = 1
    ),
    make_option(c("-c", "--crs"),
      type = "character",
      help = "The CRS, default is EPSG:4326.",
      default = "EPSG:4326"
    ),
    make_option(c("-m", "--realm"),
      type = "character",
      help = "The realm to use for filtering. Default is all.",
      default = "all"
    ),
    make_option(c("-p", "--parallel"),
      type = "logical",
      help = "Use parallel processing. Default is TRUE.",
      default = TRUE
    ),
    make_option(c("-w", "--workers"),
      type = "numeric",
      help = "Number of workers to use. Default is availableCores()-1.",
      default = availableCores() - 1
    )
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
  cat("Realm:", opt$realm, "\n")
  cat("Parallel:", opt$parallel, "\n")
  cat("Workers:", opt$workers, "\n")

  grid <- create_grid(extent_vals = extent,
                      resolution = opt$resolution,
                      crs = opt$crs)
  range_data <- prepare_range_data_from_shp_file(input_file_path = opt$input,
                                                 grid = grid,
                                                 realm = opt$realm,
                                                 use_parallel = opt$parallel,
                                                 number_of_workers = opt$workers,
                                                 rds_output_file_path = opt$output)
  print("File converted successfully!")
}

run_climatearray2rds <- function(args) {
  source("utility/convert_array_to_raster.R")

  option_list <- list(
    make_option(c("-i", "--input"),
      type = "character",
      help = "Directory containing .rds climate array files"
    ),
    make_option(c("-o", "--output"),
      type = "character",
      help = "Directory to save processed raster .rds files"
    ),
    make_option(c("-y", "--start_year"),
      type = "integer",
      default = 1961,
      help = "Starting year for naming convention (default: 1961)"
    ),
    make_option(c("-p", "--parallel"),
      type = "logical",
      help = "Use parallel processing. Default is TRUE.",
      default = TRUE
    ),
    make_option(c("-w", "--workers"),
      type = "numeric",
      help = "Number of workers to use. Default is availableCores()-1.",
      default = availableCores()-1
    )
  )

  # Parse command-line arguments
  opt <- safe_parse_opts(OptionParser(option_list = option_list), args[-1])
  check_not_null(opt$input, "input")
  check_not_null(opt$output, "output")

  # Print the received arguments
  print("Processing climate array .rds files with the following options:")
  cat("Input Directory:", opt$input, "\n")
  cat("Output Directory:", opt$output, "\n")
  cat("Start Year:", opt$start_year, "\n")
  cat("Parallel:", opt$parallel, "\n")
  cat("Workers:", opt$workers, "\n")

  # Run the climate array processing function
  processed_raster <- process_climate_array_data(
    input_dir = opt$input,
    output_dir = opt$output,
    start_year = opt$start_year,
    use_parallel = opt$parallel,
    number_of_workers = opt$workers
  )

  print("File converted successfully!")
}

run_exposure <- function(args) {
  source("scripts/exposure_workflow.R")
  option_list <- list(
    make_option(c("-d", "--data_path"),
      type = "character",
      help = "Data path with input files"
    ),
    make_option(c("-p", "--plan_type"),
      type = "character",
      help = "The plan type to use to parallel processing. Default is multisession.",
      default = "multisession"
    ),
    make_option(c("-w", "--workers"),
      type = "numeric",
      help = "Number of workers to use (uses availableCores()-1 if not provided).",
      default = NULL
    )
  )

  opt <- safe_parse_opts(OptionParser(option_list = option_list), args[-1])
  check_not_null(opt$data_path, "data_path")

  print("Calculating exposure using the following options:")
  cat("Data path:", opt$data_path, "\n")
  cat("Plan type:", opt$plan_type, "\n")
  cat("Workers:", opt$workers, "\n")
  exposure_time_workflow(opt$data_path, opt$plan_type, opt$workers)
}

# Main function
args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0) {
  stop("No command provided. Use 'shp2rds', 'tif2rds' or 'exposure'.")
}
cmd <- args[1]
if (cmd == "shp2rds") {
  run_shp2rds(args)
} else if (cmd == "exposure") {
  run_exposure(args)
} else if (cmd == "tif2rds") {
  run_tif2rds(args)
} else if (cmd == "climatearray2rds") {
  run_climatearray2rds(args)
} else {
  stop("Invalid command. Use 'shp2rds', 'tif2rds', 'climatearray2rds' or 'exposure'.")
}
