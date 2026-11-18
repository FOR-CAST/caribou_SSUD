# whether each part of a term (split at `:`) is a season, as glmmTMB names the levels of the
# `season` factor: `season<name>`, e.g. "seasonwinter" (not a layer, which ends in `_end`)
isSeasonPart <- function(p) {
  grepl("^season.", p) & !grepl("_end", p, fixed = TRUE)
}

# the seasons in a model's landscape terms, e.g. "winter" from "seasonwinter:prop_forest_240_end";
# none for a model without seasons. `mod` is as for coef_tab()
modelSeasons <- function(mod) {
  readModelTerms(mod)$seasons
}

# a season model's coefficients for one season, as a model without seasons: the terms without a
# season (shared by all seasons), and this season's terms with the season taken out (e.g.
# "seasonwinter:prop_forest_240_end" becomes "prop_forest_240_end"); other seasons' terms are dropped.
# `mod` is as for coef_tab()
seasonCoefs <- function(mod, season) {

  coefs <- coef_tab(mod)
  parts <- strsplit(coefs$term, ":", fixed = TRUE)

  keep <- vapply(parts, function(p) {
    s <- p[isSeasonPart(p)]
    !length(s) || identical(s, paste0("season", season))
  }, logical(1))

  coefs$term <- vapply(parts, function(p) paste(p[!isSeasonPart(p)], collapse = ":"), character(1))

  coefs[keep & nzchar(coefs$term)]
}

# the maps to make for a model with `seasons` (see modelSeasons()): `maps`, the seasons that get a
# map of their own, as `seasonMaps` picks, and `fullYear`, the seasons combined into the full-year
# map, as `fullYear` picks; NULL = all the model's seasons, character(0) = none. A model without
# seasons gets one map, so takes neither
seasonChoice <- function(modelName, seasons, seasonMaps = NULL, fullYear = NULL) {

  if (!length(seasons)) {
    if (length(seasonMaps) || length(fullYear)) {
      stop("The '", modelName, "' model has no seasons, so takes no seasonMaps or fullYear", call. = FALSE)
    }
    return(list(maps = character(), fullYear = character()))
  }

  pick <- function(x, what) {
    if (is.null(x)) return(seasons)
    bad <- setdiff(x, seasons)
    if (length(bad)) {
      stop(what, " names seasons the '", modelName, "' model does not have: ", paste(bad, collapse = ", "),
           ". Its seasons: ", paste(seasons, collapse = ", "), call. = FALSE)
    }
    unique(as.character(x))
  }

  out <- list(maps = pick(seasonMaps, "seasonMaps"), fullYear = pick(fullYear, "fullYear"))

  if (!length(out$maps) && !length(out$fullYear)) {
    stop("seasonMaps and fullYear are both empty, so the '", modelName, "' model gets no map", call. = FALSE)
  }

  out
}

# the names of the maps made from `mods` (named as in pdeModelNames()): a model without seasons
# gives its own name; a model with seasons gives its name for the full-year map, if any, then
# `<model>_<season>` for each season map (see seasonChoice())
pdeMapNames <- function(mods, seasonMaps = NULL, fullYear = NULL) {
  unlist(lapply(names(mods), function(mn) {
    ch <- seasonChoice(mn, modelSeasons(mods[[mn]]), seasonMaps, fullYear)
    if (!length(ch$maps) && !length(ch$fullYear)) return(mn)
    c(if (length(ch$fullYear)) mn, if (length(ch$maps)) paste0(mn, "_", ch$maps))
  }), use.names = FALSE)
}

# the weight of each season in the full-year map, summing to 1, named by season: `weights` is
# "length" (days per season, from `seasonTable`, the model's season table as hsaCEtool's
# `<model>_seasons.csv` gives it, with columns `season` and `days`), "equal", or numbers named by
# season (e.g. c(winter = 2, summer = 1)), which are scaled to sum to 1. One season needs no weights
fullYearWeights <- function(seasons, weights = "length", seasonTable = NULL) {

  if (length(seasons) == 1) {
    return(setNames(1, seasons))
  }

  if (is.character(weights)) {
    if (length(weights) != 1 || !weights %in% c("length", "equal")) {
      stop("seasonWeights must be 'length', 'equal' or numbers named by season", call. = FALSE)
    }

    if (weights == "equal") {
      w <- rep(1, length(seasons))

    } else {
      if (is.null(seasonTable)) {
        stop("seasonWeights = 'length' needs the model's season table (iSSAseasons), which was not",
             " supplied and is not in the model's zip. Supply it, or use seasonWeights = 'equal' or",
             " numbers named by season", call. = FALSE)
      }
      miss <- setdiff(c("season", "days"), names(seasonTable))
      if (length(miss)) {
        stop("The season table (iSSAseasons) lacks column(s): ", paste(miss, collapse = ", "), call. = FALSE)
      }
      w <- seasonTable$days[match(seasons, seasonTable$season)]
      if (anyNA(w)) {
        stop("The season table (iSSAseasons) has no days for: ", paste(seasons[is.na(w)], collapse = ", "),
             call. = FALSE)
      }
    }

  } else {
    if (!is.numeric(weights) || is.null(names(weights))) {
      stop("seasonWeights must be 'length', 'equal' or numbers named by season", call. = FALSE)
    }
    miss <- setdiff(seasons, names(weights))
    if (length(miss)) {
      stop("seasonWeights has no weight for: ", paste(miss, collapse = ", "), call. = FALSE)
    }
    w <- unname(weights[seasons])
  }

  if (anyNA(w) || any(w < 0) || sum(w) <= 0) {
    stop("Season weights must be zero or more, and not all zero", call. = FALSE)
  }

  setNames(w / sum(w), seasons)
}

# the model's season table (hsaCEtool's `<model>_seasons.csv`) from the model's zip, or NULL if the
# zip does not exist or has none (models fit before hsaCEtool wrote it)
readZipSeasons <- function(zip, model) {

  file <- paste0(model, "_seasons.csv")

  if (!file.exists(zip) || !file %in% basename(utils::unzip(zip, list = TRUE)$Name)) {
    return(NULL)
  }

  dir <- tempfile("seasons")
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  inZip <- utils::unzip(zip, list = TRUE)$Name
  utils::unzip(zip, files = inZip[basename(inZip) == file][1], exdir = dir, junkpaths = TRUE)

  data.table::fread(file.path(dir, file))
}
