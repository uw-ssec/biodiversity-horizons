library(optparse)
library(yaml)
library(logger)

# Initialize logger
log_threshold(INFO)

check_not_null <- function(x, name) {
  if (is.null(x)) {
    cat(sprintf("Argument '--%s' is required.", name), "\n")
    quit(status = 1)
  }
}

check_file_exists <- function(file_path) {
  if (!file.exists(file_path)) {
    cat("File does not exist:", file_path, "\n")
    quit(status = 1)
  }
}

# Function to read and process the YAML file
read_yaml_file <- function(file_path) {
  # Check if the file exists
  check_file_exists(file_path)

  # Read the YAML file
  yaml_data <- yaml.load_file(file_path)

  # Return the parsed YAML data
  return(yaml_data)
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

run_bienclimate2rds <- function(args) {
  source("utility/format_conversion_util.R")

  option_list <- list(
    make_option(c("-i", "--input"),
      type = "character",
      help = "Path to the input BIEN climate .tif file"
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

  print("Converting BIEN climate .tif to rds using the following options:")
  cat("Input:", opt$input, "\n")
  cat("Output:", opt$output, "\n")
  cat("Year range:", opt$year_range, "\n")

  bien_climate <- prepare_bien_climate_data_from_tif(
    input_file = opt$input,
    output_file = opt$output,
    year_range = year_range
  )

  print("File converted successfully!")
}

run_convertbienranges <- function(args) {
  source("utility/format_conversion_util.R")

  option_list <- list(
    make_option(c("-m", "--manifest"),
      type = "character",
      help = "Path to manifest.parquet"
    ),
    make_option(c("-o", "--output"),
      type = "character",
      help = "Directory to save processed outputs"
    ),
    make_option(c("-r", "--ranges"),
      type = "character",
      help = "Directory containing raw BIEN .tif files"
    ),
    make_option(c("-g", "--grid"),
      type = "character",
      help = "Path to saved global climate grid (.tif)"
    ),
    make_option(c("-a", "--aggregation_rule"),
      type = "character",
      default = "any",
      help = "Aggregation rule (default: 'any')"
    ),
    make_option(c("-s", "--subset"),
      type = "character",
      default = NULL,
      help = "Comma-separated subset of species to process (optional)"
    ),
    make_option(c("-p", "--parallel"),
      type = "logical",
      default = TRUE,
      help = "Use parallel processing (default: TRUE)"
    ),
    make_option(c("-w", "--workers"),
      type = "numeric",
      default = parallel::detectCores() - 1,
      help = "Number of parallel workers"
    )
  )

  opt <- safe_parse_opts(OptionParser(option_list = option_list), args[-1])

  check_not_null(opt$manifest, "manifest")
  check_not_null(opt$output, "output")
  check_not_null(opt$ranges, "ranges")
  check_not_null(opt$grid, "grid")

  species_subset <- if (!is.null(opt$subset)) strsplit(opt$subset, ",")[[1]] else NULL

  cat("Running BIEN range preprocessing with options:\n")
  cat("Manifest:", opt$manifest, "\n")
  cat("Output Directory:", opt$output, "\n")
  cat("Ranges Directory:", opt$ranges, "\n")
  cat("Climate Grid Path:", opt$grid, "\n")
  cat("Aggregation Rule:", opt$aggregation_rule, "\n")
  cat("Parallel:", opt$parallel, "\n")
  cat("Workers:", opt$workers, "\n")
  if (!is.null(species_subset)) cat("Subset of species:", paste(species_subset, collapse = ", "), "\n")

  preprocess_all_bien_species(
    manifest_path        = opt$manifest,
    processed_dir        = opt$output,
    ranges_folder        = opt$ranges,
    climate_grid_path    = opt$grid,
    aggregation_rule     = opt$aggregation_rule,
    species_subset       = species_subset,
    use_parallel         = opt$parallel,
    number_of_workers    = opt$workers
  )
}

run_exposure <- function(args) {

  source("scripts/exposure_workflow.R")

  option_list <- list(
    make_option(c("-i", "--input_yml"), type = "character", help = "Input config YAML filepath"),
    make_option("--historical_climate", type = "character", help = "Override historical climate file"),
    make_option("--future_climate", type = "character", help = "Override future climate file"),
    make_option("--species", type = "character", help = "Override species file or directory"),
    make_option("--species_type", type = "character", help = "Override species type (e.g., 'bien')"),
    make_option("--plan_type", type = "character", help = "Override parallel plan type"),
    make_option("--workers", type = "integer", help = "Override number of workers")
  )

  opt <- safe_parse_opts(OptionParser(option_list = option_list), args[-1])

  log_info("input_yml: {opt$input_yml}")
  check_not_null(opt$input_yml, "input_yml")
  config <- read_yaml_file(opt$input_yml)

  data_path <- dirname(opt$input_yml)
  check_not_null(data_path, "data_path")
  data_files <- config$data_files

  # Override with CLI values if provided
  if (!is.null(opt$historical_climate)) data_files$historical_climate <- opt$historical_climate
  if (!is.null(opt$future_climate))     data_files$future_climate     <- opt$future_climate
  if (!is.null(opt$species))            data_files$species            <- opt$species
  if (!is.null(opt$species_type))       config$species_type           <- opt$species_type
  if (!is.null(opt$plan_type))          config$plan_type              <- opt$plan_type
  if (!is.null(opt$workers))            config$workers                <- opt$workers

  # Default fallbacks
  species_type <- if (!is.null(config$species_type)) config$species_type else "shp"
  plan_type    <- if (!is.null(config$plan_type)) config$plan_type else "multisession"
  workers      <- if (!is.null(config$workers)) config$workers else (parallel::detectCores() - 1)

  # File paths
  historical_climate_file <- data_files$historical_climate
  future_climate_file     <- data_files$future_climate
  species_file            <- data_files$species
  exposure_result_file    <- config$exposure_result_file

  historical_climate_file_path <- file.path(data_path, historical_climate_file)
  future_climate_file_path     <- file.path(data_path, future_climate_file)
  species_file_path <- if (startsWith(species_file, "/")) species_file else file.path(data_path, species_file)

  check_file_exists(historical_climate_file_path)
  check_file_exists(future_climate_file_path)
  check_file_exists(species_file_path)
  check_not_null(exposure_result_file, "exposure_result_file")

  log_info("Calculating exposure using the following options:")
  log_info("Historical climate path: {historical_climate_file_path}")
  log_info("Future climate path: {future_climate_file_path}")
  log_info("Species path: {species_file_path}")
  log_info("Exposure result file: {exposure_result_file}")
  log_info("Species type: {species_type}")
  log_info("Plan type: {plan_type}")
  log_info("Workers: {workers}")

  exposure_workflow(
    historical_climate_filepath = historical_climate_file_path,
    future_climate_filepath     = future_climate_file_path,
    species_filepath            = species_file_path,
    species_type                = species_type,
    plan_type                   = plan_type,
    workers                     = workers,
    exposure_result_file        = exposure_result_file
  )
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
} else if (cmd == "bienclimate2rds") {
  run_bienclimate2rds(args)
} else if (cmd == "convert_bienranges") {
  run_convertbienranges(args)
} else {
  stop("Invalid command. Use 'shp2rds', 'tif2rds', 'climatearray2rds', 'bienclimate2rds', 'convert_bienranges' or 'exposure'.")
}
