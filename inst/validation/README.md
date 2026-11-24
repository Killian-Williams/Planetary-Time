# Solar validation

Production events come from suncalc 0.5.3. Independent references were generated
using NOAA's General Solar Position Calculations (fractional-year equations):
https://www.gml.noaa.gov/grad/solcalc/solareqns.PDF

`tools/generate-solar-reference.R` implements those equations without calling
suncalc or any production function. It evaluates declination/equation of time
at noon, uses a 90.833 degree zenith and 366 days in leap years, and writes the
committed `tests/testthat/fixtures/noaa-solar.csv`. UTC minutes are compared
modulo a day; local-date correctness has separate date-line tests.

The 24 site/date pairs cover Nairobi, New York, London, Sydney, Kiritimati, and
Pago Pago on 2024-03-20, 2025-06-21, 2026-09-22, and 2026-12-21: 48 solar events.
Observed absolute differences were 0.0563 to 2.7242 minutes with suncalc 0.5.3.
The test threshold is six minutes, chosen as a coarse regression alarm for two
approximate models. These samples do not establish a global accuracy bound.
The NOAA approximation is not a measured observational reference or the full
Meeus-based NOAA calculator. High latitudes, terrain, observer height, weather,
historical dates, and far-future dates need separate validation.

From the repository root:

```r
source("tools/generate-solar-reference.R")
testthat::test_local(filter = "solar-reference")
```

Fixtures are checked in so ordinary tests require no network. Inspect fixture
changes and their source before updating expected values. Exact-boundary tests
use unrounded POSIXct events from schedules, independent of printed precision.
