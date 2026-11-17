testthat::local_edition(3)

## a made-up season model, as hsaCEtool's <model>_fixed.csv gives it: a term shared by all seasons,
## season terms for the fixture's layers x and y, movement and season-only terms
season_coefs <- function() {
  data.table::data.table(
    term = c("x_end", "seasonwinter:x_end", "seasonsummer:x_end", "seasonwinter:y_end",
             "seasonsummer:y_end:x_end", "seasonwinter:I(log((sl_ + 1)/1000))", "seasonsummer"),
    estimate = c(0.5, 0.25, -0.5, 1, 0.1, 9, 9)
  )
}

test_that("modelSeasons() lists a model's seasons, and none for a model without", {
  expect_identical(modelSeasons(season_coefs()), c("winter", "summer"))
  expect_identical(modelSeasons(fixture_coefs()), character())
})

test_that("seasonCoefs() keeps the shared terms and the season's own, with the season taken out", {
  winter <- seasonCoefs(season_coefs(), "winter")
  expect_identical(winter$term, c("x_end", "x_end", "y_end", "I(log((sl_ + 1)/1000))"))
  expect_identical(winter$estimate, c(0.5, 0.25, 1, 9))

  summer <- seasonCoefs(season_coefs(), "summer")
  expect_identical(summer$term, c("x_end", "x_end", "y_end:x_end"))
})

test_that("seasonChoice() takes all seasons by default, a subset, or none of one kind", {
  s <- c("winter", "summer")
  expect_identical(seasonChoice("global", s), list(maps = s, fullYear = s))
  expect_identical(seasonChoice("global", s, seasonMaps = character(0), fullYear = "winter"),
                   list(maps = character(), fullYear = "winter"))
  expect_error(seasonChoice("global", s, seasonMaps = "fall"), "seasonMaps.*'global'.*fall.*winter, summer")
  expect_error(seasonChoice("global", s, character(0), character(0)), "both empty")
  expect_identical(seasonChoice("global", character()), list(maps = character(), fullYear = character()))
  expect_error(seasonChoice("global", character(), seasonMaps = "winter"), "no seasons")
})

test_that("pdeMapNames() names the full-year map as the model and each season map <model>_<season>", {
  mods <- list(global = season_coefs(), BC = fixture_coefs())
  expect_identical(pdeMapNames(mods[2]), "BC")
  expect_identical(pdeMapNames(mods[1]), c("global", "global_winter", "global_summer"))
  expect_identical(pdeMapNames(mods[1], seasonMaps = "summer", fullYear = character(0)), "global_summer")
})

test_that("fullYearWeights() weights by season length, equally, or by given numbers, summing to 1", {
  table <- data.table::data.table(season = c("winter", "summer", "other"), days = c(200L, 100L, 65L))

  expect_identical(fullYearWeights(c("winter", "summer"), "length", table), c(winter = 2 / 3, summer = 1 / 3))
  expect_identical(fullYearWeights(c("winter", "summer"), "equal"), c(winter = 0.5, summer = 0.5))
  expect_identical(fullYearWeights(c("winter", "summer"), c(summer = 1, winter = 3)), c(winter = 0.75, summer = 0.25))

  expect_error(fullYearWeights(c("winter", "summer"), "length"), "needs the model's season table")
  expect_error(fullYearWeights(c("fall", "winter"), "length", table), "no days for: fall")
  expect_error(fullYearWeights(c("winter", "summer"), c(1, 2)), "named by season")
  expect_error(fullYearWeights(c("winter", "summer"), c(winter = 1)), "no weight for: summer")
  expect_error(fullYearWeights(c("winter", "summer"), c(winter = 0, summer = 0)), "not all zero")
  expect_identical(fullYearWeights("winter", "length"), c(winter = 1))
  expect_error(fullYearWeights(c("winter", "summer"), "days"), "must be 'length', 'equal'")
})

test_that("makePDEs() makes a map per season and a full-year map, the seasons' PDEs weighted", {
  ud <- makePDEs(mods = list(global = season_coefs()), envLayers = fixture_envlayers(),
                 studyAreaCaribou = fixture_area(), seasonWeights = c(winter = 3, summer = 1))

  expect_named(ud$pde, c("global", "global_winter", "global_summer"))
  expect_named(ud$pdeMap, c("global", "global_winter", "global_summer"))

  # a season's map is the model without seasons made from that season's terms
  winter <- makePDEs(mods = list(global = seasonCoefs(season_coefs(), "winter")), envLayers = fixture_envlayers(),
                     studyAreaCaribou = fixture_area())
  expect_equal(terra::values(ud$pde$global_winter), terra::values(winter$pde$global))

  expected <- 0.75 * terra::values(ud$pde$global_winter) + 0.25 * terra::values(ud$pde$global_summer)
  expect_equal(terra::values(ud$pde$global), expected)
  expect_equal(terra::global(ud$pde$global, "sum", na.rm = TRUE)[[1]], 1)
})

test_that("makePDEs() makes only the maps asked for, and stops for a full-year map without normalizing", {
  ud <- makePDEs(mods = list(global = season_coefs()), envLayers = fixture_envlayers(),
                 studyAreaCaribou = fixture_area(), seasonMaps = character(0), fullYear = "summer")
  expect_named(ud$pde, "global")
  expect_equal(terra::values(ud$pde$global),
               terra::values(makePDEs(list(global = seasonCoefs(season_coefs(), "summer")), fixture_envlayers(),
                                      studyAreaCaribou = fixture_area())$pde$global))

  expect_error(makePDEs(mods = list(global = season_coefs()), envLayers = fixture_envlayers(),
                        studyAreaCaribou = fixture_area(), normalizePDE = FALSE, seasonWeights = "equal"),
               "needs normalizePDE = TRUE")
  ud <- makePDEs(mods = list(global = season_coefs()), envLayers = fixture_envlayers(),
                 studyAreaCaribou = fixture_area(), normalizePDE = FALSE, fullYear = character(0))
  expect_named(ud$pde, c("global_winter", "global_summer"))
  expect_null(ud$pdeMap)
})

test_that("makePDEs() writes the season maps as pde_<model>_<season>_<key>.tif", {
  dir <- withr::local_tempdir()
  ud <- makePDEs(mods = list(global = season_coefs()), envLayers = fixture_envlayers(),
                 studyAreaCaribou = fixture_area(), seasonWeights = "equal", savePath = dir, key = "year2030")
  expect_setequal(basename(list.files(dir)),
                  paste0(rep(c("pde_", "pdeMap_"), each = 3), c("global", "global_winter", "global_summer"),
                         "_year2030.tif"))
})

test_that("readZipSeasons() reads <model>_seasons.csv from the model's zip, or gives NULL without one", {
  dir <- withr::local_tempdir()
  table <- data.table::data.table(season = c("winter", "summer"), days = c(200L, 165L))
  data.table::fwrite(table, file.path(dir, "m_seasons.csv"))
  data.table::fwrite(season_coefs(), file.path(dir, "m_fixed.csv"))
  withr::with_dir(dir, {
    utils::zip("with.zip", c("m_fixed.csv", "m_seasons.csv"), flags = "-q")
    utils::zip("without.zip", "m_fixed.csv", flags = "-q")
  })

  expect_equal(readZipSeasons(file.path(dir, "with.zip"), "m"), table)
  expect_null(readZipSeasons(file.path(dir, "without.zip"), "m"))
  expect_null(readZipSeasons(file.path(dir, "absent.zip"), "m"))
})
