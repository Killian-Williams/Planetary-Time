# Release 0.1.0

1. Run `roxygen2::roxygenise()` and review generated help.
2. Run `testthat::test_local()` and `R CMD build .` followed by
   `R CMD check --as-cran --no-manual PlanetaryTime_0.1.0.tar.gz`.
3. Commit the reviewed changes on `improve-package-quality`, push that branch,
   and open a pull request against `main`.
4. Wait for all three GitHub Actions platforms to pass. Review any CRAN incoming
   notes separately from package failures. Merge the reviewed PR.
5. At the verified main commit, create the annotated tag `v0.1.0` and push it.
6. Publish a GitHub release from that tag with the 0.1.0 NEWS entries as release
   notes and attach the checked source archive.

The package rename requires users to change `library(PlanteryTime)` or
`library(PlantaryTime)` to `library(PlanetaryTime)`. This release does not replace
the user's older local experimental tzdb implementation.

Publication must follow successful remote CI; a locally prepared archive is not
a published release. Do not tag an unreviewed or unchecked main commit.
