testthat::local_edition(3)

## a 240 m grid of 10 x 10 cells whose corner (xmin 0, ymax 2400) lines up with 1200 m blocks
fixture_grid <- function(vals = 0) {
  terra::rast(nrows = 10, ncols = 10, xmin = 0, xmax = 2400, ymin = 0, ymax = 2400,
              crs = "EPSG:3154", vals = vals)
}

## a conifer and a broadleaf species, in LandR's species-equivalence layout
fixture_spp <- function() {
  data.table::data.table(LandR = c("Pice_mar", "Popu_tre"), Type = c("Conifer", "Deciduous"))
}

test_that("parseLayerName() splits a name into covariate, resolution and cap", {
  out <- parseLayerName(c("prop_forest_240", "dist_paved_1200_adj", "timeSinceFire"))
  expect_equal(out$stem, c("prop_forest", "dist_paved", "timeSinceFire"))
  expect_equal(out$res, c(240, 1200, NA))
  expect_equal(out$adj, c(FALSE, TRUE, FALSE))
})

test_that("layerSources() gives each layer the source whose pattern it matches, or NA", {
  out <- layerSources(c("prop_forest_240", "ts_fire_1200", "dist_paved_240_adj", "prop_veg_240"),
                      defaultDynamicLayers("northern_mountain"))
  expect_equal(unname(out), c("forest", "fire", "disturbance", NA))
  expect_named(out, c("prop_forest_240", "ts_fire_1200", "dist_paved_240_adj", "prop_veg_240"))

  boreal <- layerSources(c("prop_needleleaf", "prop_veg", "timeSinceHarvest", "distpaved"),
                         defaultDynamicLayers("boreal"))
  expect_equal(unname(boreal), c("forest", NA, "harvest", "disturbance"))
})

test_that("layerSources() stops for a layer that matches two patterns, or an unnamed list", {
  expect_error(layerSources("prop_forest_240", list(forest = "^prop_", veg = "forest")),
               "more than one dynamicLayers pattern: prop_forest_240")
  expect_error(layerSources("prop_forest_240", list("^prop_")), "named list")
  expect_true(all(is.na(layerSources("prop_forest_240", list()))))
})

test_that("toResolution() averages the grid cells in each block and copies the mean back", {
  g <- fixture_grid()
  g[1] <- 1             # one cell of the first 1200 m block (5 x 5 cells)
  g[2] <- NA            # left out of the mean
  out <- toResolution(g, 1200)
  expect_true(terra::compareGeom(out, g))
  expect_equal(out[1][[1]], 1 / 24)
  expect_equal(out[25][[1]], 1 / 24)   # row 3, col 5: the first block
  expect_equal(out[6][[1]], 0)    # row 1, col 6: the next block
  expect_identical(toResolution(g, 240), g)
  expect_identical(toResolution(g, NA), g)
})

test_that("toResolution() stops for a resolution the grid cannot make, or blocks that would not line up", {
  expect_error(toResolution(fixture_grid(), 1000), "not a multiple")
  shifted <- terra::shift(fixture_grid(), dx = 240)
  expect_error(toResolution(shifted, 1200), "not a multiple of 1200 m")
})

test_that("circleMean() averages the cells within the radius and keeps NA cells NA", {
  g <- fixture_grid()
  g[terra::cellFromRowCol(g, 5, 5)] <- 1
  g[1] <- NA
  out <- circleMean(g, 500)
  ## a 500 m circle on a 240 m grid holds 13 cells (centres within 480 m, and the diagonals at 339 m)
  expect_equal(out[terra::cellFromRowCol(g, 5, 5)][[1]], 1 / 13)
  expect_equal(out[terra::cellFromRowCol(g, 5, 7)][[1]], 1 / 13)
  expect_equal(out[terra::cellFromRowCol(g, 5, 8)][[1]], 0)
  expect_true(is.na(out[1][[1]]))
})

test_that("landRForestCells() marks cells whose stand is of the types asked and above the biomass", {
  pgm <- terra::rast(nrows = 1, ncols = 4, xmin = 0, xmax = 4, ymin = 0, ymax = 1, vals = c(1L, 2L, NA, 3L))
  ## group 1 conifer (B 100), 2 broadleaf (B 300), 3 conifer with little biomass (B 10)
  cd <- data.table::data.table(pixelGroup = 1:3, speciesCode = c("Pice_mar", "Popu_tre", "Pice_mar"),
                               B = c(100L, 300L, 10L), age = 50L)
  all <- landRForestCells(cd, pgm, c("conifer", "deciduous", "mixed"), sppEquiv = fixture_spp())
  expect_equal(as.vector(terra::values(all)), c(1, 1, 0, 1))
  conifer <- landRForestCells(cd, pgm, "conifer", minBiomass = 50, sppEquiv = fixture_spp())
  expect_equal(as.vector(terra::values(conifer)), c(1, 0, 0, 0))
  ## cohortData is not changed
  expect_named(cd, c("pixelGroup", "speciesCode", "B", "age"))
  expect_error(landRForestCells(cd, pgm, "pine", sppEquiv = fixture_spp()), "Unknown forest types: pine")
})

test_that("forestLayer() adds LandR's change to modelLand's layer, kept within 0-1", {
  start <- fixture_grid(1)
  now <- fixture_grid(1)
  now[1:5] <- 0   # five cells lost their forest
  ml <- list(prop_forest_1200 = fixture_grid(0.5), prop_forest_240 = fixture_grid(0.1))

  ## 1200 m: the first block lost 5 of its 25 cells
  out <- forestLayer("prop_forest_1200", now, start, ml)
  expect_equal(out[1][[1]], 0.5 - 5 / 25)
  expect_equal(out[100][[1]], 0.5)
  expect_named(out, "prop_forest_1200")

  ## 240 m, in a 500 m circle: kept at 0 or more
  out <- forestLayer("prop_forest_240", now, start, ml, windowRadius = list("240" = 500))
  expect_equal(out[1][[1]], 0)
  expect_equal(out[100][[1]], 0.1)

  ## LandR alone
  out <- forestLayer("prop_forest_1200", now, start, ml, mode = "LandR")
  expect_equal(out[1][[1]], 20 / 25)
})

test_that("timeSinceLayers() takes the more recent of modelLand's and the simulation's events", {
  base <- fixture_grid(NA)            # ts_fire_240 in 2025: NA = never burned
  base[1] <- 5                        # burned 2020
  base[2] <- 10                       # burned 2015
  base[3] <- 200                      # filled with ts_else: never burned
  simTs <- fixture_grid(NA)           # scfm in 2035: years since a fire in the simulation
  simTs[2] <- 3                       # burned 2032
  simTs[4] <- 8                       # burned 2027

  out <- timeSinceLayers(c("ts_fire_240", "ts_fire_1200"), base, 2035, 2025, 200, simTs)
  expect_named(out, c("ts_fire_240", "ts_fire_1200"))
  expect_equal(unlist(out$ts_fire_240[1:5]), c(15, 3, 200, 8, 200), ignore_attr = TRUE)
  ## 1200 m: the most recent fire year of the block's burned cells (2020, 2032, 2027)
  expect_equal(out$ts_fire_1200[1][[1]], 2035 - 2032)
  expect_equal(out$ts_fire_1200[100][[1]], 200)

  ## or their mean
  out <- timeSinceLayers("ts_fire_1200", base, 2035, 2025, 200, simTs, coarse = "mean")
  expect_equal(out$ts_fire_1200[1][[1]], 2035 - mean(c(2020, 2032, 2027)))
  expect_error(timeSinceLayers("ts_fire_1200", base, 2035, 2025, 200, coarse = "max"), "'recent' or 'mean'")

  ## no simulation fires: modelLand's layer only ages
  aged <- timeSinceLayers("ts_fire_240", base, 2035, 2025, 200)
  expect_equal(unlist(aged[1:4]), c(15, 20, 200, 200), ignore_attr = TRUE)
})

test_that("timeSinceLayers() reads a stand-in no-event year (noEventYear) as no event", {
  ## as the boreal NWT modelLand: baseline 2022, never burned = years since 1900 (122)
  base <- fixture_grid(122)
  base[1] <- 2                        # burned 2020
  base[2] <- 122                      # never
  base[3] <- 10                       # burned 2012
  simTs <- fixture_grid(NA)
  simTs[2] <- 1                       # burned 2026 in the simulation

  out <- timeSinceLayers(c("timeSinceFire", "ts_fire_1200"), base, 2027, 2022, 200, simTs,
                         noEventYear = 1900)
  ## never-burned cells keep counting from 1900, as the model was fit
  expect_equal(unlist(out$timeSinceFire[1:4]), c(7, 1, 15, 127), ignore_attr = TRUE)
  ## the stand-in is left out of the block: most recent of 2020, 2026, 2012
  expect_equal(out$ts_fire_1200[1][[1]], 1)
  expect_equal(out$ts_fire_1200[100][[1]], 127)
  expect_equal(timeSinceLayers("ts_fire_1200", base, 2027, 2022, 200, simTs, coarse = "mean",
                               noEventYear = 1900)[1][[1]],
               2027 - mean(c(2020, 2026, 2012)))

  ## a ts_else below the stand-in does not matter once noEventYear is set
  out <- timeSinceLayers("timeSinceFire", base, 2027, 2022, 100, noEventYear = 1900)
  expect_equal(unlist(out[c(2, 3)]), c(127, 15), ignore_attr = TRUE)

  ## without noEventYear the stand-in would be read as a fire in 1900 (aged) unless >= ts_else
  out <- timeSinceLayers("timeSinceFire", base, 2027, 2022, 100)
  expect_equal(out[2][[1]], 100)
})

test_that("buildForecastLayers() takes each source's noEventYear", {
  ml <- list(timeSinceFire = fixture_grid(122), timeSinceHarvest = fixture_grid(72))
  layers <- names(ml)
  sources <- layerSources(layers, defaultDynamicLayers("boreal"))
  p <- list(baselineYear = 2022, ts_else = 100, noEventYear = list(fire = 1900, harvest = 1950))
  out <- suppressMessages(buildForecastLayers(layers, sources, 2027, ml, fixture_grid(), objs = list(), p = p))
  expect_equal(out$timeSinceFire[1][[1]], 127)
  expect_equal(out$timeSinceHarvest[1][[1]], 77)
  expect_true(is.na(noEventYearFor("harvest", list(fire = 1900))))
})

test_that("timeSinceBase() finds modelLand's layer of the covariate on the grid", {
  ml <- list(ts_fire_240 = fixture_grid(1), ts_fire_1200 = fixture_grid(2), timeSinceHarvest = fixture_grid(3))
  expect_equal(timeSinceBase("ts_fire", ml, 240)[1][[1]], 1)
  expect_equal(timeSinceBase("timeSinceHarvest", ml, 240)[1][[1]], 3)
  expect_error(timeSinceBase("ts_fire", ml["ts_fire_1200"], 240), "needs ts_fire_240")
})

test_that("buildForecastLayers() builds each layer from its source, and the rest from modelLand", {
  g <- fixture_grid()
  ml <- list(prop_forest_240 = fixture_grid(0.5), ts_fire_240 = fixture_grid(NA),
             prop_veg_240 = fixture_grid(0.3), dist_paved_240_adj = fixture_grid(1000))
  layers <- c("prop_veg_240", "prop_forest_240", "ts_fire_240", "dist_paved_240_adj")
  sources <- layerSources(layers, defaultDynamicLayers("northern_mountain"))
  p <- list(baselineYear = 2025, ts_else = 200, windowRadius = list(), forestForecast = "change",
            forestTypes = list(prop_forest = c("conifer", "deciduous", "mixed")),
            forestMinBiomass = 0, sppEquivCol = "LandR")

  ## one stand everywhere, then none in the first cell; one fire in the simulation, in cell 2
  pgm <- terra::rast(g, vals = 1L)
  cd <- data.table::data.table(pixelGroup = 1L, speciesCode = "Pice_mar", B = 100L, age = 50L)
  startCells <- landRForestCells(cd, pgm, p$forestTypes$prop_forest, sppEquiv = fixture_spp())
  pgmNow <- pgm
  pgmNow[1] <- NA
  tsf <- fixture_grid(NA)
  tsf[2] <- 4

  expect_message(
    out <- buildForecastLayers(layers, sources, 2030, ml, g,
                               objs = list(cohortData = cd, pixelGroupMap = pgmNow, sppEquiv = fixture_spp(),
                                           timeSinceFire = tsf, forestBaseline = list(prop_forest = startCells)),
                               p = p),
    "stay as in modelLand.*dist_paved_240_adj"
  )
  expect_named(out, layers)
  expect_equal(out$prop_forest_240[1:2][[1]], c(0, 0.5))
  expect_equal(out$ts_fire_240[1:3][[1]], c(200, 4, 200))
  expect_equal(out$prop_veg_240[1][[1]], 0.3)
  expect_equal(out$dist_paved_240_adj[1][[1]], 1000)
})

test_that("buildForecastLayers() keeps forest layers as in modelLand and ages fire without the sim's objects", {
  ml <- list(prop_forest_240 = fixture_grid(0.5), ts_fire_240 = fixture_grid(5))
  layers <- names(ml)
  sources <- layerSources(layers, defaultDynamicLayers("northern_mountain"))
  p <- list(baselineYear = 2025, ts_else = 200)
  msgs <- testthat::capture_messages(
    out <- buildForecastLayers(layers, sources, 2030, ml, fixture_grid(), objs = list(), p = p)
  )
  expect_match(msgs, "No cohortData", all = FALSE)
  expect_match(msgs, "only age", all = FALSE)
  expect_equal(out$prop_forest_240[1][[1]], 0.5)
  expect_equal(out$ts_fire_240[1][[1]], 10)
})

test_that("buildForecastLayers() stops for a static layer modelLand lacks, and a sim layer off the grid", {
  p <- list(baselineYear = 2025, ts_else = 200)
  expect_error(buildForecastLayers("prop_veg_240", c(prop_veg_240 = NA), 2030, list(), fixture_grid(),
                                   objs = list(), p = p),
               "lacks these layers the forecast needs: prop_veg_240")
  ml <- list(ts_fire_240 = fixture_grid(5))
  expect_error(buildForecastLayers("ts_fire_240", c(ts_fire_240 = "fire"), 2030, ml, fixture_grid(),
                                   objs = list(timeSinceFire = terra::shift(fixture_grid(), dx = 240)), p = p),
               "timeSinceFire is not on the forecast grid")
})
