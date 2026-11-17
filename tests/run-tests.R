## Run the module's tests, from the module root: Rscript tests/run-tests.R [file filter]
## tests/testthat/helper-source.R attaches the packages the module's R/ functions call and sources
## those functions. Used by .github/workflows/test-module.yaml.
## Tests use at most 2 cores, as CRAN asks; TEST_CORES raises that, to 4 at most, for a longer run.
## R starts OpenMP and BLAS before this script runs, so the limits must be in the environment R
## starts with: unless all four are set to that number of cores, the script runs itself again in a
## new R process that has them. It does so once (RUN_TESTS_RERUN marks the new process): an Renviron
## file that R reads at start-up, such as ~/.Renviron, can set a limit again, so the new process
## sets the limits back instead. Sourced from an interactive session, it runs the tests there
## instead, without those limits; use Rscript for them.
asked <- suppressWarnings(as.integer(Sys.getenv("TEST_CORES")))
cores <- if (is.na(asked)) 2L else min(4L, max(1L, asked))
limits <- c("OMP_THREAD_LIMIT", "OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS")
if (!interactive() && !all(Sys.getenv(limits) == as.character(cores))) {
  if (!nzchar(Sys.getenv("RUN_TESTS_RERUN"))) {
    status <- system2(
      file.path(R.home("bin"), "R"),
      shQuote(commandArgs(trailingOnly = FALSE)[-1L]),
      env = c(paste0(limits, "=", cores), "RUN_TESTS_RERUN=true")
    )
    quit(save = "no", status = status)
  }
  values <- rep(as.character(cores), length(limits))
  names(values) <- limits
  do.call(Sys.setenv, as.list(values))
}
data.table::setDTthreads(cores)
args <- commandArgs(trailingOnly = TRUE)
testthat::test_dir(
  file.path("tests", "testthat"),
  filter = if (length(args)) args[[1L]] else NULL,
  reporter = "summary",
  stop_on_failure = TRUE
)
