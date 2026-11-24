# Independent implementation of NOAA's fractional-year approximation:
# https://www.gml.noaa.gov/grad/solcalc/solareqns.PDF
# No suncalc calls: this generator is deliberately independent of production.
# Run from the package root; committed fixtures make tests offline/reproducible.
noaa_minutes <- function(date, lat, lon) {
  d <- as.Date(date)
  year <- as.integer(format(d, "%Y"))
  days <- as.numeric(as.Date(sprintf("%d-01-01", year + 1)) -
                       as.Date(sprintf("%d-01-01", year)))
  gamma <- 2 * pi / days * (as.POSIXlt(d)$yday)
  eq <- 229.18 * (0.000075 + 0.001868 * cos(gamma) - 0.032077 * sin(gamma) -
                   0.014615 * cos(2 * gamma) - 0.040849 * sin(2 * gamma))
  decl <- 0.006918 - 0.399912 * cos(gamma) + 0.070257 * sin(gamma) -
    0.006758 * cos(2 * gamma) + 0.000907 * sin(2 * gamma) -
    0.002697 * cos(3 * gamma) + 0.00148 * sin(3 * gamma)
  phi <- lat * pi / 180
  ha <- acos(cos(90.833 * pi / 180) / (cos(phi) * cos(decl)) -
               tan(phi) * tan(decl)) * 180 / pi
  c(sunrise = 720 - 4 * (lon + ha) - eq,
    sunset = 720 - 4 * (lon - ha) - eq)
}
sites <- data.frame(
  site = c("Nairobi", "New York", "London", "Sydney", "Kiritimati", "Pago Pago"),
  timezone = c("Africa/Nairobi", "America/New_York", "Europe/London",
               "Australia/Sydney", "Pacific/Kiritimati", "Pacific/Pago_Pago"),
  latitude = c(-1.2921, 40.7128, 51.5074, -33.8688, 1.8721, -14.2756),
  longitude = c(36.8219, -74.006, -0.1278, 151.2093, -157.4278, -170.702))
fixtures <- do.call(rbind, lapply(c("2024-03-20", "2025-06-21", "2026-09-22", "2026-12-21"),
  function(date) {
    out <- sites
    out$date <- date
    values <- t(vapply(seq_len(nrow(sites)), function(i)
      noaa_minutes(date, sites$latitude[i], sites$longitude[i]), numeric(2)))
    out$sunrise_utc_minutes <- values[, 1] %% 1440
    out$sunset_utc_minutes <- values[, 2] %% 1440
    out
  }))
write.csv(fixtures, "tests/testthat/fixtures/noaa-solar.csv", row.names = FALSE)
