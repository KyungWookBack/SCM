args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("Usage: Rscript run_lambda_sensitivity.R <results directory>")
directory <- args[1]
cfg <- dget(file.path(directory, "config_used.R"))
for (file in c("data", "models", "diagnostics", "export"))
  source(file.path("R", paste0(file, ".R")))
stopifnot(requireNamespace("augsynth", quietly = TRUE))
main <- readRDS(file.path(directory, "main_models.rds"))
panel <- prepare_panel(read_raw_panel(cfg), cfg)
used <- read.csv(file.path(directory, "panel_used.csv"))
stopifnot(isTRUE(all.equal(panel, used, check.attributes = FALSE, tolerance = 1e-10)))
f <- main$ASCM$fit
index <- which.min(f$lambda_errors)
minimum_lambda <- f$lambdas[index]
threshold <- f$lambda_errors[index] + f$lambda_errors_se[index]
set.seed(cfg$seed)
result <- fit_ascm(panel, cfg, lambda = minimum_lambda)
out <- file.path(directory, "lambda_sensitivity")
dir.create(out, showWarnings = FALSE)
export_main(result, out, cfg)
saveRDS(result, file.path(out, "minimum_cv_model.rds"))
cv <- data.frame(Lambda = f$lambdas, MSE = f$lambda_errors,
                 SE = f$lambda_errors_se,
                 Minimum = seq_along(f$lambdas) == index,
                 One_SE_selected = f$lambdas == f$lambda,
                 Within_one_SE = f$lambda_errors <= threshold)
write.csv(cv, file.path(out, "cv_grid.csv"), row.names = FALSE)
initial <- f
initial$weights <- matrix(as.numeric(f$synw), ncol = 1L,
                         dimnames = dimnames(f$weights))
initial_prediction <- as.numeric(predict(initial, att = FALSE))
z <- main$ASCM$series
initial_series <- make_series(z$Year, z$Actual, initial_prediction)
write.csv(initial_series, file.path(out, "initial_ascm_series.csv"), row.names = FALSE)
series <- list(Standard_SCM = main$SCM$series, ASCM_initial = initial_series,
               ASCM_one_SE = main$ASCM$series, ASCM_min_CV = result$series)
summary <- do.call(rbind, lapply(names(series), function(name) {
  x <- series[[name]]
  final <- x[x$Year == 2013, ]
  data.frame(Model = name, Pre_RMSPE = gap_metrics(x, cfg$cutoff)$Pre_RMSPE,
             Synthetic_2013 = final$Synthetic, Gap_2013 = final$Gap,
             Negative_post_years = sum(x$Gap[x$Year >= cfg$cutoff] < 0))
}))
write.csv(summary, file.path(out, "comparison.csv"), row.names = FALSE)
capture.output(utils::sessionInfo(), file = file.path(out, "sessionInfo.txt"))
print(summary)
print(cv[c(index, which(f$lambdas == f$lambda)), ])
print(result$weights)
