# the landscape layers a model reads: the variables in its end-of-step terms, without `_end`, e.g.
# "prop_forest_240" from "prop_forest_240_end:prop_forest_1200_end"; movement terms (sl_, ta_) and
# season terms name no `_end` variable, so are left out. `mod` is as for coef_tab()
modelLayerNames <- function(mod) {

  terms <- coef_tab(mod)$term
  terms <- terms[grepl("_end", terms)]

  vars <- unlist(lapply(terms, function(tm) {
    tryCatch(all.vars(str2lang(tm)),
             error = function(e) stop("Cannot read the model term '", tm, "' as an R expression", call. = FALSE))
  }))

  unique(sub("_end$", "", grep("_end$", vars, value = TRUE)))
}

# stops naming any layer a model reads that `layerNames` (the landscape's layers) lacks; with
# `warnCapped`, also warns when a model reads an uncapped distance, X, while the landscape has its
# capped copy, X_adj: the model may have been fit on capped values under the plain name
checkModelLayers <- function(mods, layerNames, warnCapped = FALSE) {

  for (mn in names(mods)) {
    needed <- modelLayerNames(mods[[mn]])

    missing <- setdiff(needed, layerNames)
    if (length(missing)) {
      stop("The '", mn, "' model reads these layers, which the landscape lacks: ",
           paste(missing, collapse = ", "), call. = FALSE)
    }

    capped <- needed[!grepl("_adj$", needed) & paste0(needed, "_adj") %in% layerNames]
    if (warnCapped && length(capped)) {
      warning("The '", mn, "' model reads the uncapped ", paste(capped, collapse = ", "),
              ", but the landscape also has the capped copies (", paste0(capped, "_adj", collapse = ", "),
              "). If the model was fit on capped distances, its terms should name the `_adj` layers.",
              call. = FALSE)
    }
  }

  invisible(TRUE)
}

# the grid the module builds forecast layers on: the simulation's rasterToMatch if given, else
# modelLand's own grid. Stops if a modelLand layer is not on that grid (same extent, rows and
# columns, cell size and coordinate system)
ssudGrid <- function(modelLand, rasterToMatch = NULL) {

  grid <- if (is.null(rasterToMatch)) terra::rast(modelLand[[1]]) else terra::rast(rasterToMatch)

  offGrid <- names(modelLand)[!vapply(modelLand, function(r) {
    isTRUE(terra::compareGeom(r, grid, stopOnError = FALSE, messages = FALSE))
  }, logical(1))]

  if (length(offGrid)) {
    stop("These modelLand layers are not on ",
         if (is.null(rasterToMatch)) "the grid of the first modelLand layer" else "rasterToMatch's grid",
         " (extent, rows and columns, cell size or coordinate system differ): ",
         paste(offGrid, collapse = ", "), call. = FALSE)
  }

  grid
}
