# PlanetaryTime

Calculate traditional planetary day and hour rulers for timestamps at a
specified location. Daylight and nighttime each have twelve equal intervals;
these are usually **not** sixty-minute clock hours.

## Installation

```r
install.packages("remotes")
remotes::install_github("Killian-Williams/Planetary-Time")
library(PlanetaryTime)
```

For this local checkout, use `install.packages("path/to/Planetary-Time-improvements",
repos = NULL, type = "source")` after installing `clock` and `suncalc`.
The package name is **PlanetaryTime**, replacing the earlier misspellings
`PlanteryTime` and `PlantaryTime`. The repository name remains `Planetary-Time`.

## Classify timestamps

```r
library(PlanetaryTime)
result <- planetary_hours(
  "2026-10-08 14:30:00",
  timezone = "Africa/Nairobi", latitude = -1.2921, longitude = 36.8219
)
result[c("planetary_date", "day_ruler", "hour_ruler", "planetary_hour", "status")]
#   planetary_date day_ruler hour_ruler planetary_hour status
# 1     2026-10-08   Jupiter       Mars              9     OK
```

The full result is a data frame, one row per timestamp. It includes
`timestamp_utc`, `local_time`, `timezone`, `planetary_date`, `day_ruler`,
`hour_ruler`, `planetary_hour`, `period`, `hour_start`, `hour_end`,
`duration_minutes`, and `status`. Timestamp and interval columns are `POSIXct`;
`local_time` is display text. See `?planetary_hours` for the complete contract.

Text input uses `YYYY-MM-DD HH:MM[:SS]`. Use `source_timezone = "UTC"` when
input clock readings were recorded in UTC. `POSIXct` values already identify
instants and are never reinterpreted. Alternatively, supply dates plus
`time = "14:30"`. Each call uses one location.

## Add information to a dataset

```r
observations <- data.frame(
  recorded_at = c("2026-10-08 14:30:00", NA, "invalid"),
  value = c(10, 12, 14)
)
annotated <- add_planetary_info(
  observations, "recorded_at", "Africa/Nairobi", -1.2921, 36.8219
)
annotated[c("recorded_at", "value", "planetary_hour", "status")]
```

Original columns and row order are preserved. This function defaults to
`on_error = "NA"`: invalid rows remain, with a reason in `status`. Missing
inputs have status `"Missing timestamp"`. Output-column name collisions are
rejected. `planetary_hours()` instead defaults to `on_error = "stop"`.
Invalid shared coordinates or time zones always stop the call.

## Generate a schedule

```r
schedule <- planetary_schedule(
  "2026-10-08", "Africa/Nairobi", -1.2921, 36.8219
)
head(schedule, 2)
#   planetary_date day_ruler planetary_hour period hour_ruler          hour_start
# 1     2026-10-08   Jupiter              1    Day    Jupiter 2026-10-08 06:17:39
# 2     2026-10-08   Jupiter              2    Day       Mars 2026-10-08 07:18:17
#              hour_end duration_minutes
# 1 2026-10-08 07:18:17         60.64444
# 2 2026-10-08 08:18:56         60.64444
```

Output above was generated with suncalc 0.5.3. Computed boundaries retain
fractions of a second even though the default display omits them.

Intervals include their start and exclude their end. Sunrise starts hour 1;
sunset starts hour 13. Before sunrise, the previous planetary day applies.
The weekday ruler starts the repeating sequence Saturn, Jupiter, Mars, Sun,
Venus, Mercury, Moon. Durations measure elapsed time across DST transitions.
Ambiguous or nonexistent local clock strings are errors; use parsed `POSIXct`
instants to distinguish repeated times when clocks go back.

## Model and limits

Solar events use the R [suncalc package](https://github.com/datastorm-open/suncalc),
a port of SunCalc, with a solar-centre altitude of approximately -0.833 degrees
for sunrise and sunset. There is no elevation, terrain, weather, or local-horizon
input. The package requires consecutive local-date sunrises and one sunset
between them. Polar day/night and skipped civil dates can make this impossible;
`planetary_schedule()` errors and classification follows `on_error`.

Use modern Gregorian dates and IANA time zones appropriate to the coordinates.
The API does not impose a year cutoff, but validation currently covers selected
2024-2026 dates, not historical or far-future ephemerides. Future civil-time rules
can change. R and clock may use different timezone-database releases; keep both
current. Leap seconds are unsupported. No global or minute-level observational
accuracy guarantee is made.

Independent tests compare 48 sunrise/sunset events at six sites across four
seasonal dates against the [NOAA fractional-year equations](https://www.gml.noaa.gov/grad/solcalc/solareqns.PDF).
The largest observed difference is **2.725 minutes** (rounded up), with a
six-minute regression threshold. This measures agreement of two approximations,
not absolute accuracy. See [the validation notes](inst/validation/README.md)
for the sites, dates, provenance, and reproduction instructions.

## Development

```r
install.packages(c("testthat", "roxygen2", "rcmdcheck"))
roxygen2::roxygenise()
testthat::test_local()
rcmdcheck::rcmdcheck(args = c("--no-manual", "--as-cran"), error_on = "warning")
```

GitHub Actions runs the tests and R CMD check on Linux, macOS, and Windows.
See [NEWS.md](NEWS.md) for changes and [RELEASE-CHECKLIST.md](RELEASE-CHECKLIST.md)
for the publication steps.
