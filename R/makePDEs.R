#' @title make caribou PDEs for each model, over each model's area
#' @export
#' @author Julie W. Turner
#' @return a list with `pde` (the normalized PDE, or the raw utility if `normalizePDE` is FALSE) and
#' `pdeMap` (the binned maps, NULL if `normalizePDE` is FALSE), each a list with one raster per map,
#' named as `mods` (for a model with seasons, see below). The global model covers `studyAreaCaribou`, and each regional model its area in
#' `studyArea_juris`, unless `pdeArea` picks the reporting area (see `getStudyAreaForModel()`): each
#' PDE is normalized and binned within its area. If `savePath` is given, each PDE (and map) is
#' also written there as `pde_<map>.tif` (and `pdeMap_<map>.tif`), with `key` (e.g. "year2030")
#' at the end of the file name if given, and the list also has `files`: the paths written, as `pde`
#' (and `pdeMap`), each named by map. Stops naming any layer a model reads that `envLayers` lacks.
#' A model with seasons (terms such as `seasonwinter:prop_forest_240_end`) gives one map per season in
#' `seasonMaps`, named `<model>_<season>` (e.g. "global_winter"), and a full-year map named as the
#' model: the seasons in `fullYear`, each season's PDE weighted by `seasonWeights` (see
#' fullYearWeights(); `seasonTable` gives the days per season), so it still sums to 1. NULL = all the
#' model's seasons, character(0) = none (see seasonChoice()). The full-year map needs `normalizePDE`.

makePDEs <- function(mods, envLayers, studyAreaCaribou = NULL, studyArea_juris = NULL, normalizePDE = TRUE,
                     savePath = NULL, key = NULL, studyAreaReporting = NULL,
                     pdeArea = c("fullArea", "regionalArea"), seasonMaps = NULL, fullYear = NULL,
                     seasonWeights = "length", seasonTable = NULL) {

  checkModelLayers(mods, ls(envLayers))

  UDlist <- list()

  for (mn in names(mods)) {

    sa <- getStudyAreaForModel(
      modelName = mn,
      studyArea_juris = studyArea_juris,
      studyAreaCaribou = studyAreaCaribou,
      studyAreaReporting = studyAreaReporting,
      pdeArea = pdeArea
    )

    seasons <- seasonChoice(mn, modelSeasons(mods[[mn]]), seasonMaps, fullYear)

    if (!length(seasons$maps) && !length(seasons$fullYear)) {
      UDlist[[mn]] <- mod2UD(
        mod = mods[[mn]],
        envlayers = envLayers,
        studyArea = sa,
        normalize = normalizePDE
      )
      next
    }

    if (length(seasons$fullYear) && !normalizePDE) {
      stop("The full-year map of the '", mn, "' model is made from the seasons' PDEs, so needs",
           " normalizePDE = TRUE; or use fullYear = character(0)", call. = FALSE)
    }
    # checked before the seasons' PDEs are made
    w <- if (length(seasons$fullYear)) fullYearWeights(seasons$fullYear, seasonWeights, seasonTable)

    bySeason <- lapply(setNames(nm = union(seasons$fullYear, seasons$maps)), function(s) {
      mod2UD(
        mod = seasonCoefs(mods[[mn]], s),
        envlayers = envLayers,
        studyArea = sa,
        normalize = normalizePDE
      )
    })

    # the full year: the seasons' PDEs, weighted
    if (length(w)) {
      pde <- Reduce(`+`, lapply(names(w), function(s) bySeason[[s]]$pde * w[[s]]))
      UDlist[[mn]] <- list(pde = pde, map = make_pde_map(pde))
    }

    for (s in seasons$maps) {
      UDlist[[paste0(mn, "_", s)]] <- bySeason[[s]]
    }
  }

  if (normalizePDE) {
    pde <- lapply(UDlist, `[[`, "pde")
    # as.numeric() drops the class labels, which GeoTIFF would keep only in a separate .aux.xml file
    pdeMap <- lapply(UDlist, function(x) as.numeric(x$map))
  } else {
    pde <- lapply(UDlist, `[[`, "utility")
    pdeMap <- NULL
  }

  out <- list(pde = pde, pdeMap = pdeMap)

  # save outputs, and return the paths written
  if (!is.null(savePath)) {
    out$files <- writePDEs(pde, pdeMap, savePath, key)
  }

  return(out)
}
