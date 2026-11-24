day_rulers <- c("Sun", "Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn")
chaldean_order <- c("Saturn", "Jupiter", "Mars", "Sun", "Venus", "Mercury", "Moon")

.check_location <- function(timezone, latitude, longitude) {
  if (!is.character(timezone) || length(timezone) != 1L ||
      is.na(timezone) || !timezone %in% OlsonNames()) {
    stop("Use a valid time zone, e.g. America/New_York or Africa/Nairobi.")
  }
  if (!is.numeric(latitude) || length(latitude) != 1L ||
      !is.finite(latitude) || abs(latitude) > 90) {
    stop("latitude must be one number between -90 and 90.")
  }
  if (!is.numeric(longitude) || length(longitude) != 1L ||
      !is.finite(longitude) || abs(longitude) > 180) {
    stop("longitude must be one number between -180 and 180.")
  }
  if (!requireNamespace("suncalc", quietly = TRUE)) {
    stop('Install suncalc first: install.packages("suncalc")')
  }
}

# Query neighboring dates, then select by LOCAL date. This matters near the
# international date line, where a sunrise's UTC date can differ from its local date.
.solar_events <- function(date, timezone, latitude, longitude) {
  candidates <- suncalc::getSunlightTimes(
    date = seq(date - 2, date + 2, by = "day"),
    lat = latitude, lon = longitude,
    keep = c("sunrise", "sunset"), tz = timezone
  )
  rise_dates <- as.Date(candidates$sunrise, tz = timezone)
  today <- which(!is.na(rise_dates) & rise_dates == date)
  tomorrow <- which(!is.na(rise_dates) & rise_dates == date + 1)
  if (length(today) != 1L || length(tomorrow) != 1L) {
    stop("Cannot calculate hours: sunrise is missing or not unique for ",
         date, " or the next local date. Check location and polar conditions.")
  }
  sunrise <- candidates$sunrise[today]
  next_sunrise <- candidates$sunrise[tomorrow]
  sets <- which(!is.na(candidates$sunset) &
                  candidates$sunset > sunrise & candidates$sunset < next_sunrise)
  if (length(sets) != 1L) {
    stop("Cannot calculate hours: no unique sunset between consecutive sunrises.")
  }
  list(sunrise = sunrise, sunset = candidates$sunset[sets],
       next_sunrise = next_sunrise)
}

# Internal calculator separated from astronomy so boundaries can be tested.
.make_schedule <- function(date, timezone, sunrise, sunset, next_sunrise) {
  points <- as.numeric(c(sunrise, sunset, next_sunrise))
  if (any(!is.finite(points)) || any(diff(points) <= 0)) {
    stop("Solar events must be finite and ordered: sunrise < sunset < next sunrise.")
  }
  # Twelve equal parts of daylight and twelve equal parts of darkness.
  bounds <- c(seq(points[1], points[2], length.out = 13),
              seq(points[2], points[3], length.out = 13)[-1])
  weekday <- as.POSIXlt(as.Date(date), tz = "UTC")$wday + 1L
  day_ruler <- day_rulers[weekday]
  first <- match(day_ruler, chaldean_order)
  rulers <- chaldean_order[((first - 1L + 0:23) %% 7L) + 1L]
  data.frame(
    planetary_date = rep(as.Date(date), 24),
    day_ruler = rep(day_ruler, 24),
    planetary_hour = 1:24,
    period = rep(c("Day", "Night"), each = 12),
    hour_ruler = rulers,
    hour_start = as.POSIXct(bounds[1:24], origin = "1970-01-01", tz = timezone),
    hour_end = as.POSIXct(bounds[2:25], origin = "1970-01-01", tz = timezone),
    duration_minutes = diff(bounds) / 60,
    stringsAsFactors = FALSE
  )
}

#' Generate a planetary day's 24 intervals
#'
#' Divide sunrise to sunset and sunset to the following sunrise into twelve
#' equal elapsed-time intervals each. Solar events come from `suncalc`.
#' @param date One `Date` or a date string in `YYYY-MM-DD` format, interpreted
#'   as a calendar date at the target location.
#' @param timezone One IANA time zone name, such as `Africa/Nairobi`.
#' @param latitude One finite latitude in degrees, between -90 and 90.
#' @param longitude One finite longitude in degrees, between -180 and 180;
#'   east is positive.
#' @return A 24-row data frame with `planetary_date` (`Date`), `day_ruler`,
#'   `planetary_hour` (1 to 24), `period` (`Day` or `Night`), `hour_ruler`,
#'   `hour_start` and `hour_end` (`POSIXct` in `timezone`), and
#'   `duration_minutes` (elapsed minutes).
#' @details Intervals include their start and exclude their end. The first
#'   hour's ruler is the weekday ruler; subsequent rulers follow Saturn,
#'   Jupiter, Mars, Sun, Venus, Mercury, Moon. A planetary day starts at sunrise.
#'   Durations use elapsed seconds, including across daylight-saving changes.
#'   An error is raised if consecutive sunrises or the intervening sunset are
#'   unavailable or not unique (for example, during polar day or night).
#'   Solar times are approximate, assume an unobstructed horizon, and do not
#'   account for local weather or terrain. No universal accuracy is guaranteed.
#' @examples
#' schedule <- planetary_schedule("2026-10-08", "Africa/Nairobi", -1.2921, 36.8219)
#' head(schedule)
#' @seealso [planetary_hours()], [add_planetary_info()]
#' @export
planetary_schedule <- function(date, timezone, latitude, longitude) {
  .check_location(timezone, latitude, longitude)
  if (length(date) != 1L || is.na(date) ||
      !(inherits(date, "Date") || is.character(date))) {
    stop("Supply one valid date: YYYY-MM-DD.")
  }
  if (is.character(date)) {
    parsed <- suppressWarnings(as.Date(date, format = "%Y-%m-%d"))
    if (is.na(parsed) || format(parsed, "%Y-%m-%d") != date) {
      stop("Supply one valid date: YYYY-MM-DD.")
    }
    date <- parsed
  }
  if (!is.finite(as.numeric(date))) stop("Supply one valid date: YYYY-MM-DD.")
  solar <- .solar_events(date, timezone, latitude, longitude)
  .make_schedule(date, timezone, solar$sunrise, solar$sunset, solar$next_sunrise)
}

.parse_timestamp <- function(timestamp, source_timezone) {
  # POSIXct already describes an instant. Never reinterpret its clock reading.
  if (inherits(timestamp, "POSIXt")) return(as.POSIXct(timestamp))
  if (is.na(timestamp)) return(as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC"))
  if (!is.character(timestamp)) stop("Use timestamp text or a POSIXct object.")
  if (!requireNamespace("clock", quietly = TRUE)) {
    stop('Install clock first: install.packages("clock")')
  }
  timestamp <- trimws(timestamp)
  if (grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}$", timestamp)) {
    timestamp <- paste0(timestamp, ":00")
  }
  if (!grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$", timestamp)) {
    stop("Use YYYY-MM-DD HH:MM:SS, or pass an already parsed POSIXct object.")
  }
  value <- suppressWarnings(clock::date_time_parse(
    timestamp, zone = source_timezone, format = "%Y-%m-%d %H:%M:%S",
    nonexistent = "error", ambiguous = "error"
  ))
  if (is.na(value)) stop("Invalid timestamp: ", timestamp)
  value
}

#' Classify timestamps by planetary day and hour
#'
#' Find the sunrise-based planetary date and interval for each timestamp at
#' one geographic location. Before sunrise, the previous planetary day applies.
#' @param timestamp A nonempty vector of local timestamp strings in
#'   `YYYY-MM-DD HH:MM[:SS]` format, or `POSIXct`/`POSIXlt` instants.
#'   With `time`, supply dates instead. Missing timestamps produce missing rows.
#' @param time Optional clock strings in `HH:MM[:SS]` format, of length one
#'   or the same length as `timestamp`.
#' @inheritParams planetary_schedule
#' @param source_timezone IANA zone for input strings, defaulting to `timezone`.
#'   Already parsed `POSIXt` values retain their instants, regardless of this zone.
#' @param on_error `"stop"` to stop on an invalid timestamp or unavailable solar
#'   events; `"NA"` to return a missing result with the error in `status`.
#'   Invalid shared location or zone arguments always raise an error.
#' @return A data frame with one row per timestamp, in input order. Columns are
#'   `timestamp_utc` (`POSIXct`), `local_time` (formatted text with zone
#'   abbreviation), `timezone`, the eight schedule columns described in
#'   [planetary_schedule()], and `status` (`"OK"`, `"Missing timestamp"`, or an
#'   error message). Failed rows have missing result fields except `timezone`
#'   and `status`.
#' @details Intervals are start-inclusive and end-exclusive. Exact sunset begins
#'   hour 13; exact sunrise begins hour 1 of the new planetary day. Ambiguous
#'   fall-back and nonexistent spring-forward clock strings are rejected;
#'   pass a `POSIXct` instant to distinguish repeated clock times. Leap seconds
#'   are not supported. Solar-model limitations are described in
#'   [planetary_schedule()].
#' @examples
#' planetary_hours(c("2026-10-08 14:30:00", NA), timezone = "Africa/Nairobi",
#'                 latitude = -1.2921, longitude = 36.8219)
#' planetary_hours("2026-10-08", time = "14:30", timezone = "Africa/Nairobi",
#'                 latitude = -1.2921, longitude = 36.8219)
#' @seealso [planetary_schedule()], [add_planetary_info()]
#' @export
planetary_hours <- function(timestamp, time = NULL, timezone,
                            latitude, longitude, source_timezone = timezone,
                            on_error = c("stop", "NA")) {
  .check_location(timezone, latitude, longitude)
  on_error <- match.arg(on_error)
  if (!is.character(source_timezone) || length(source_timezone) != 1L ||
      is.na(source_timezone) || !source_timezone %in% OlsonNames()) {
    stop("source_timezone must be a valid time zone name.")
  }
  if (!is.null(time)) {
    if (length(time) != 1L && length(time) != length(timestamp)) {
      stop("time must have length one or the same length as timestamp.")
    }
    dates <- as.character(timestamp)
    missing <- is.na(timestamp) | is.na(rep(time, length.out = length(timestamp)))
    timestamp <- paste(dates, time)
    timestamp[missing] <- NA_character_
  }
  if (!length(timestamp)) stop("Supply at least one timestamp.")
  cache <- new.env(parent = emptyenv())
  get_schedule <- function(date) {
    key <- as.character(date)
    if (!exists(key, envir = cache, inherits = FALSE)) {
      assign(key, planetary_schedule(date, timezone, latitude, longitude), envir = cache)
    }
    get(key, envir = cache, inherits = FALSE)
  }
  blank <- function(status) {
    data.frame(
      timestamp_utc = as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC"),
      local_time = NA_character_, timezone = timezone,
      planetary_date = as.Date(NA_character_), day_ruler = NA_character_,
      hour_ruler = NA_character_, planetary_hour = NA_integer_, period = NA_character_,
      hour_start = as.POSIXct(NA_real_, origin = "1970-01-01", tz = timezone),
      hour_end = as.POSIXct(NA_real_, origin = "1970-01-01", tz = timezone),
      duration_minutes = NA_real_, status = status, stringsAsFactors = FALSE
    )
  }
  rows <- lapply(seq_along(timestamp), function(i) {
    tryCatch({
      instant <- .parse_timestamp(timestamp[i], source_timezone)
      if (is.na(instant)) return(blank("Missing timestamp"))
      local_date <- as.Date(instant, tz = timezone)
      schedule <- get_schedule(local_date)
      # Before today's sunrise, the previous planetary day is still in effect.
      if (instant < schedule$hour_start[1]) schedule <- get_schedule(local_date - 1)
      hour <- which(instant >= schedule$hour_start & instant < schedule$hour_end)
      if (length(hour) != 1L) stop("Timestamp is outside the calculated solar intervals.")
      chosen <- schedule[hour, ]
      result <- blank("OK")
      result$timestamp_utc <- as.POSIXct(as.numeric(instant), origin = "1970-01-01", tz = "UTC")
      result$local_time <- format(instant, "%Y-%m-%d %H:%M:%S %Z", tz = timezone)
      result[names(chosen)] <- chosen
      result
    }, error = function(e) {
      if (on_error == "stop") stop("Timestamp ", i, ": ", conditionMessage(e), call. = FALSE)
      blank(conditionMessage(e))
    })
  })
  result <- do.call(rbind, rows)
  rownames(result) <- NULL
  result
}

#' Add planetary classifications to a dataset
#'
#' Append planetary information to every row of a data frame at one location.
#' Original columns and row order are retained.
#' @param data A nonempty data frame.
#' @param timestamp_column Name of the existing timestamp column. Its values
#'   must follow the `timestamp` contract in [planetary_hours()].
#' @inheritParams planetary_hours
#' @return The input data frame with all columns from [planetary_hours()]
#'   appended. Existing names must not collide with any output column name.
#' @details Unlike [planetary_hours()], the default `on_error = "NA"` retains
#'   invalid rows and records the reason in `status`. Shared argument errors
#'   still stop the call. For multiple locations, call separately for each group.
#' @examples
#' observations <- data.frame(recorded_at = c("2026-10-08 14:30:00", NA),
#'                            value = c(10, 12))
#' add_planetary_info(observations, "recorded_at", "Africa/Nairobi", -1.2921, 36.8219)
#' @seealso [planetary_hours()], [planetary_schedule()]
#' @export
add_planetary_info <- function(data, timestamp_column, timezone,
                               latitude, longitude, source_timezone = timezone,
                               on_error = "NA") {
  if (!is.data.frame(data)) stop("data must be a data frame.")
  if (!is.character(timestamp_column) || length(timestamp_column) != 1L ||
      is.na(timestamp_column) ||
      !timestamp_column %in% names(data)) stop("Choose an existing timestamp column.")
  if (!nrow(data)) stop("The data frame has no rows.")
  info <- planetary_hours(data[[timestamp_column]], timezone = timezone,
                          latitude = latitude, longitude = longitude,
                          source_timezone = source_timezone, on_error = on_error)
  if (any(names(info) %in% names(data))) {
    stop("Output column names already exist in data. Rename them before adding planetary info.")
  }
  cbind(data, info)
}
