# reads a model's end-of-step terms (those naming a variable ending in `_end`); each term is split at
# `:` into its parts. Returns a list:
# - `layers`: the landscape layers read, without `_end`, e.g. "prop_forest_240" from
#   "prop_forest_240_end:prop_forest_1200_end";
# - `categorical`: one row per level of a categorical layer, which glmmTMB names as the variable then
#   the level, e.g. "lc_endopen" (layer "lc", level "open");
# - `other`: the other parts of these terms, e.g. "seasonwinter" in "seasonwinter:prop_forest_240_end".
# Movement terms (sl_, ta_) and season terms name no `_end` variable, so are left out. `mod` is as
# for coef_tab()
readModelTerms <- function(mod) {

  terms <- coef_tab(mod)$term
  parts <- unique(unlist(strsplit(terms[grepl("_end", terms)], ":", fixed = TRUE)))

  layers <- character()
  categorical <- data.frame(layer = character(), level = character())
  other <- character()

  for (p in parts) {
    vars <- tryCatch(all.vars(str2lang(p)), error = function(e) NULL)

    if (!is.null(vars) && length(vars) && all(grepl("_end$", vars))) {
      layers <- c(layers, sub("_end$", "", vars))

    } else if (grepl("^[A-Za-z.][A-Za-z0-9._]*_end.", p)) {
      # a categorical layer: the variable name up to its first `_end`, then the level
      categorical <- rbind(categorical, data.frame(layer = sub("_end.*$", "", p),
                                                   level = sub("^.*?_end", "", p, perl = TRUE)))
    } else {
      other <- c(other, p)
    }
  }

  list(layers = unique(c(layers, categorical$layer)), categorical = unique(categorical),
       other = unique(other))
}

# the landscape layers a model reads (see readModelTerms())
modelLayerNames <- function(mod) {
  readModelTerms(mod)$layers
}

# stops for what the module cannot predict from yet: a model with seasons (or another variable that
# is not a landscape layer) in its end-of-step terms, or with a categorical layer; then stops naming
# any layer a model reads that `layerNames` (the landscape's layers) lacks. With `warnCapped`, also
# warns when a model reads an uncapped distance, X, while the landscape has its capped copy, X_adj:
# the model may have been fit on capped values under the plain name
checkModelLayers <- function(mods, layerNames, warnCapped = FALSE) {

  for (mn in names(mods)) {
    terms <- readModelTerms(mods[[mn]])

    if (length(terms$other)) {
      stop("The '", mn, "' model's landscape terms also hold ", paste(terms$other, collapse = ", "),
           ", which are not landscape layers (e.g. seasons). Models with seasons are not supported yet.",
           call. = FALSE)
    }

    if (nrow(terms$categorical)) {
      stop("The '", mn, "' model has categorical landscape layers, which are not supported yet: ",
           paste0(terms$categorical$layer, " (level '", terms$categorical$level, "')", collapse = ", "),
           call. = FALSE)
    }

    needed <- terms$layers

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
