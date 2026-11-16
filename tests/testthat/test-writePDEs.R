testthat::local_edition(3)

test_that("writePDEs() writes each model's PDE and map to savePath, and returns their paths by model", {
  ud <- makePDEs(list(global = fixture_coefs()), fixture_envlayers(), studyAreaCaribou = fixture_area())
  dir <- withr::local_tempdir()

  files <- writePDEs(ud$pde, ud$pdeMap, dir, key = "year2030")
  expect_identical(files, list(pde = c(global = file.path(dir, "pde_global_year2030.tif")),
                               pdeMap = c(global = file.path(dir, "pdeMap_global_year2030.tif"))))
  expect_equal(as.vector(terra::values(terra::rast(files$pde[["global"]]))), as.vector(terra::values(ud$pde$global)))
  expect_equal(as.vector(terra::values(terra::rast(files$pdeMap[["global"]]))), as.vector(terra::values(ud$pdeMap$global)))

  expect_identical(writePDEs(ud$pde, NULL, dir), list(pde = c(global = file.path(dir, "pde_global.tif"))))
})
