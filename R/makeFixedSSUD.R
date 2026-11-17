# the landscape layers that stay fixed in dynamic-mode forecasts (`layers`: those the models read
# that no dynamicLayers pattern matches), taken from modelLand under their own names; stops naming
# any layer modelLand lacks
makeFixedSSUD <- function(modelLand, layers) {

  missing <- setdiff(layers, names(modelLand))

  if (length(missing)) {
    stop("Dynamic mode needs these layers, which modelLand lacks: ", paste(missing, collapse = ", "))
  }

  if (!length(layers)) return(NULL)

  fixed <- terra::rast(unname(modelLand[layers]))
  names(fixed) <- layers

  return(fixed)
}
