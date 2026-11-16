defineModule(sim, list(
  name = "caribou_SSUD",
  description = "This is a module to create a steady-state utilization distribution from an iSSA based on Potts & Schlägel 2020 ",
  keywords = c('steady-state utilization distribution', 'iSSA'),
  authors = structure(list(list(given = c("Julie", "W"), family = "Turner", role = c("aut", "cre"), email = "julwturner@gmail.com", comment = NULL)), class = "person"),
  childModules = character(0),
  version = list(caribou_SSUD = "0.0.0.9001"),
  timeframe = as.POSIXlt(c(NA, NA)),
  timeunit = "year",
  citation = list("citation.bib"),
  documentation = list("NEWS.md", "README.md", "caribou_SSUD.Rmd"),
  reqdPkgs = list("SpaDES.core (>= 2.1.5.9002)", "ggplot2", 'Require', 'reproducible', 'data.table', 'terra','sf',
                  'glmmTMB', 'broom.mixed', 'googledrive', 'viridis', 'RColorBrewer',
                  'tidyterra', 'patchwork'),
  parameters = bindrows(
    #defineParameter("paramName", "paramClass", value, min, max, "parameter description"),
    # defineParameter("disturbYear", "integer", 2020, NA, NA,
    #                 paste0("This is the year the initial disturbance layers are from",
    #                        "and used for time since variables.",
    #                        "This parameter would need to be updated if use a different year of data.")),
    defineParameter("ts_else", "integer", 200, NA, NA,
                    paste0("Years since disturbance given to cells with no recorded disturbance (e.g.",
                           " never burned) in the time-since-fire and time-since-harvest layers. Use the",
                           " value the model was fit with (hsaCEtool's `ts_nodata`; 200 for the northern",
                           " mountain models).")),
    defineParameter("histLandYears", "integer", 2010:2023, NA, NA,
                    paste0("This is the year range we use past (not simulated) landscape layers.")),
    defineParameter("simulationProcess", "character", "static", NA, NA,
                    paste0("Should the simulation use LandR (dynamic) or land cover map (static)?",
                           "defaults to static")),
    defineParameter("predictionInterval", "numeric", 5, NA, NA, "Time between predictions"),
    defineParameter("predictStartYear", "numeric", 2025, NA, NA,
                    paste0("The first year to start forecasted simulations if dynamic.",
                           " This is because we start forecasting landcovers earlier.")),
    defineParameter("predictLastYear", "logical", TRUE, NA, NA,
                    paste0("If last year of simulation is not multiple of",
                           " predictionInterval, should it predict for the last year too?")),
    defineParameter("simulationScale", "character", "global", NA, NA,
                    paste0("Which models to predict: 'global' (the global model, over studyAreaCaribou),",
                           " 'regional' (one model per region in `jurisdiction`, each over its area in",
                           " studyArea_juris), or 'both'. 'jurisdictional' is read as 'regional'.")),
    defineParameter("baselineSource", "character", NA, NA, NA,
                    paste0("A premade baseline, used when `pde` is not supplied: a folder, a .zip file,",
                           " or a URL (e.g. of a .zip on Google Drive) holding `pde_<model>.tif` (and",
                           " `pdeMap_<model>.tif` if normalizePDE) for each model, as this module writes",
                           " them. If NA, the baseline is made from modelLand and saved to outputPath.")),
    defineParameter("pdeArea", "character", c("fullArea", "regionalArea"), NA, NA,
                    paste0("The area each PDE is predicted, normalized (summed to 1) and binned into",
                           " its map over, so a map compares cells within that area. One choice for",
                           " the global model: 'fullArea' (studyAreaCaribou, the area the global model",
                           " was fit on) or 'fullReportingArea' (studyAreaReporting, which may reach",
                           " beyond the fitted area); and one for the regional models: 'regionalArea'",
                           " (the model's region in studyArea_juris) or 'regionalReportingArea' (the",
                           " part of studyAreaReporting inside the model's region). Only the choice for",
                           " the models run (simulationScale) is used. The 'Reporting' choices need",
                           " studyAreaReporting.")),
    defineParameter("normalizePDE", "logical", TRUE,
                    desc = "Whether to normalize PDE inside SSUD (FALSE for tmux workflow)"),
    defineParameter("jurisdiction", "character",c("BC","SK","MB", "ON", "NTYT", "NT"),
                    desc = "A list of jurisdictions to use for PDE creation"),
    defineParameter("ecotype", "character", "boreal",
                    desc = "Which ecotype of caribou were modelled: 'boreal' or 'northern_mountain'"),
    #####
    defineParameter(".plots", "character", "screen", NA, NA,
                    "Used by Plots function, which can be optionally used here"),
    defineParameter(".plotInitialTime", "numeric", start(sim), NA, NA,
                    "Describes the simulation time at which the first plot event should occur."),
    defineParameter(".plotInterval", "numeric", NA, NA, NA,
                    "Describes the simulation time interval between plot events."),
    defineParameter(".saveInitialTime", "numeric", NA, NA, NA,
                    "Describes the simulation time at which the first save event should occur."),
    defineParameter(".saveInterval", "numeric", NA, NA, NA,
                    "This describes the simulation time interval between save events."),
    defineParameter(".studyAreaName", "character", NA, NA, NA,
                    "Human-readable name for the study area used - e.g., a hash of the study",
                    "area obtained using `reproducible::studyAreaName()`"),

    ## .seed is optional: `list('init' = 123)` will `set.seed(123)` for the `init` event only.
    defineParameter(".seed", "list", list(), NA, NA,
                    "Named list of seeds to use for each event (names)."),
    defineParameter(".useCache", "logical", FALSE, NA, NA,
                    "Should caching of events or module be used?"),
    defineParameter("outputFolderID", "character", "https://drive.google.com/drive/folders/1CRSY_tJucL3E8VDgUYEv9WXuG1nKImH3", NA, NA,
                    "Google Drive folder ID for workflow outputs"),
    defineParameter("coefficientsModel", "character", "full_to2020", NA, NA,
                    "Name of the northern mountain iSSA model whose coefficients are read"),
    defineParameter("modelsFolderID", "character",
                    "https://drive.google.com/drive/folders/1NMhR1zwWc6jYjhKjd7o53VsSWJ9wP5ZM", NA, NA,
                    "Google Drive folder holding the northern mountain model zips")
  ),
  inputObjects = bindrows(
    #expectsInput("objectName", "objectClass", "input object description", sourceURL, ...),
    expectsInput(objectName = 'iSSAmodels', objectClass = 'list',
                 desc = 'A list of glmmTMB iSSA models by jurisdiction or global models (boreal ecotype)'),
    expectsInput(objectName = 'iSSAcoefficients', objectClass = 'data.table',
                 desc = paste('Fixed-effect coefficients of the northern mountain iSSA model: one row per',
                              'term, with columns `term` and `estimate` (others, e.g. those of hsaCEtool\'s',
                              '`<model>_fixed.csv`, are ignored). If not supplied, it is taken from',
                              '`iSSAmodels` when that is supplied, else read from `<coefficientsModel>_fixed.csv`',
                              'in `NMC_model_<coefficientsModel>.zip` in `modelsFolderID`.')),
    expectsInput("cohortData", "data.table",
                 desc = paste("`data.table` with cohort-level information on age and biomass, by `pixelGroup` and ecolocation",
                              "(i.e., `ecoregionGroup`). If supplied, it must have the following columns: `pixelGroup` (integer),",
                              "`ecoregionGroup` (factor), `speciesCode` (factor), `B` (integer in $g/m^2$), `age` (integer in years)")),
    expectsInput("pixelGroupMap", "SpatRaster",
                 desc = paste("A raster layer with `pixelGroup` IDs per pixel. Pixels are grouped" ,
                              "based on identical `ecoregionGroup`, `speciesCode`, `age` and `B` composition,",
                              "even if the user supplies other initial groupings (e.g., via the `Biomass_borealDataPrep`",
                              "module.")),
    expectsInput(objectName = "timeSinceFire", objectClass = "SpatRaster",
                 desc = "If dynamic, map of time since last burn used in model"),
    expectsInput(objectName = "modelLand", objectClass = "list",
                  desc = paste("The landscape layers the models read: a named list of SpatRasters on one",
                               "grid, each named as in the model's terms without `_end` (e.g.",
                               "`prop_forest_240` for the term `prop_forest_240_end`). The layers needed",
                               "are read from the terms, and a missing one stops the run, naming it.",
                               "Capped distances carry `_adj` (e.g. `dist_paved_240_adj`). If not",
                               "supplied, `modelLand.tif` is downloaded from outputFolderID.")),
    expectsInput(objectName = "studyAreaCaribou", objectClass = "SpatVector",
                 desc = paste("The area of the global model: a polygon of the full extent of the caribou",
                              "locations it was fit on. If not supplied, studyArea is used.")),
    expectsInput(objectName = "studyAreaReporting", objectClass = "SpatVector",
                 desc = paste("Optional: the area the results are reported for (e.g. a range buffer",
                              "clipped to a jurisdiction), a SpatVector or sf polygon. Used only when",
                              "pdeArea is 'fullReportingArea' or 'regionalReportingArea'.")),
    expectsInput(objectName = "rasterToMatch", objectClass = "SpatRaster",
                 desc = paste("Dynamic mode: the simulation's grid, e.g. the one LandR and scfm use. The",
                              "forecast layers are built on it, and every modelLand layer must be on it",
                              "(same extent, rows and columns, cell size and coordinate system), or the",
                              "run stops. If not supplied, modelLand's grid is used.")),
    expectsInput(objectName = "studyArea_juris", objectClass = "list",
                 desc = paste("Named list of SpatVectors, one area per region (e.g. jurisdiction), for the",
                              "regional models. Not needed when simulationScale is 'global'.")),
    expectsInput(objectName = "pde", objectClass = "list",
                 desc = paste("Baseline PDE (raw utility if normalizePDE is FALSE): a named list with one",
                              "SpatRaster per model ('global' and/or a region). If not supplied, read from",
                              "baselineSource, else made from modelLand.")),
    expectsInput(objectName = "pdeMap", objectClass = "list",
                 desc = "Baseline binned PDE maps, named as `pde`; NULL if normalizePDE is FALSE."),
    expectsInput(objectName = "fixedSSUD", objectClass = "SpatRaster",
                 desc = paste("Dynamic mode: the modelLand layers that do not change in forecasts. If not",
                              "supplied, taken from modelLand.")),
    expectsInput(objectName = "baselineYear", objectClass = "numeric",
                 desc = "Dynamic mode: year of the baseline landscape. Defaults to max(histLandYears).")
  ),
  outputObjects = bindrows(
    createsOutput("timeSinceFire", "SpatRaster",
                  "If dynamic, map of time since last burn used in model - with pixels that never burn receiving NA"),
    createsOutput(objectName = 'pde', objectClass = 'list',
                  desc = 'Current (pre simulation) Raw pde calculation, one SpatRaster per model'),
    createsOutput(objectName = 'pdeMap', objectClass = 'list',
                  desc = 'Current (pre simulation) binned map of pde UD for intensity of selection, one SpatRaster per model'),
    createsOutput(objectName = 'simPde', objectClass = 'list',
                  desc = 'Raw pde calculation from sim layers, by year, then one SpatRaster per model'),
    createsOutput(objectName = 'simPdeMap', objectClass = 'list',
                  desc = 'Forcast (simulated) binned map of pde UD for intensity of selection by year')

  )
))

doEvent.caribou_SSUD = function(sim, eventTime, eventType) {
  switch(
    eventType,
    init = {


      # The baseline (sim$pde, sim$pdeMap) is made in .inputObjects(), or here if it needed objects
      # that other modules make; static mode stops there
      sim <- setupBaseline(sim)

      if (P(sim)$simulationProcess == "dynamic") {
        # the forecast grid; stops if modelLand is not on it
        grid <- ssudGrid(sim$modelLand, sim$rasterToMatch)

        if(P(sim)$ecotype == 'boreal'){
          sim$timeSinceFire <- postProcess(sim$modelLand$timeSinceFire,
                                           to = grid)
        }

        if(P(sim)$ecotype == 'northern_mountain'){
          sim$timeSinceFire <- postProcess(sim$modelLand$timeSinceFire,
                                           to = grid)
        }


        # always run simLayers
        sim <- scheduleEvent(sim, P(sim)$predictStartYear, "caribou_SSUD", "simLayers")
        sim <- scheduleEvent(sim, P(sim)$predictStartYear, "caribou_SSUD", "calcSimPde")

        # the last year, unless the predictionInterval already lands on it
        if (P(sim)$predictLastYear && (end(sim) - P(sim)$predictStartYear) %% P(sim)$predictionInterval != 0) {
          sim <- scheduleEvent(sim, end(sim), "caribou_SSUD", "simLayers")
          sim <- scheduleEvent(sim, end(sim), "caribou_SSUD", "calcSimPde")
        }
      }

    },

    simLayers = {

      thisYear <- as.integer(time(sim))
      key <- paste0("year", thisYear)
      message(paste0("Simulating landscape for ", thisYear))

      template <- ssudGrid(sim$modelLand, sim$rasterToMatch)



      # ensure baseline fixed layers were created
      if (is.null(sim$fixedSSUD) || is.null(sim$baselineYear))
        stop("Missing sim$fixedSSUD / sim$baselineYear, which .inputObjects() makes in dynamic mode")

      # Fixed layers from baseline

      fixedResamp <- terra::resample(sim$fixedSSUD,  template, method = "average")
      # prop_veg  <- terra::resample(sim$fixedSSUD$prop_veg,  template, method = "average")
      # prop_wets <- terra::resample(sim$fixedSSUD$prop_wets, template, method = "average")
      #
      # distpaved   <- terra::resample(sim$fixedSSUD$distpaved,   template, method = "average")
      # distunpaved <- terra::resample(sim$fixedSSUD$distunpaved, template, method = "average")
      # distpolys   <- terra::resample(sim$fixedSSUD$distpolys,   template, method = "average")

      # Dynamic forest layers from LandR
      reclassForest <- reclassifyCohortData(
        cohortData = sim$cohortData,
        sppEquivCol = "LandR",
        pixelGroupMap = sim$pixelGroupMap,
        mixedForestCutoffs = c(0.33, 0.66)
      )

      ft <- reclassForest$`forest type`

      if(P(sim)$ecotype == 'boreal'){
        # Needleleaf
        needle_mask <- terra::classify(
          ft, rcl = matrix(c(210, 1), ncol = 2, byrow = TRUE), others = 0
        )
        prop_needleleaf <- terra::resample(needle_mask, template, method = "average")
        names(prop_needleleaf) <- "prop_needleleaf"

        # Mixedforest
        mixed_mask <- terra::classify(
          ft, rcl = matrix(c(220, 1, 230, 1), ncol = 2, byrow = TRUE),
          others = 0
        )
        prop_mixedforest <- terra::resample(mixed_mask, template, method = "average")
        names(prop_mixedforest) <- "prop_mixedforest"

        forests <- c(prop_needleleaf, prop_mixedforest)
      }

      if(P(sim)$ecotype == 'northern_mountain'){
        # all forest
        forest_mask <- terra::classify(
          ft, rcl = matrix(c(210, 1, 220, 1, 230, 1), ncol = 2, byrow = TRUE), others = 0
        )
        prop_forest_250 <- terra::resample(forest_mask, template, method = "average")
        names(prop_forest_250) <- "prop_forest_250"

        forests <- c(prop_forest_250)

      }



      message("Reclassifying forest layers")
      # Dynamic timeSinceFire from scfmSpread
      tsf <- reproducible::postProcess(sim$timeSinceFire, to = template)
      tsf[is.na(tsf)] <- P(sim)$ts_else

      message("Update timeSinceFire using scfm")

      # age forward timeSinceHarvest
      dt <- thisYear - sim$baselineYear

      if(P(sim)$ecotype == 'boreal'){
        names(tsf) <- "timeSinceFire"

        tsh <- terra::resample(sim$fixedSSUD$timeSinceHarvest0, template, method = "average")
        tsh <- tsh + dt
        tsh[is.na(tsh)] <- P(sim)$ts_else
        names(tsh) <- "timeSinceHarvest"
        message("Moving harvest forward")

        tsRasts <- c(tsf, tsh)
      }

      if(P(sim)$ecotype == 'northern_mountain'){
        names(tsf) <- "ts_fires_250"

        tsRasts <- tsf
        #TODO update poly disturbances for harvest eventually
        # tsh <- terra::resample(sim$fixedSSUD$timeSinceHarvest0, template, method = "average")
        # tsh <- tsh + dt
        # tsh[is.na(tsh)] <- P(sim)$ts_else
        # names(tsh) <- "timeSinceHarvest"
        # message("Moving harvest forward")
      }


      # Bundle into env for make_pde eval()
      simLand <- c(fixedResamp, forests, tsRasts)
      # simLand needs to be exported to workflowOutputs for normalization model

      sim$simEnv[[key]] <- list2env(
        setNames(lapply(names(simLand), \(n) simLand[[n]]), names(simLand)),
        parent = baseenv()
      )
      #message("needleleaf mean: ", terra::global(prop_needleleaf, "mean", na.rm=TRUE)[1,1])
      #message("mixed mean: ", terra::global(prop_mixedforest, "mean", na.rm=TRUE)[1,1])
      message("tsf mean: ", terra::global(tsf, "mean", na.rm=TRUE)[1,1])
      #message("tsh mean: ", terra::global(tsh, "mean", na.rm=TRUE)[1,1])


      # save layers
      outDir <- reproducible::checkPath(file.path(outputPath(sim), paste0('pde_', P(sim)$.studyAreaName), 'sims'), create = T)

      if(P(sim)$ecotype == 'boreal'){
        jur <- paste(P(sim)$jurisdiction, collapse = "")
        terra::writeRaster(simLand, file.path(outDir, paste0("pdeLayers_", jur, key, ".tif")), filetype = "GTiff", overwrite = TRUE)
      }

      if(P(sim)$ecotype == 'northern_mountain'){

        terra::writeRaster(simLand, file.path(outDir, paste0("pdeLayers_", P(sim)$.studyAreaName, "_", key, ".tif")), filetype = "GTiff", overwrite = TRUE)
      }

      sim <- scheduleEvent(sim, time(sim) + P(sim)$predictionInterval, "caribou_SSUD", "simLayers")
    },

    calcSimPde = {
      thisYear <- as.integer(time(sim))
      key <- paste0("year", thisYear)
      message(paste0("Calculating simulated PDE for: ", thisYear))
      if (is.null(sim$simEnv[[key]]))
        stop("Missing sim$simEnv[['", key, "']]. Did simLayers run first?")


      outDir <- reproducible::checkPath(file.path(outputPath(sim), paste0('pde_', P(sim)$.studyAreaName), 'sims'), create = T)


      # forecast the same models as the baseline
      mods <- pdeModels(names(sim$pde), P(sim)$ecotype, sim$iSSAmodels, sim$iSSAcoefficients)
      ud <- makePDEs(mods = mods, envLayers = sim$simEnv[[key]], studyAreaCaribou = sim$studyAreaCaribou,
                     studyArea_juris = sim$studyArea_juris, normalizePDE = P(sim)$normalizePDE,
                     savePath = outDir, key = key, studyAreaReporting = sim$studyAreaReporting,
                     pdeArea = P(sim)$pdeArea)
      sim$simPde[[key]] <- ud$pde
      sim$simPdeMap[[key]] <- ud$pdeMap


      message(paste0("Finished creating PDE for: ", thisYear))
      message(paste0("Outputs saved to: ", outDir))
      sim <- scheduleEvent(sim, time(sim) + P(sim)$predictionInterval, "caribou_SSUD", "calcSimPde")
    },

    warning(noEventWarning(sim))
  )
  return(invisible(sim))
  #return(sim)
}

.inputObjects <- function(sim) {

  cacheTags <- c(currentModule(sim), "function:.inputObjects") ## uncomment this if Cache is being used
  dPath <- asPath(getOption("reproducible.destinationPath", dataPath(sim)), 1)
  message(currentModule(sim), ": using dataPath '", dPath, "'.")

  if (length(P(sim)$ecotype) != 1 || !P(sim)$ecotype %in% c("boreal", "northern_mountain")) {
    stop("ecotype must be one of 'boreal' or 'northern_mountain'")
  }

  # the models the baseline (and forecasts) predict
  modelNames <- pdeModelNames(P(sim)$simulationScale, P(sim)$jurisdiction)
  # stops early for a pdeArea that does not fit the models run
  checkPdeArea(P(sim)$pdeArea, modelNames, suppliedElsewhere("studyAreaReporting", sim))

  # load caribou studyArea
  if (!suppliedElsewhere("studyAreaCaribou", sim)) {
    
    message("using studyArea for studyAreaCaribou maps")
    
    sim$studyAreaCaribou <- sim$studyArea
  }
  
  # load modelLand
  if (!suppliedElsewhere("modelLand", sim)) {

    message("Loading modelLand from cloud")

    modelLandFile <- prepInputs(
      targetFile = "modelLand.tif",
      destinationPath = dPath,
      fun = terra::rast,
      url = P(sim)$outputFolderID
    )

    # as.list() drops the layer names, which make_pde() needs
    sim$modelLand <- setNames(as.list(modelLandFile), names(modelLandFile))
  }

  # whether iSSAmodels was supplied, recorded before the boreal block below can fill it in
  modelsSupplied <- suppliedElsewhere("iSSAmodels", sim)

  # load iSSA models (the boreal ecotype; northern mountain uses iSSAcoefficients)
  if ("boreal" %in% P(sim)$ecotype && !modelsSupplied) {

    message("Loading iSSA models from cloud")

    modelFile <- prepInputs(
      targetFile = "iSSAmodels.RData",
      destinationPath = dPath,
      url = P(sim)$outputFolderID,
      fun = load(targetFile)
    )

    load(modelFile)

    if (!exists("iSSAmodels")) {
      stop("iSSAmodels not found in loaded file")
    }

    sim$iSSAmodels <- iSSAmodels
  }

  # load the northern mountain model's coefficients: from a supplied model, else from the cloud
  if ("northern_mountain" %in% P(sim)$ecotype && !suppliedElsewhere("iSSAcoefficients", sim)) {
    if (modelsSupplied) {
      sim$iSSAcoefficients <- coef_tab(sim$iSSAmodels)
    } else {
      message("Loading iSSA coefficients from cloud")

      modelZip <- paste0("NMC_model_", P(sim)$coefficientsModel, ".zip")
      coefficients <- prepInputs(
        # the zip's own url: given the folder's, reproducible would download every zip in it
        url = drive_file_in_folder(P(sim)$modelsFolderID, modelZip),
        archive = modelZip,
        targetFile = paste0(P(sim)$coefficientsModel, "_fixed.csv"),
        destinationPath = dPath,
        fun = data.table::fread(targetFile)
      )

      sim$iSSAcoefficients <- coef_tab(coefficients)
    }
  }

  # load jurisdictional study areas, needed only for regional models
  if (any(modelNames != "global") && !suppliedElsewhere("studyArea_juris", sim)) {
    studyareaJuris<- prepInputs(
      targetFile = paste0("studyArea_juris_", P(sim)$.studyAreaName, ".rds"),
      destinationPath = dPath,
      url = P(sim)$outputFolderID,
      fun = readStudyAreaJuris(targetFile)
    )
    sim$studyArea_juris <- studyareaJuris

  }

  # the baseline and forecast setup; init makes what needs objects that other modules make later
  ready <- !is.null(sim$modelLand) &&
    !is.null(if (P(sim)$ecotype == "boreal") sim$iSSAmodels else sim$iSSAcoefficients)
  if (ready) {
    sim <- setupBaseline(sim, objects = c("fixedSSUD", "baselineYear", "pde")[
      !c(suppliedElsewhere("fixedSSUD", sim), suppliedElsewhere("baselineYear", sim), suppliedElsewhere("pde", sim))
    ])
  }

  return(invisible(sim))
}

## The baseline and forecast setup, made from modelLand and the models: the `objects` named, each
## only if not already in sim. Called from .inputObjects() when modelLand and the models are already
## there, and from init for anything still missing (e.g. when other modules make them).
setupBaseline <- function(sim, objects = c("fixedSSUD", "baselineYear", "pde")) {

  dPath <- asPath(getOption("reproducible.destinationPath", dataPath(sim)), 1)
  modelNames <- pdeModelNames(P(sim)$simulationScale, P(sim)$jurisdiction)

  # forecast setup: the landscape layers that stay fixed, and the year they are from
  if (P(sim)$simulationProcess == "dynamic") {

    if ("fixedSSUD" %in% objects && is.null(sim$fixedSSUD)) {
      sim$fixedSSUD <- makeFixedSSUD(sim$modelLand, P(sim)$ecotype)
    }

    if ("baselineYear" %in% objects && is.null(sim$baselineYear)) {
      sim$baselineYear <- max(P(sim)$histLandYears)
    }
  }

  # baseline PDEs and maps: from a premade baseline if one is given, else made from modelLand
  if ("pde" %in% objects && is.null(sim$pde)) {

    if (!is.na(P(sim)$baselineSource)) {
      message("Reading the premade baseline from ", P(sim)$baselineSource)
      ud <- readBaseline(baselineDir(P(sim)$baselineSource, dPath), modelNames, P(sim)$normalizePDE)

    } else {
      message("Building baseline PDEs for: ", paste(modelNames, collapse = ", "))

      envlayers <- list2env(setNames(lapply(names(sim$modelLand), function(n) sim$modelLand[[n]]), names(sim$modelLand)),
                            parent = baseenv())
      outDir <- reproducible::checkPath(file.path(outputPath(sim), paste0('pde_', P(sim)$.studyAreaName)), create = T)

      mods <- pdeModels(modelNames, P(sim)$ecotype, sim$iSSAmodels, sim$iSSAcoefficients)
      # stops naming any layer the models read that modelLand lacks; warns if one may need `_adj`
      checkModelLayers(mods, names(sim$modelLand), warnCapped = TRUE)

      ud <- makePDEs(mods = mods,
                     envLayers = envlayers, studyAreaCaribou = sim$studyAreaCaribou,
                     studyArea_juris = sim$studyArea_juris, normalizePDE = P(sim)$normalizePDE,
                     savePath = outDir, studyAreaReporting = sim$studyAreaReporting,
                     pdeArea = P(sim)$pdeArea)
      message("Baseline PDEs saved to: ", outDir)
    }

    sim$pde <- ud$pde
    sim$pdeMap <- ud$pdeMap
  }

  return(invisible(sim))
}

ggplotFn <- function(data, ...) {
  ggplot2::ggplot(data, ggplot2::aes(TheSample)) +
    ggplot2::geom_histogram(...)
}
