# register the PDE files makePDEs() wrote (its `files`) as saved outputs of the simulation, so
# outputs(sim) lists them, e.g. for a workflow that collects a run's saved files; `objectNames`
# gives the object each set of files holds, e.g. c(pde = "simPde", pdeMap = "simPdeMap") for a
# forecast year
registerPdeFiles <- function(sim, files, objectNames = c(pde = "pde", pdeMap = "pdeMap")) {

  for (nm in names(files)) {
    fl <- unname(files[[nm]])

    if (length(fl)) {
      sim <- SpaDES.core::registerOutputs(filename = fl, sim = sim, objectName = objectNames[[nm]],
                                          fun = "terra::writeRaster")
    }
  }

  return(sim)
}
