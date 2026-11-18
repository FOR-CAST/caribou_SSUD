caribou_SSUD Manual
================
Version 0.0.0.9001, last updated: 2026-11-18

- [caribou_SSUD Module](#caribou_ssud-module)
  - [Module Overview](#module-overview)
    - [Module summary](#module-summary)
    - [Module inputs and parameters](#module-inputs-and-parameters)
    - [Events](#events)
    - [Plotting](#plotting)
    - [Saving](#saving)
    - [Module outputs](#module-outputs)
    - [Links to other modules](#links-to-other-modules)
    - [Getting help](#getting-help)

# caribou_SSUD Module

<!-- the following are text references used in captions for LaTeX compatibility -->

[![made-with-Markdown](https://img.shields.io/badge/Made%20with-Markdown-1f425f.png)](https://commonmark.org)

<!-- if knitting to pdf remember to add the pandoc_args: ["--extract-media", "."] option to yml in order to get the badge images -->

#### Authors:

Julie W Turner <julwturner@gmail.com> \[aut, cre\]
<!-- ideally separate authors with new lines, '\n' not working -->

## Module Overview

### Module summary

Provide a brief summary of what the module does / how to use the module.

Module documentation should be written so that others can use your
module. This is a template for module documentation, and should be
changed to reflect your module.

### Module inputs and parameters

Describe input data required by the module and how to obtain it (e.g.,
directly from online sources or supplied by other modules) If
`sourceURL` is specified, `downloadData("caribou_SSUD", "..")` may be
sufficient. Table <a href="#tab:moduleInputs-caribou-SSUD">1</a> shows
the full list of module inputs.

| objectName | objectClass | desc | sourceURL |
|:---|:---|:---|:---|
| iSSAmodels | list | A list of glmmTMB iSSA models by jurisdiction or global models (boreal ecotype) | NA |
| iSSAcoefficients | data.table | Fixed-effect coefficients of the northern mountain iSSA model: one row per term, with columns `term` and `estimate` (others, e.g. those of hsaCEtool’s `<model>_fixed.csv`, are ignored). If not supplied, it is taken from `iSSAmodels` when that is supplied, else read from `<coefficientsModel>_fixed.csv` in `NMC_model_<coefficientsModel>.zip` in `modelsFolderID`. | NA |
| iSSAseasons | data.table | For a model with seasons and seasonWeights ‘length’: the model’s season table, one row per season, with columns `season` (as in the terms, e.g. `winter` for `seasonwinter`) and `days` (days per season), as hsaCEtool’s `<model>_seasons.csv` gives it. If not supplied, read from `<coefficientsModel>_seasons.csv` in the model’s zip, when it has one (models fit before hsaCEtool wrote this table do not). | NA |
| cohortData | data.table | `data.table` with cohort-level information on age and biomass, by `pixelGroup` and ecolocation (i.e., `ecoregionGroup`). If supplied, it must have the following columns: `pixelGroup` (integer), `ecoregionGroup` (factor), `speciesCode` (factor), `B` (integer in $g/m^2$), `age` (integer in years) | NA |
| pixelGroupMap | SpatRaster | A raster layer with `pixelGroup` IDs per pixel. Pixels are grouped based on identical `ecoregionGroup`, `speciesCode`, `age` and `B` composition, even if the user supplies other initial groupings (e.g., via the `Biomass_borealDataPrep` module. | NA |
| timeSinceFire | SpatRaster | Dynamic mode: years since each cell last burned in the simulation, NA where it has not burned (as scfmSpread keeps it), on the forecast grid. Fire layers take a cell’s fire year from it where that is more recent than modelLand’s. If absent, fire layers only age. | NA |
| sppEquiv | data.table | Dynamic mode: LandR’s species-equivalence table, with a `Type` column (Conifer/Deciduous) and the species codes in column sppEquivCol. If absent, LandR::sppEquivalencies_CA. | NA |
| forestBaseline | list | Dynamic mode, forestForecast ‘change’: LandR’s forest at the start of the simulation, a named list of 0/1 SpatRasters on the forecast grid, one per forest covariate (e.g. prop_forest). If not supplied, made in init from cohortData and pixelGroupMap. | NA |
| modelLand | list | The landscape layers the models read: a named list of SpatRasters on one grid (or one multi-layer SpatRaster, made into that list), each named as in the model’s terms without `_end` (e.g. `prop_forest_240` for the term `prop_forest_240_end`). The layers needed are read from the terms, and a missing one stops the run, naming it. Capped distances carry `_adj` (e.g. `dist_paved_240_adj`). If not supplied, `modelLand.tif` is downloaded from outputFolderID. | NA |
| studyAreaCaribou | SpatVector | The area of the global model: a polygon of the full extent of the caribou locations it was fit on. If not supplied, studyArea is used. | NA |
| studyAreaReporting | SpatVector | Optional: the area the results are reported for (e.g. a range buffer clipped to a jurisdiction), a SpatVector or sf polygon. Used only when pdeArea is ‘fullReportingArea’ or ‘regionalReportingArea’. | NA |
| rasterToMatch | SpatRaster | Dynamic mode: the simulation’s grid, e.g. the one LandR and scfm use. The forecast layers are built on it, and every modelLand layer must be on it (same extent, rows and columns, cell size and coordinate system), or the run stops. If not supplied, modelLand’s grid is used. | NA |
| studyArea_juris | list | Named list of SpatVectors, one area per region (e.g. jurisdiction), for the regional models. Not needed when simulationScale is ‘global’. | NA |
| pde | list | Baseline PDE (raw utility if normalizePDE is FALSE): a named list with one SpatRaster per model (‘global’ and/or a region), or for a model with seasons, per season map and the full-year map (see seasonMaps, fullYear). If not supplied, read from baselineSource, else made from modelLand. | NA |
| pdeMap | list | Baseline binned PDE maps, named as `pde`; NULL if normalizePDE is FALSE. | NA |
| fixedSSUD | SpatRaster | Dynamic mode: the layers the models read that do not change in forecasts (those no dynamicLayers pattern matches), named as in the terms. If not supplied, taken from modelLand. | NA |

<span id="tab:moduleInputs-caribou-SSUD"></span>Table 1: List of
*caribou_SSUD* input objects and their description.

Provide a summary of user-visible parameters (Table
<a href="#tab:moduleParams-caribou-SSUD">2</a>)

| paramName | paramClass | default | min | max | paramDesc | cacheKey |
|:---|:---|:---|:---|:---|:---|:---|
| ts_else | integer | 200 | NA | NA | Years since disturbance given to cells with no recorded disturbance (e.g. never burned) in the time-since-fire and time-since-harvest layers. Use the value the model was fit with (hsaCEtool’s `ts_nodata`; 200 for the northern mountain models). | TRUE |
| baselineYear | integer | 2025 | NA | NA | The year modelLand describes: its time-since layers (e.g. ts_fire_240) count years back from it. Forecasts count from it too, and the simulation should start in it (LandR’s stands at the start are compared with modelLand’s). 2025 for the northern mountain modelLand; 2022 for the boreal NWT one. | TRUE |
| noEventYear | list | NA, NA | NA | NA | How modelLand’s time-since layers store cells with no fire (or harvest), by source: NA = such cells are NA (or ts_else or more), and forecasts give them ts_else; a year = they hold the years since that stand-in year (e.g. 1900: 122 with baselineYear 2022), and forecasts give them the years since it (year - noEventYear), as the model was fit. Either way they are left out of coarser layers’ fire years. E.g. the boreal NWT modelLand (baselineYear 2022): list(fire = 1900, harvest = 1900). | TRUE |
| dynamicLayers | list |  | NA | NA | Dynamic mode: which of the layers the models read are forecast, and from what: a named list, source = a regular expression matched against layer names. Sources: ‘forest’ (LandR’s cohortData and pixelGroupMap), ‘fire’ (scfm’s timeSinceFire), ‘harvest’ (no forecaster yet: the layer only ages) and ‘disturbance’ (not yet forecast: kept as in modelLand). A layer that matches no pattern stays as in modelLand (e.g. vegetation). NULL = the ecotype’s default: northern mountain list(forest = ‘^prop_forest\_’, fire = ‘^ts_fire\_’, harvest = ‘^ts_harv(est)?*’, disturbance = ’^dist*’); boreal list(forest = ‘^prop\_(needleleaf\|mixedforest)$', fire = '^timeSinceFire$’, harvest = ‘^timeSinceHarvest\$’, disturbance = ‘^dist’). | TRUE |
| windowRadius | list | 500 | NA | NA | Dynamic mode: radius (m) of the circle forest shares are averaged in, by layer resolution (m), as hsaCEtool’s `window_m`: list(‘240’ = 500) = a 240 m layer (e.g. prop_forest_240) is the mean of the 240 m cells within 500 m. A resolution not listed gets no circle (e.g. prop_forest_1200 is the mean of the 240 m cells in each 1200 m block). Fire layers get no circle. | TRUE |
| fireCoarse | character | recent | NA | NA | Dynamic mode: how a fire layer coarser than the grid (e.g. ts_fire_1200 on a 240 m grid) is built from the grid cells’ fire years (unburned cells left out): ‘recent’ = the most recent fire in the block, as modelLand’s layers and the current northern mountain models (full_to2020) were made; ‘mean’ = the mean fire year, as hsaCEtool will make them. Use the rule the model was fit with. TODO: default to ‘mean’ once the models are refit. | TRUE |
| harvestCoarse | character | recent | NA | NA | Dynamic mode: as fireCoarse, for harvest layers coarser than the grid (e.g. ts_harv_1200): ‘recent’ = the most recent harvest in the block; ‘mean’ = the mean harvest year (unharvested cells left out). Use the rule the model was fit with. | TRUE |
| forestMinBiomass | numeric | 0 | 0 | NA | Dynamic mode: a LandR cell is forest when its stand has more than this much tree biomass (g/m2, LandR’s unit for B); 0 = any tree biomass. | TRUE |
| forestForecast | character | change | NA | NA | Dynamic mode: how forest layers are forecast. ‘change’ = modelLand’s layer plus LandR’s change since the start of the simulation (LandR now minus LandR at the start), kept within 0-1; ‘LandR’ = LandR’s value alone. | TRUE |
| forestTypes | list | c(“conif…. | NA | NA | Dynamic mode: the LandR forest types each forest covariate counts, by covariate (the layer name without its resolution). Types: ‘conifer’ (conifer share of the stand’s biomass at or above the upper mixedForestCutoff, 0.66), ‘mixed’ (between the cutoffs) and ‘deciduous’ (at or below the lower cutoff, 0.33). | TRUE |
| sppEquivCol | character | LandR | NA | NA | Dynamic mode: the column of sppEquiv that holds cohortData’s species codes, used to tell conifers from broadleaf species. | TRUE |
| simulationProcess | character | static | NA | NA | Should the simulation use LandR (dynamic) or land cover map (static)?defaults to static | TRUE |
| predictionInterval | numeric | 5 | NA | NA | Time between predictions | TRUE |
| predictStartYear | numeric | 2025 | NA | NA | The first year to start forecasted simulations if dynamic. This is because we start forecasting landcovers earlier. | TRUE |
| predictLastYear | logical | TRUE | NA | NA | If last year of simulation is not multiple of predictionInterval, should it predict for the last year too? | TRUE |
| simulationScale | character | global | NA | NA | Which models to predict: ‘global’ (the global model, over studyAreaCaribou), ‘regional’ (one model per region in `jurisdiction`, each over its area in studyArea_juris), or ‘both’. ‘jurisdictional’ is read as ‘regional’. | TRUE |
| baselineSource | character | NA | NA | NA | A premade baseline, used when `pde` is not supplied: a folder, a .zip file, or a URL (e.g. of a .zip on Google Drive) holding `pde_<model>.tif` (and `pdeMap_<model>.tif` if normalizePDE) for each model, as this module writes them. If NA, the baseline is made from modelLand and saved to outputPath. | TRUE |
| pdeArea | character | fullArea…. | NA | NA | The area each PDE is predicted, normalized (summed to 1) and binned into its map over, so a map compares cells within that area. One choice for the global model: ‘fullArea’ (studyAreaCaribou, the area the global model was fit on) or ‘fullReportingArea’ (studyAreaReporting, which may reach beyond the fitted area); and one for the regional models: ‘regionalArea’ (the model’s region in studyArea_juris) or ‘regionalReportingArea’ (the part of studyAreaReporting inside the model’s region). Only the choice for the models run (simulationScale) is used. The ‘Reporting’ choices need studyAreaReporting. | TRUE |
| seasonMaps | character |  | NA | NA | For a model with seasons (terms such as `seasonwinter:prop_forest_240_end`): the seasons that each get a map of their own, named `<model>_<season>` (e.g. global_winter, written as pde_global_winter.tif). A season’s map uses the terms without a season and that season’s terms. NULL = all the model’s seasons; character(0) = none. Models without seasons ignore it. | TRUE |
| fullYear | character |  | NA | NA | For a model with seasons: the seasons combined into one full-year map, named as the model (e.g. global, written as pde_global.tif): the seasons’ PDEs, weighted by seasonWeights, so it still sums to 1. NULL = all the model’s seasons; character(0) = no full-year map. Needs normalizePDE. Models without seasons ignore it. | TRUE |
| seasonWeights | characte…. | length | NA | NA | How the seasons in fullYear are weighted: ‘length’ = by days per season, from iSSAseasons; ‘equal’; or numbers named by season (e.g. c(winter = 2, summer = 1)), scaled to sum to 1. | TRUE |
| normalizePDE | logical | TRUE | NA | NA | Whether to normalize PDE inside SSUD (FALSE for tmux workflow) | TRUE |
| jurisdiction | character | BC, SK, …. | NA | NA | A list of jurisdictions to use for PDE creation | TRUE |
| ecotype | character | boreal | NA | NA | Which ecotype of caribou were modelled: ‘boreal’ or ‘northern_mountain’ | TRUE |
| .plots | character | screen | NA | NA | Used by Plots function, which can be optionally used here | TRUE |
| .plotInitialTime | numeric | 0 | NA | NA | Describes the simulation time at which the first plot event should occur. | TRUE |
| .plotInterval | numeric | NA | NA | NA | Describes the simulation time interval between plot events. | TRUE |
| .saveInitialTime | numeric | NA | NA | NA | Describes the simulation time at which the first save event should occur. | TRUE |
| .saveInterval | numeric | NA | NA | NA | This describes the simulation time interval between save events. | TRUE |
| .studyAreaName | character | NA | NA | NA | Human-readable name for the study area used - e.g., a hash of the studyarea obtained using `reproducible::studyAreaName()` | TRUE |
| .seed | list |  | NA | NA | Named list of seeds to use for each event (names). | TRUE |
| .useCache | logical | FALSE | NA | NA | Should caching of events or module be used? | TRUE |
| outputFolderID | character | <https://>…. | NA | NA | Google Drive folder ID for workflow outputs | TRUE |
| coefficientsModel | character | full_to2020 | NA | NA | Name of the northern mountain iSSA model whose coefficients are read | TRUE |
| modelsFolderID | character | <https://>…. | NA | NA | Google Drive folder holding the northern mountain model zips | TRUE |

<span id="tab:moduleParams-caribou-SSUD"></span>Table 2: List of
*caribou_SSUD* parameters and their description.

### Events

Describe what happens for each event type.

### Plotting

Write what is plotted.

### Saving

Write what is saved.

### Module outputs

Description of the module outputs (Table
<a href="#tab:moduleOutputs-caribou-SSUD">3</a>).

| objectName | objectClass | desc |
|:---|:---|:---|
| fixedSSUD | SpatRaster | Dynamic mode: the layers that do not change in forecasts (see inputs) |
| forestBaseline | list | Dynamic mode: LandR’s forest at the start of the simulation (see inputs) |
| pde | list | Current (pre simulation) Raw pde calculation, one SpatRaster per map (see the input `pde`) |
| pdeMap | list | Current (pre simulation) binned map of pde UD for intensity of selection, one SpatRaster per map |
| simPde | list | Raw pde calculation from sim layers, by year, then one SpatRaster per map, as `pde` |
| simPdeMap | list | Forcast (simulated) binned map of pde UD for intensity of selection by year |

<span id="tab:moduleOutputs-caribou-SSUD"></span>Table 3: List of
*caribou_SSUD* outputs and their description.

### Links to other modules

Describe any anticipated linkages to other modules, such as modules that
supply input data or do post-hoc analysis.

### Getting help

- provide a way for people to obtain help (e.g., module repository
  issues page)
