testthat::local_edition(3)

## a modelLand list with the given layer names, each a 2 x 2 raster
fixture_land <- function(layers) {
  r <- terra::rast(nrows = 2, ncols = 2, xmin = 0, xmax = 2, ymin = 0, ymax = 2, vals = 1:4)
  setNames(lapply(seq_along(layers), function(i) r + i), layers)
}

test_that("makeFixedSSUD() takes the named layers from modelLand, under their own names", {
  fixed <- makeFixedSSUD(fixture_land(c("prop_veg_240", "dist_paved_240_adj", "prop_forest_240")),
                         c("prop_veg_240", "dist_paved_240_adj"))
  expect_named(fixed, c("prop_veg_240", "dist_paved_240_adj"))
  expect_equal(as.vector(terra::values(fixed$dist_paved_240_adj)), 3:6)
})

test_that("makeFixedSSUD() names the layers modelLand lacks", {
  expect_error(
    makeFixedSSUD(fixture_land(c("prop_veg_240", "dist_paved_240")), c("prop_veg_240", "prop_veg_1200")),
    "lacks: prop_veg_1200"
  )
})

test_that("makeFixedSSUD() gives NULL when no layer is fixed", {
  expect_null(makeFixedSSUD(fixture_land("ts_fire_240"), character()))
})
