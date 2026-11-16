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
