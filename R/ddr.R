if (getRversion() >= "2.15.1") {
  utils::globalVariables(c("DDR_ASSET_CLASSES"))
}

DDR_ASSET_CLASSES <- c("CR" = "CREDITS", 'EQ' = "EQUITIES", 'FX' = "FOREX",
  'IR' = "RATES", 'CO' = "COMMODITIES")

ddr_file_name <- function (date, asset_class) {
  paste0(paste("CUMULATIVE", DDR_ASSET_CLASSES[asset_class], format(date, "%Y"),
    format(date, "%m"), format(date, "%d"), sep="_"))
}

ddr_url <- function (date, asset_class) {
  assertthat::assert_that(assertthat::has_name(DDR_ASSET_CLASSES, asset_class))
  stump <- "https://kgc0418-tdw-data-0.s3.amazonaws.com/slices/"
  # "https://kgc0418-tdw-data-0.s3.amazonaws.com/slices/CUMULATIVE_CREDITS_2015_04_29.zip"
  paste0(stump, ddr_file_name(date, asset_class), ".zip")
}

download_ddr_zip <- function (date, asset_class) {
  zip_url <- ddr_url(date, asset_class)
  message('Downloading DDR zip file for ', DDR_ASSET_CLASSES[asset_class],
    ' on ', date, '...')
  tmpfile_pattern <- ddr_file_name(date, asset_class)
  tmpdir <- file.path(tempdir(), "ddr")
  if (!dir.exists(tmpdir)) dir.create(tmpdir, recursive = TRUE)
  tmpfile <- tempfile(tmpfile_pattern, tmpdir, fileext = ".zip")
  # Need to use libcurl for https access
  download.file(url = zip_url, destfile = tmpfile, method = "libcurl")
  message("Unzipping DDR file ...")
  # Create date/asset_class dir as CSV file name in zip does not reflect date.
  # This makes it harder to ensure read_ddr_file picks up the right file.
  tmpdir <- file.path(tmpdir, date, "/", asset_class, '/')
  unzip(tmpfile, exdir = tmpdir)
  message('Deleting the zip file ...')
  unlink(tmpfile)
}

read_ddr_file <- function (date, asset_class) {
  message('Reading DDR data for ', format(date, '%d-%b-%Y'), '...')
  tmpdir <- file.path(tempdir(), 'ddr/', date, "/", asset_class, '/')
  ddrfile <- list.files(tmpdir, DDR_ASSET_CLASSES[asset_class], full.names = TRUE)
  if (length(ddrfile) < 1L) {
    return(dplyr::data_frame())
  } else {
    # Should only have one file per day. Use first if multiple matches
    # Use col_types() to specify each colum type as the first 100 rows may
    # not contain valid values. Reviewing col names for different asset classes
    # at 30 Apr 2014 indicates they all have same names. So specify col types
    # explicitly
    col_types <- list(
      DISSEMINATION_ID = readr::col_integer(),
      ORIGINAL_DISSEMINATION_ID = readr::col_integer(),
      ACTION = readr::col_character(),
      EXECUTION_TIMESTAMP = readr::col_datetime(),
      CLEARED = readr::col_character(),
      INDICATION_OF_COLLATERALIZATION = readr::col_character(),
      INDICATION_OF_END_USER_EXCEPTION = readr::col_character(),
      INDICATION_OF_OTHER_PRICE_AFFECTING_TERM = readr::col_character(),
      "BLOCK_TRADES_AND_LARGE_NOTIONAL_OFF-FACILITY_SWAPS" = readr::col_character(),
      EXECUTION_VENUE = readr::col_character(),
      EFFECTIVE_DATE = readr::col_date(),
      END_DATE = readr::col_date(),
      DAY_COUNT_CONVENTION = readr::col_character(),
      SETTLEMENT_CURRENCY = readr::col_character(),
      ASSET_CLASS = readr::col_character(),
      "SUB-ASSET_CLASS_FOR_OTHER_COMMODITY" = readr::col_character(),
      TAXONOMY = readr::col_character(),
      PRICE_FORMING_CONTINUATION_DATA = readr::col_character(),
      UNDERLYING_ASSET_1 = readr::col_character(),
      UNDERLYING_ASSET_2 = readr::col_character(),
      PRICE_NOTATION_TYPE = readr::col_character(),
      PRICE_NOTATION = readr::col_numeric(),
      ADDITIONAL_PRICE_NOTATION_TYPE = readr::col_character(),
      ADDITIONAL_PRICE_NOTATION = readr::col_numeric(),
      NOTIONAL_CURRENCY_1 = readr::col_character(),
      NOTIONAL_CURRENCY_2 = readr::col_character(),
      ROUNDED_NOTIONAL_AMOUNT_1 = readr::col_numeric(),
      ROUNDED_NOTIONAL_AMOUNT_2 = readr::col_numeric(),
      PAYMENT_FREQUENCY_1 = readr::col_character(),
      PAYMENT_FREQUENCY_2 = readr::col_character(),
      RESET_FREQUENCY_1 = readr::col_character(),
      RESET_FREQUENCY_2 = readr::col_character(),
      EMBEDED_OPTION = readr::col_character(),
      OPTION_STRIKE_PRICE = readr::col_numeric(),
      OPTION_TYPE = readr::col_character(),
      OPTION_FAMILY = readr::col_character(),
      OPTION_CURRENCY = readr::col_character(),
      OPTION_PREMIUM = readr::col_numeric(),
      OPTION_LOCK_PERIOD = readr::col_date(),
      OPTION_EXPIRATION_DATE = readr::col_date(),
      PRICE_NOTATION2_TYPE = readr::col_character(),
      PRICE_NOTATION2 = readr::col_numeric(),
      PRICE_NOTATION3_TYPE = readr::col_character(),
      PRICE_NOTATION3 = readr::col_numeric())
    return(readr::read_csv(ddrfile[1], col_types = col_types))
  }
}

clean_ddr_files <- function () {
  message('Deleting the DDR temp directories...')
  unlink(file.path(tempdir(), 'ddr'))
}


#' Get DDR data
#'
#' The DTCC Data Repository is a registered U.S. swap data repository that allows
#' market participants to fulfil their public disclosure obligations under
#' U.S. legislation. This function will give you the ability to download
#' trade-level data that is reported by market participants. The field names
#' are (and is assumed to be) the same for each asset class.
#'
#' @param date the date for which data is required as Date or DateTime
#' object. Only the year, month and day elements of the object are used.
#' @param asset_class the asset class for which you would like to download
#' trade data. Valid inputs are \code{"CR"} (credit), \code{"IR"} (rates),
#' \code{"EQ"} (equities), \code{"FX"} (foreign exchange), \code{"CO"}
#' (commodities).
#' @param clean where or not to clean up temporary files that are created
#' during this process. Defaults to \code{TRUE}.
#' @return a \code{tbl_df} that contains the requested data.
#' @examples
#' library("lubridate")
#' get_ddr_data(ymd(20140430), "IR")
#' @references
#' \href{https://rtdata.dtcc.com/gtr/}{DDR Real Time Dissemination Platform}
#' @export

get_ddr_data <- function (date, asset_class, clean = TRUE) {
  download_ddr_zip(date, asset_class)
  on.exit(if (clean) clean_icap_files())
  read_ddr_file(date, asset_class)
}