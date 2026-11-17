# The forecast (dynamic mode) landscape layers, built from their names. A layer's name says what it
# is: <covariate>_<resolution m>[_adj], e.g. prop_forest_240, ts_fire_1200, dist_paved_240_adj; a
# name with no resolution (e.g. timeSinceFire) is on the sim grid.

# the patterns that send a layer to the module that forecasts it, by ecotype (dynamicLayers = NULL)
defaultDynamicLayers <- function(ecotype) {
  if (ecotype == "boreal") {
    list(forest = "^prop_(needleleaf|mixedforest)$", fire = "^timeSinceFire$",
         harvest = "^timeSinceHarvest$", disturbance = "^dist")
  } else {
    list(forest = "^prop_forest_", fire = "^ts_fire_", disturbance = "^dist_")
  }
}

# splits layer names into the covariate (`stem`), the resolution in m (`res`; NA = the sim grid) and
# whether the layer is a capped distance (`adj`)
parseLayerName <- function(x) {
  base <- sub("_adj$", "", x)
  hasRes <- grepl("_[0-9]+$", base)
  data.frame(layer = x, stem = sub("_[0-9]+$", "", base),
             res = ifelse(hasRes, suppressWarnings(as.numeric(sub("^.*_", "", base))), NA_real_),
             adj = grepl("_adj$", x))
}

# the source that forecasts each layer, named by layer: the name of the first `dynamicLayers` pattern
# it matches, or NA (static, from modelLand). Stops for a layer that matches more than one pattern
layerSources <- function(layers, dynamicLayers) {
  if (!length(dynamicLayers)) return(setNames(rep(NA_character_, length(layers)), layers))
  if (is.null(names(dynamicLayers)) || any(!nzchar(names(dynamicLayers))))
    stop("dynamicLayers must be a named list: source = pattern, e.g. list(fire = \"^ts_fire_\")",
         call. = FALSE)

  hits <- vapply(dynamicLayers, function(p) grepl(p, layers), logical(length(layers)))
  hits <- matrix(hits, nrow = length(layers), dimnames = list(layers, names(dynamicLayers)))

  twice <- layers[rowSums(hits) > 1]
  if (length(twice))
    stop("These layers match more than one dynamicLayers pattern: ", paste(twice, collapse = ", "),
         call. = FALSE)

  setNames(apply(hits, 1, function(h) if (any(h)) names(dynamicLayers)[h] else NA_character_), layers)
}

# a grid-cell map at the resolution `res` (m): unchanged if `res` is NA or the grid's own; otherwise
# `fun` (na.rm; default the mean) of the grid cells in each res x res block, copied back onto every
# cell of the block. Blocks start at the coordinate origin, as modelLand's coarse layers do (hsaCEtool), so the
# grid's xmin and ymax must be multiples of `res`
toResolution <- function(x, res, fun = "mean") {
  cell <- terra::res(x)[1]
  if (is.na(res) || isTRUE(all.equal(res, cell))) return(x)

  k <- res / cell
  if (abs(k - round(k)) > 1e-8 || k < 1)
    stop("A ", res, " m layer cannot be built from the ", cell, " m grid: ", res,
         " is not a multiple of the grid's cell size", call. = FALSE)

  e <- terra::ext(x)
  if (abs(e$xmin %% res) > 1e-6 || abs(e$ymax %% res) > 1e-6)
    stop("The grid's corner (xmin ", e$xmin, ", ymax ", e$ymax, ") is not a multiple of ", res,
         " m, so its ", res, " m blocks would not line up with modelLand's", call. = FALSE)

  k <- round(k)
  coarse <- terra::aggregate(x, fact = k, fun = fun, na.rm = TRUE)
  fine <- terra::disagg(coarse, fact = k)
  terra::crop(fine, x, extend = TRUE)
}

# the mean of the cells within `radius` m of each cell (a circle; na.rm); NA cells stay NA
circleMean <- function(x, radius) {
  w <- terra::focalMat(x, radius, type = "circle")
  w[w > 0] <- 1
  terra::focal(x, w = w, fun = "mean", na.rm = TRUE, na.policy = "omit")
}

# a 0/1 grid-cell map of LandR forest: 1 where the cell's stand has more than `minBiomass` g/m2 of
# biomass and its forest type is one of `types` ("conifer", "deciduous", "mixed"); 0 elsewhere,
# including cells with no stand
landRForestCells <- function(cohortData, pixelGroupMap, types, minBiomass = 0,
                             sppEquiv = NULL, sppEquivCol = "LandR") {
  codes <- c(conifer = 210, deciduous = 220, mixed = 230)
  bad <- setdiff(types, names(codes))
  if (length(bad))
    stop("Unknown forest types: ", paste(bad, collapse = ", "), "; use conifer, deciduous or mixed",
         call. = FALSE)

  # reclassifyCohortData() reads the map's values under the name pixelGroup
  pixelGroupMap <- terra::deepcopy(pixelGroupMap)
  names(pixelGroupMap) <- "pixelGroup"
  # a copy: reclassifyCohortData() adds columns to cohortData by reference
  args <- list(cohortData = data.table::copy(data.table::as.data.table(cohortData)),
               sppEquivCol = sppEquivCol, pixelGroupMap = pixelGroupMap)
  if (!is.null(sppEquiv)) args$sppEquiv <- sppEquiv
  stands <- do.call(reclassifyCohortData, args)

  # AGB is in Mg/ha; 1 Mg/ha = 100 g/m2
  forest <- stands[["forest type"]] %in% codes[types] & stands[["AGB (Mg/ha)"]] * 100 > minBiomass
  forest <- terra::ifel(is.na(forest), 0, forest)
  names(forest) <- "forest"
  forest
}

# the forecast of one forest layer (e.g. prop_forest_240) from 0/1 LandR forest cell maps now and at
# the start of the simulation: at its resolution, then averaged in a circle if windowRadius lists the
# resolution. "change": modelLand's layer + (LandR now - LandR at the start), kept within 0-1;
# "LandR": LandR's value alone
forestLayer <- function(name, nowCells, startCells, modelLand, windowRadius = list(), mode = "change") {
  res <- parseLayerName(name)$res
  share <- function(cells) {
    out <- toResolution(cells, res)
    r <- windowRadius[[as.character(res)]]
    if (!is.null(r)) out <- circleMean(out, r)
    out
  }

  now <- share(nowCells)
  out <- if (mode == "LandR") {
    now
  } else {
    if (is.null(modelLand[[name]]))
      stop("forestForecast 'change' needs ", name, " in modelLand", call. = FALSE)
    terra::clamp(modelLand[[name]] + now - share(startCells), 0, 1, values = TRUE)
  }
  if (!is.null(modelLand[[name]])) out <- terra::mask(out, modelLand[[name]])
  names(out) <- name
  out
}

# the forecast of time-since layers (years since fire or harvest) for `year`. The grid-cell event
# year comes from modelLand's layer of the same covariate on the grid (`baseLayer`; the event year is
# baselineYear minus its value; NA, or `tsElse` or more, = no event), replaced by the year from
# `simTimeSince` (e.g. scfm's timeSinceFire: years since an event in the simulation, NA = none) where
# that is more recent. Coarser layers take, of the grid cells' event years (na.rm), the most recent
# (`coarse` "recent") or the mean ("mean"). Then years since = year - event year; NA (no event) =
# `tsElse`
timeSinceLayers <- function(names, baseLayer, year, baselineYear, tsElse, simTimeSince = NULL,
                            coarse = "recent") {
  fun <- switch(coarse, recent = "max", mean = "mean",
                stop("fireCoarse must be 'recent' or 'mean'", call. = FALSE))

  eventYear <- baselineYear - baseLayer
  eventYear <- terra::ifel(baseLayer >= tsElse, NA, eventYear)

  if (!is.null(simTimeSince)) {
    simYear <- year - simTimeSince
    eventYear <- terra::ifel(!is.na(simYear) & (is.na(eventYear) | simYear > eventYear),
                             simYear, eventYear)
  }

  out <- lapply(names, function(n) {
    ts <- year - toResolution(eventYear, parseLayerName(n)$res, fun)
    ts <- terra::ifel(is.na(ts), tsElse, ts)
    names(ts) <- n
    ts
  })
  terra::rast(out)
}

# the modelLand layer a time-since covariate starts from: the one with the same covariate on the grid
# (its resolution = the grid's cell size, or none)
timeSinceBase <- function(stem, modelLand, cellSize) {
  info <- parseLayerName(names(modelLand))
  hit <- info$layer[info$stem == stem & !info$adj & (is.na(info$res) | info$res == cellSize)]
  if (!length(hit))
    stop("Forecasting ", stem, " layers needs ", stem, "_", cellSize, " (or ", stem,
         ") in modelLand: the event years on the grid", call. = FALSE)
  modelLand[[hit[1]]]
}

# the forecast landscape for `year`: every layer in `layers`, by its source (layerSources()). Static
# layers (no source, or a source whose objects the sim lacks) come from modelLand; `objs` holds the
# sim's objects (cohortData, pixelGroupMap, sppEquiv, timeSinceFire, forestBaseline); `p` the
# module's parameters. Returns a SpatRaster with one layer per name
buildForecastLayers <- function(layers, sources, year, modelLand, grid, objs, p) {

  info <- parseLayerName(layers)
  cellSize <- terra::res(grid)[1]
  out <- list()

  static <- layers[is.na(sources)]

  # forest, from LandR
  forest <- layers[sources %in% "forest"]
  if (length(forest)) {
    if (is.null(objs$cohortData) || is.null(objs$pixelGroupMap)) {
      message("No cohortData/pixelGroupMap in the sim: these forest layers stay as in modelLand: ",
              paste(forest, collapse = ", "))
      static <- c(static, forest)
    } else {
      checkOnGrid(objs$pixelGroupMap, grid, "pixelGroupMap")
      for (n in forest) {
        stem <- info$stem[info$layer == n]
        nowCells <- landRForestCells(objs$cohortData, objs$pixelGroupMap, forestTypesFor(stem, p$forestTypes),
                                     p$forestMinBiomass, objs$sppEquiv, p$sppEquivCol)
        startCells <- objs$forestBaseline[[stem]]
        if (p$forestForecast == "change" && is.null(startCells))
          stop("forestBaseline lacks ", stem, ", which forestForecast 'change' needs", call. = FALSE)
        out[[n]] <- forestLayer(n, nowCells, startCells, modelLand, p$windowRadius, p$forestForecast)
      }
    }
  }

  # time since fire (scfm's timeSinceFire) and harvest (no forecaster yet: ages only)
  for (src in intersect(c("fire", "harvest"), sources)) {
    these <- layers[sources %in% src]
    simTs <- if (src == "fire") objs$timeSinceFire
    if (is.null(simTs)) {
      message("No ", if (src == "fire") "timeSinceFire (scfm)" else "harvest forecast",
              " in the sim: these layers only age (no new ", src, "s): ", paste(these, collapse = ", "))
    } else {
      checkOnGrid(simTs, grid, "timeSinceFire")
    }
    for (stem in unique(info$stem[info$layer %in% these])) {
      ns <- these[info$stem[match(these, info$layer)] == stem]
      out[ns] <- as.list(timeSinceLayers(ns, timeSinceBase(stem, modelLand, cellSize), year,
                                         p$baselineYear, p$ts_else, simTs,
                                         if (is.null(p$fireCoarse)) "recent" else p$fireCoarse))
    }
  }

  # sources this module cannot build yet (e.g. disturbance: step D)
  other <- layers[!is.na(sources) & !sources %in% c("forest", "fire", "harvest")]
  if (length(other)) {
    message("These layers stay as in modelLand (no forecast for their source yet): ",
            paste(other, collapse = ", "))
    static <- c(static, other)
  }

  missing <- setdiff(static, names(modelLand))
  if (length(missing))
    stop("modelLand lacks these layers the forecast needs: ", paste(missing, collapse = ", "), call. = FALSE)
  out[static] <- modelLand[static]

  out <- terra::rast(unname(out[layers]))
  names(out) <- layers
  out
}

# the LandR forest types counted for a forest covariate (e.g. prop_forest), from forestTypes
forestTypesFor <- function(stem, forestTypes) {
  types <- forestTypes[[stem]]
  if (is.null(types))
    stop("forestTypes does not say which LandR forest types count for ", stem, call. = FALSE)
  types
}

# stops if `x` is not on the forecast grid
checkOnGrid <- function(x, grid, what) {
  if (!isTRUE(terra::compareGeom(x, grid, stopOnError = FALSE, messages = FALSE)))
    stop(what, " is not on the forecast grid (rasterToMatch, or modelLand's): extent, rows and",
         " columns, cell size or coordinate system differ", call. = FALSE)
  invisible(TRUE)
}

# the LandR forest cell maps at the start of the simulation, one per forest covariate the forecast
# builds (e.g. prop_forest), for forestForecast "change"
makeForestBaseline <- function(stems, cohortData, pixelGroupMap, p, sppEquiv = NULL) {
  setNames(lapply(stems, function(s) {
    landRForestCells(cohortData, pixelGroupMap, forestTypesFor(s, p$forestTypes), p$forestMinBiomass,
                     sppEquiv, p$sppEquivCol)
  }), stems)
}
