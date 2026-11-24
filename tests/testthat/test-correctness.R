test_that("all exact interval starts and ends use half-open intervals", {
  s <- planetary_schedule("2026-10-08", "Africa/Nairobi", -1.2921, 36.8219)
  expect_equal(nairobi(s$hour_start)$planetary_hour, 1:24)
  expect_equal(nairobi(s$hour_end)$planetary_hour, c(2:24, 1L))
  expect_equal(nairobi(s$hour_start - 0.001)$planetary_hour, c(24L, 1:23))
  expect_equal(nairobi(s$hour_start[13])$period, "Night")
  expect_equal(nairobi(s$hour_end[24])$planetary_date, as.Date("2026-10-09"))
  expect_equal(nairobi("2026-10-08 02:00:00")$planetary_date, as.Date("2026-10-07"))
  expect_equal(s$hour_end[-24], s$hour_start[-1])
  expect_equal(sum(s$duration_minutes), as.numeric(difftime(s$hour_end[24],
                                                        s$hour_start[1], units = "mins")))
  expect_equal(length(unique(round(s$duration_minutes[1:12], 6))), 1L)
  expect_equal(length(unique(round(s$duration_minutes[13:24], 6))), 1L)
})

test_that("weekday rulers and all 24 Chaldean rulers are correct", {
  expected <- c("Sun", "Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn")
  cycle <- c("Saturn", "Jupiter", "Mars", "Sun", "Venus", "Mercury", "Moon")
  for (i in 1:7) {
    s <- planetary_schedule(as.Date("2026-10-04") + i - 1,
                            "Africa/Nairobi", -1.2921, 36.8219)
    expect_equal(s$day_ruler, rep(expected[i], 24))
    expect_equal(s$hour_ruler, cycle[(match(expected[i], cycle) - 1 + 0:23) %% 7 + 1])
  }
})

test_that("DST gaps and folds require unambiguous instants", {
  expect_error(ny("2026-03-08 02:30:00"), "[Nn]onexistent")
  expect_error(ny("2026-11-01 01:30:00"), "[Aa]mbiguous")
  times <- as.POSIXct(c("2026-11-01 05:30:00", "2026-11-01 06:30:00"), tz = "UTC")
  x <- ny(times)
  expect_equal(diff(as.numeric(x$timestamp_utc)), 3600)
  expect_true(all(x$status == "OK"))
  expect_match(x$local_time[1], "EDT")
  expect_match(x$local_time[2], "EST")
  for (d in c("2026-03-07", "2026-10-31")) {
    s <- planetary_schedule(d, "America/New_York", 40.7128, -74.006)
    expect_equal(ny(s$hour_start)$planetary_hour, 1:24)
    expect_equal(s$duration_minutes, as.numeric(difftime(s$hour_end, s$hour_start,
                                                       units = "mins")))
    expect_true(all(abs(diff(s$duration_minutes[13:24])) < 1e-7))
  }
})

test_that("date-line and fractional-offset locations retain their local date", {
  locations <- list(c("Pacific/Kiritimati", 1.8721, -157.4278),
                    c("Pacific/Pago_Pago", -14.2756, -170.702),
                    c("Asia/Kathmandu", 27.7172, 85.324))
  for (loc in locations) {
    zone <- loc[1]; lat <- as.numeric(loc[2]); lon <- as.numeric(loc[3])
    s <- planetary_schedule("2026-06-21", zone, lat, lon)
    expect_equal(as.Date(s$hour_start[1], tz = zone), as.Date("2026-06-21"))
    expect_equal(as.Date(s$hour_end[24], tz = zone), as.Date("2026-06-22"))
    expect_true(all(s$duration_minutes > 0))
    x <- planetary_hours(s$hour_start, timezone = zone, latitude = lat, longitude = lon)
    expect_equal(x$planetary_hour, 1:24)
  }
})

test_that("source zones and POSIXct instants are interpreted consistently", {
  a <- nairobi("2026-10-08 11:30:00", source_timezone = "UTC")
  b <- nairobi("2026-10-08 14:30:00")
  c <- nairobi(as.POSIXct("2026-10-08 11:30:00", tz = "UTC"))
  expect_equal(a, b)
  expect_equal(b, c)
  expect_equal(nairobi("2026-10-08", time = "14:30"), b)
})

test_that("missing and invalid rows retain order and actionable status", {
  expect_equal(nairobi(NA)$status, "Missing timestamp")
  expect_equal(nairobi(NA_real_)$status, "Missing timestamp")
  x <- nairobi(c(NA, "bad", "2026-10-08 14:30:00"), on_error = "NA")
  expect_equal(x$status[c(1, 3)], c("Missing timestamp", "OK"))
  expect_true(all(is.na(x$planetary_hour[1:2])))
  expect_error(nairobi("bad"), "Timestamp 1")
  expect_error(nairobi("2026-02-30 12:00:00"))
  expect_error(nairobi("2026-10-08 24:00:00"))
  expect_error(nairobi(character()), "at least one")
  expect_error(nairobi(c("2026-10-08", "2026-10-09"), time = c("01:00", "02:00", "03:00")))
  expect_equal(nairobi(c("2026-10-08", NA), time = "12:00")$status,
               c("OK", "Missing timestamp"))
})

test_that("invalid shared arguments and dates are rejected", {
  for (lat in list(NA_real_, NaN, Inf, 91, c(1, 2), "1")) {
    expect_error(planetary_schedule("2026-10-08", "UTC", lat, 0), "latitude")
  }
  for (lon in list(NA_real_, NaN, Inf, 181, c(1, 2), "1")) {
    expect_error(planetary_schedule("2026-10-08", "UTC", 0, lon), "longitude")
  }
  expect_error(planetary_schedule("2026-10-08", "Invalid/Zone", 0, 0), "time zone")
  expect_error(nairobi("2026-10-08 12:00:00", source_timezone = NA_character_))
  for (d in list(NA, character(), c("2026-01-01", "2026-01-02"),
                 "2026-02-30", "2026-01-01junk", 1, as.Date(Inf, origin = "1970-01-01"))) {
    expect_error(planetary_schedule(d, "UTC", 0, 0), "valid date")
  }
})

test_that("polar conditions fail explicitly or yield status rows", {
  for (d in c("2026-06-21", "2026-12-21")) {
    expect_error(planetary_schedule(d, "Europe/Oslo", 69.6492, 18.9553), "sunrise|sunset")
    x <- planetary_hours(paste(d, "12:00:00"), timezone = "Europe/Oslo",
                         latitude = 69.6492, longitude = 18.9553, on_error = "NA")
    expect_match(x$status, "sunrise|sunset")
    expect_true(is.na(x$planetary_hour))
  }
})

test_that("dataset enrichment preserves data and rejects collisions", {
  d <- data.frame(at = c("2026-10-08 14:30:00", NA), value = c(10, 20))
  x <- add_planetary_info(d, "at", "Africa/Nairobi", -1.2921, 36.8219)
  expect_equal(x[names(d)], d)
  expect_equal(x$status, c("OK", "Missing timestamp"))
  expect_error(add_planetary_info(d, NA_character_, "UTC", 0, 0), "existing timestamp")
  expect_error(add_planetary_info(d[FALSE, ], "at", "UTC", 0, 0), "no rows")
  d$status <- "existing"
  expect_error(add_planetary_info(d, "at", "UTC", 0, 0), "already exist")
})
