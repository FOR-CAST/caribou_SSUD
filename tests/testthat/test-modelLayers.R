testthat::local_edition(3)

## terms as hsaCEtool's <model>_fixed.csv writes them (made-up estimates)
nm_terms <- function(terms) {
  data.table::data.table(term = terms, estimate = seq_along(terms) / 10)
}

test_that("modelLayerNames() reads the layers from the end-of-step terms, without movement or season terms", {
  coefs <- nm_terms(c(
    "I(log((sl_ + 1)/1000))", "I(cos(ta_))", "I(log((sl_ + 1)/1000)):I(cos(ta_))",
    "prop_forest_240_end", "I(log(ts_fire_240_end + 1))",
    "I(log((dist_paved_240_adj_end + 1)/1000)):I(log((dist_paved_1200_adj_end + 1)/1000))",
    "prop_forest_240_end:prop_forest_1200_end", "seasonwinter:prop_Ice_240_end", "x_start"
  ))

  expect_identical(
    modelLayerNames(coefs),
    c("prop_forest_240", "ts_fire_240", "dist_paved_240_adj", "dist_paved_1200_adj", "prop_forest_1200",
      "prop_Ice_240")
  )
})

test_that("modelLayerNames() reads a fitted model's terms too", {
  skip_if_not_installed("broom.mixed")
  expect_setequal(modelLayerNames(fixture_fit()), c("x", "y"))
})

test_that("checkModelLayers() stops naming the model and the layers the landscape lacks", {
  mods <- list(global = nm_terms(c("prop_forest_240_end", "prop_veg_240_end:prop_veg_1200_end")))

  expect_error(checkModelLayers(mods, c("prop_forest_240", "prop_veg_240")), "'global'.*prop_veg_1200")
  expect_true(checkModelLayers(mods, c("prop_forest_240", "prop_veg_240", "prop_veg_1200")))
})

test_that("checkModelLayers() warns when a model reads an uncapped distance whose `_adj` copy exists", {
  plain <- list(global = nm_terms("I(log((dist_paved_240_end + 1)/1000))"))
  capped <- list(global = nm_terms("I(log((dist_paved_240_adj_end + 1)/1000))"))
  layers <- c("dist_paved_240", "dist_paved_240_adj")

  expect_warning(checkModelLayers(plain, layers, warnCapped = TRUE), "dist_paved_240_adj")
  expect_no_warning(checkModelLayers(plain, layers))
  expect_no_warning(checkModelLayers(capped, layers, warnCapped = TRUE))
})

test_that("ssudGrid() gives rasterToMatch, or modelLand's grid without it", {
  land <- as.list(fixture_envlayers())[c("x", "y")]
  rtm <- terra::rast(land$x)

  expect_true(terra::compareGeom(ssudGrid(land), land$x))
  expect_true(terra::compareGeom(ssudGrid(land, rtm), rtm))
  expect_false(terra::hasValues(ssudGrid(land)))
})

test_that("ssudGrid() stops naming the modelLand layers not on rasterToMatch's grid", {
  land <- as.list(fixture_envlayers())[c("x", "y")]
  finer <- terra::rast(nrows = 4, ncols = 4, xmin = 0, xmax = 2, ymin = 0, ymax = 2,
                       crs = terra::crs(land$x))

  expect_error(ssudGrid(land, finer), "rasterToMatch's grid.*x, y")
  land$y <- terra::disagg(land$y, 2)
  expect_error(ssudGrid(land), "first modelLand layer.*: y$")
})

test_that("readModelTerms() finds categorical layers, seasons and other variables in the landscape terms", {
  coefs <- nm_terms(c("x_end", "lc_endopen", "lc_endmixed wood", "x_end:seasonwinter",
                      "seasonsummer:x_end", "seasonwinter:I(log((sl_ + 1)/1000))", "seasonwinter",
                      "yearseason2020:x_end"))
  terms <- readModelTerms(coefs)

  expect_identical(terms$layers, c("x", "lc"))
  expect_identical(terms$categorical, data.frame(layer = c("lc", "lc"), level = c("open", "mixed wood")))
  expect_identical(terms$seasons, c("winter", "summer"))
  expect_identical(terms$other, "yearseason2020")
})

test_that("checkModelLayers() takes a season model, and stops for other variables or a categorical layer", {
  expect_true(checkModelLayers(list(global = nm_terms("seasonwinter:prop_forest_240_end")), "prop_forest_240"))
  expect_error(checkModelLayers(list(global = nm_terms("yearseason2020:prop_forest_240_end")), "prop_forest_240"),
               "'global'.*yearseason2020.*neither")
  expect_error(checkModelLayers(list(global = nm_terms(c("x_end", "lc_endopen"))), c("x", "lc")),
               "categorical.*lc \\(level 'open'\\)")
})
