# PlanetaryTime 0.1.0

* Standardize the package and RStudio project name as `PlanetaryTime`; update
  repository URLs to Killian-Williams/Planetary-Time.
* Add correctness tests for interval boundaries, weekday rulers, DST,
  international date-line locations, missing inputs, and polar conditions.
* Add Linux, macOS, and Windows GitHub Actions tests and R CMD check.
* Document all three exported functions and include generated help pages.
* Add executable usage examples and independent solar-reference fixtures.
* Reject malformed schedule dates and missing timestamp-column names clearly.
* Treat standalone logical and numeric missing timestamps as missing rows.
* Remove unrelated debugging code.

The GitHub API remains data-frame based. The old misspellings `PlanteryTime`
and `PlantaryTime` are replaced by `PlanetaryTime`; update `library()` calls.
The older local experimental tzdb API is not part of this release.
