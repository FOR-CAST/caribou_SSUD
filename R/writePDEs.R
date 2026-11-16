# write each model's PDE (and map, unless `pdeMap` is NULL) to `savePath` as `pde_<model>.tif` (and
# `pdeMap_<model>.tif`), with `key` (e.g. "year2030") at the end of the file name if given; returns
# the paths written, as `pde` (and `pdeMap`), each named by model
writePDEs <- function(pde, pdeMap, savePath, key = NULL) {

  files <- list(pde = character(), pdeMap = character())

  for (mn in names(pde)) {
    suffix <- paste(c(mn, key), collapse = "_")
    files$pde[[mn]] <- file.path(savePath, paste0('pde_', suffix, ".tif"))
    terra::writeRaster(pde[[mn]], files$pde[[mn]], filetype = "GTiff", overwrite = TRUE)

    if (!is.null(pdeMap)) {
      files$pdeMap[[mn]] <- file.path(savePath, paste0('pdeMap_', suffix, ".tif"))
      terra::writeRaster(pdeMap[[mn]], files$pdeMap[[mn]], filetype = "GTiff", overwrite = TRUE)
    }
  }

  if (is.null(pdeMap)) {
    files$pdeMap <- NULL
  }

  return(files)
}
