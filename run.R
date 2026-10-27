# Run from the project root: Rscript run.R [--legacy] [--quick] [--conformal]
args <- commandArgs(trailingOnly = TRUE)
if (length(setdiff(args, c("--legacy", "--quick", "--conformal")))) stop("Unknown argument")
required <- c("readxl", "Synth", "augsynth", "ggplot2")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("Install dependencies first (README.md): ", paste(missing, collapse = ", "))
if (!file.exists("config.R")) stop("Run from the project root")
source("config.R")
for (file in c("data", "models", "diagnostics", "export"))
  source(file.path("R", paste0(file, ".R")))
if ("--legacy" %in% args) cfg$preprocess_mode <- "legacy_replay"
if ("--quick" %in% args) cfg$run_placebos <- cfg$run_intime <- cfg$run_loo <- FALSE
if ("--conformal" %in% args) cfg$run_conformal <- TRUE
if (cfg$preprocess_mode == "legacy_replay")
  warning("legacy_replay reproduces the original preprocessing, which uses post-cutoff observations")
set.seed(cfg$seed)
directory <- file.path("results", paste(cfg$preprocess_mode,
                      format(Sys.time(), "%Y%m%d_%H%M%S"), Sys.getpid(), sep = "_"))
if (dir.exists(directory)) stop("Output directory already exists")
dir.create(directory, recursive = TRUE)
dput(cfg, file = file.path(directory, "config_used.R"))
capture.output(utils::sessionInfo(), file = file.path(directory, "sessionInfo.txt"))
write_table(data.frame(File = cfg$data_file, MD5 = unname(tools::md5sum(cfg$data_file))),
              file.path(directory, "input_fingerprint.csv"))
writeLines("INCOMPLETE", file.path(directory, "status.txt"))
raw <- read_raw_panel(cfg)
write_table(raw_missing_mask(raw), file.path(directory, "raw_missing_mask.csv"))
panel <- prepare_panel(raw, cfg)
write_table(panel, file.path(directory, "panel_used.csv"))
main <- list(SCM = fit_scm(panel, cfg), ASCM = fit_ascm(panel, cfg))
saveRDS(main, file.path(directory, "main_models.rds"))
for (result in main) export_main(result, directory, cfg)
failures <- 0L
if (cfg$run_placebos) {
  for (model in names(main)) {
    fun <- if (model == "SCM") fit_scm else fit_ascm
    result <- run_space_placebos(panel, cfg, main[[model]], fun)
    saveRDS(result, file.path(directory, paste0(tolower(model), "_placebos.rds")))
    export_placebos(result, tolower(model), directory, cfg)
    failures <- failures + sum(result$table$Status != "ok" | !is.finite(result$table$Ratio))
  }
}
if (cfg$run_intime) {
  result <- run_intime(raw, cfg)
  saveRDS(result, file.path(directory, "scm_intime_model.rds"))
  write_table(result$series, file.path(directory, "scm_intime_1935.csv"))
  write_table(gap_metrics(result$series, cfg$intime_cutoff),
                file.path(directory, "scm_intime_metrics.csv"))
  z <- result$series
  z$Series <- "SCM in-time"
  save_line_plot(z, "Gap", "Series", "SCM in-time placebo (1935)",
                  file.path(directory, "scm_intime_1935.png"), cfg$intime_cutoff)
}
if (cfg$run_loo) {
  result <- run_loo(panel, cfg, main$SCM)
  write_table(result$log, file.path(directory, "scm_loo_log.csv"))
  write_table(result$series, file.path(directory, "scm_loo_series.csv"))
  failures <- failures + sum(result$log$Status != "ok")
  save_line_plot(result$series, "Gap", "Omitted", "SCM leave-one-out (legend: omitted donor)",
                  file.path(directory, "scm_loo.png"), cfg$cutoff)
}
if (cfg$run_conformal) {
  set.seed(cfg$seed)
  inference <- summary(main$ASCM$fit, inf_type = "conformal")
  write_table(inference$att, file.path(directory, "ascm_conformal_exploratory.csv"))
  capture.output(print(inference), file = file.path(directory, "ascm_conformal_summary.txt"))
}
capture.output(utils::sessionInfo(), file = file.path(directory, "sessionInfo.txt"))
status <- if (failures) "FINISHED_WITH_DIAGNOSTIC_FAILURES" else "FINISHED_REQUESTED_STEPS"
writeLines(c(status, paste("Diagnostic failures:", failures)),
           file.path(directory, "status.txt"))
message("Outputs: ", directory)
if (failures) stop("Some diagnostics failed; see the saved logs")
