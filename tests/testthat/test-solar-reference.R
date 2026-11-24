test_that("selected solar events agree with independent NOAA approximation", {
  ref <- read.csv(test_path("fixtures", "noaa-solar.csv"))
  # Six minutes is a regression threshold between two approximate models,
  # not a claim about observed sunrise/sunset or all dates and latitudes.
  for (i in seq_len(nrow(ref))) {
    r <- ref[i, ]
    s <- planetary_schedule(r$date, r$timezone, r$latitude, r$longitude)
    actual <- as.numeric(c(s$hour_start[1], s$hour_start[13])) / 60 %% 1440
    expected <- c(r$sunrise_utc_minutes, r$sunset_utc_minutes)
    delta <- abs((actual - expected + 720) %% 1440 - 720)
    expect_true(all(delta < 6), info = paste(r$site, r$date, paste(round(delta, 3), collapse = ", ")))
  }
})
