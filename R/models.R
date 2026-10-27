country_id <- function(panel, country) {
  ids <- unique(panel$ID[panel$Country == country])
  if (length(ids) != 1L) stop("Expected one ID for ", country)
  ids
}

named_weights <- function(ids, values, panel, expected) {
  ids <- as.character(ids)
  if (length(ids) != length(values) || anyDuplicated(ids) ||
      !setequal(ids, as.character(expected)) || any(!is.finite(values)))
    stop("Weight IDs do not match the donor set")
  map <- unique(panel[c("ID", "Country")])
  data.frame(ID = as.integer(ids), Country = map$Country[match(ids, as.character(map$ID))],
             Weight = as.numeric(values))
}

make_series <- function(years, actual, synthetic) {
  if (length(actual) != length(years) || length(synthetic) != length(years) ||
      any(!is.finite(c(actual, synthetic)))) stop("Invalid prediction series")
  data.frame(Year = years, Actual = as.numeric(actual),
             Synthetic = as.numeric(synthetic), Gap = as.numeric(actual - synthetic))
}

fit_scm <- function(panel, cfg, treated = cfg$treated,
                    controls = setdiff(cfg$countries, treated),
                    cutoff = cfg$cutoff, blocks = cfg$gdp_blocks) {
  pre <- sort(unique(panel$Year[panel$Year < cutoff]))
  years <- sort(unique(panel$Year))
  if (length(pre) < 2L || !length(setdiff(years, pre))) stop("Need pre and post years")
  if (any(!unlist(blocks) %in% pre)) stop("GDP blocks extend beyond training years")
  treated_id <- country_id(panel, treated)
  donor_ids <- vapply(controls, function(x) country_id(panel, x), integer(1))
  dp <- Synth::dataprep(
    foo = as.data.frame(panel), predictors = cfg$predictors, predictors.op = "mean",
    time.predictors.prior = pre,
    special.predictors = lapply(blocks, function(y) list("GDP_per_Capita", y, "mean")),
    dependent = "GDP_per_Capita", unit.variable = "ID", unit.names.variable = "Country",
    time.variable = "Year", treatment.identifier = treated_id,
    controls.identifier = donor_ids, time.optimize.ssr = pre, time.plot = years
  )
  fit <- Synth::synth(data.prep.obj = dp)
  w <- named_weights(rownames(fit$solution.w), as.numeric(fit$solution.w), panel, donor_ids)
  # Match weights to matrix columns by unit ID, not by position.
  ordered_w <- w$Weight[match(colnames(dp$Y0plot), as.character(w$ID))]
  xw <- w$Weight[match(colnames(dp$X0), as.character(w$ID))]
  actual <- as.numeric(dp$Y1plot)
  synthetic <- as.numeric(dp$Y0plot %*% ordered_w)
  balance <- data.frame(Predictor = rownames(dp$X1), Actual = as.numeric(dp$X1),
                        Synthetic = as.numeric(dp$X0 %*% xw),
                        Donor_mean = rowMeans(dp$X0), V = as.numeric(fit$solution.v))
  list(model = "SCM", fit = fit, weights = w, balance = balance,
       series = make_series(as.integer(rownames(dp$Y1plot)), actual, synthetic))
}

fit_ascm <- function(panel, cfg, treated = cfg$treated,
                     controls = setdiff(cfg$countries, treated), cutoff = cfg$cutoff,
                     lambda = NULL) {
  panel <- panel[panel$Country %in% c(treated, controls), , drop = FALSE]
  panel <- panel[order(panel$ID, panel$Year), , drop = FALSE]
  panel$Trt_Stat <- as.integer(panel$Country == treated & panel$Year >= cutoff)
  form <- stats::as.formula(paste("GDP_per_Capita ~ Trt_Stat |",
                                 paste(cfg$predictors, collapse = " + ")))
  fit <- augsynth::augsynth(form = form, unit = ID, time = Year, data = panel,
                          t_int = cutoff, progfunc = "ridge", scm = TRUE, fixedeff = FALSE,
                          lambda = lambda)
  ids <- unique(panel$ID[panel$Country %in% controls])
  w <- named_weights(rownames(fit$weights), as.numeric(fit$weights), panel, ids)
  predicted <- stats::predict(fit, att = FALSE)
  years <- as.integer(fit$data$time)
  if (!identical(years, sort(unique(panel$Year))) || length(predicted) != length(years))
    stop("Unexpected ASCM time ordering; inspect the installed augsynth version")
  if (!is.null(names(predicted)) && !identical(as.integer(names(predicted)), years))
    stop("ASCM prediction labels do not match its time vector")
  actual <- panel[panel$Country == treated, c("Year", "GDP_per_Capita")]
  actual <- actual$GDP_per_Capita[match(years, actual$Year)]
  # Unweighted pre-period means; Synth's V-weighted balance is reported for SCM only.
  balance <- do.call(rbind, lapply(cfg$predictors, function(v) {
    averages <- tapply(panel[[v]][panel$Year < cutoff],
                       panel$Country[panel$Year < cutoff], mean)
    data.frame(Predictor = v, Actual = unname(averages[treated]),
               Synthetic = sum(averages[w$Country] * w$Weight),
               Donor_mean = mean(averages[controls]))
  }))
  list(model = "ASCM", fit = fit, weights = w, balance = balance,
       series = make_series(years, actual, as.numeric(predicted)))
}
