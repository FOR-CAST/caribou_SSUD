## a 2 x 2 landscape with two covariates, and a study area covering it
envlayers <- function() {
  x <- terra::rast(nrows = 2, ncols = 2, xmin = 0, xmax = 2, ymin = 0, ymax = 2, vals = 1:4)
  y <- terra::rast(x, vals = c(0, 1, 0, 1))
  list2env(list(x = x, y = y), parent = baseenv())
}
studyArea <- function() terra::as.polygons(terra::ext(0, 2, 0, 2), crs = terra::crs(envlayers()$x))

test_that("make_pde() predicts from a coefficients table", {
  ## columns as in hsaCEtool's <model>_fixed.csv; only the _end terms enter the PDE
  coefs <- data.frame(
    term = c("(Intercept)", "x_start", "x_end", "x_end:y_end"),
    estimate = c(5, 9, 0.5, 0.25),
    se = 1, z = 1, p = 0.5
  )
  pde <- make_pde(coefs, envlayers(), studyArea(), normalize = FALSE)
  x <- 1:4
  y <- c(0, 1, 0, 1)
  expect_equal(as.vector(terra::values(pde)), exp(2 * 0.5 * x + 2 * 0.25 * x * y))

  pde <- make_pde(coefs, envlayers(), studyArea())
  u <- exp(2 * 0.5 * x + 2 * 0.25 * x * y)
  expect_equal(as.vector(terra::values(pde)), u / sum(u))
})

test_that("a fitted model and its coefficients table give the same PDE", {
  set.seed(1)
  steps <- data.frame(x_end = stats::runif(200), y_end = stats::rbinom(200, 1, 0.5))
  steps$case_ <- stats::rbinom(200, 1, stats::plogis(-1 + 1.5 * steps$x_end))
  fit <- glmmTMB::glmmTMB(case_ ~ x_end + x_end:y_end, family = stats::binomial(), data = steps)

  tab <- coef_tab(fit)
  expect_identical(names(tab), c("term", "estimate"))
  expect_identical(tab$term, names(glmmTMB::fixef(fit)$cond))
  expect_equal(
    terra::values(mod2UD(tab, envlayers(), studyArea())$pde),
    terra::values(mod2UD(fit, envlayers(), studyArea())$pde)
  )
})

test_that("coef_tab() names the columns a coefficients table lacks", {
  expect_error(coef_tab(data.frame(term = "x_end", beta = 1)), "estimate")
  expect_error(coef_tab(data.frame(name = "x_end", beta = 1)), "term, estimate")
})
