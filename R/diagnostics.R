gap_metrics <- function(series, cutoff) {
  pre <- series$Gap[series$Year < cutoff]
  post <- series$Gap[series$Year >= cutoff]
  if (!length(pre) || !length(post) || any(!is.finite(c(pre, post))))
    stop("Incomplete gap series")
  pre_mspe <- mean(pre^2)
  post_mspe <- mean(post^2)
  data.frame(Pre_n = length(pre), Post_n = length(post), Pre_MSPE = pre_mspe,
             Post_MSPE = post_mspe, Pre_RMSPE = sqrt(pre_mspe),
             Ratio = if (pre_mspe > 0) post_mspe / pre_mspe else NA_real_)
}

placebo_rank <- function(table, treated, k = Inf) {
  target <- table[table$Country == treated, , drop = FALSE]
  stopifnot(nrow(target) == 1L)
  if (anyDuplicated(table$Country) || is.na(k) || k < 1) stop("Invalid placebo rank inputs")
  finite <- table$Status == "ok" & is.finite(table$Ratio) & is.finite(table$Pre_RMSPE)
  # A failed or non-finite placebo makes the rank undefined rather than shrinking the reference set.
  complete <- all(finite)
  target_valid <- target$Status == "ok" && is.finite(target$Ratio) &&
    is.finite(target$Pre_RMSPE) && target$Pre_RMSPE > 0
  eligible <- if (target_valid) finite & table$Pre_RMSPE <= k * target$Pre_RMSPE else
    rep(FALSE, nrow(table))
  n <- sum(eligible)
  rank_fraction <- if (complete && n > 0 && is.finite(target$Ratio)) {
    mean(table$Ratio[eligible] >= target$Ratio)
  } else NA_real_
  data.frame(RMSPE_multiplier = k, Expected_units = nrow(table),
             Valid_units = sum(finite), Included_units = n,
             Rank_fraction = rank_fraction, Complete = complete)
}

run_space_placebos <- function(panel, cfg, main, fit_fun) {
  rows <- list(cbind(data.frame(Country = cfg$treated, Status = "ok", Error = ""),
                     gap_metrics(main$series, cfg$cutoff)))
  paths <- list(data.frame(Country = cfg$treated, main$series))
  for (country in setdiff(cfg$countries, cfg$treated)) {
    message(main$model, " placebo: ", country)
    # North Korea is excluded from every donor placebo, so each has 8 controls.
    controls <- setdiff(cfg$countries, c(cfg$treated, country))
    result <- tryCatch(fit_fun(panel, cfg, treated = country, controls = controls),
                       error = function(e) e)
    if (inherits(result, "error")) {
      rows[[length(rows) + 1L]] <- data.frame(
        Country = country, Status = "failed", Error = conditionMessage(result),
        Pre_n = NA_integer_, Post_n = NA_integer_, Pre_MSPE = NA_real_,
        Post_MSPE = NA_real_, Pre_RMSPE = NA_real_, Ratio = NA_real_)
    } else {
      rows[[length(rows) + 1L]] <- cbind(
        data.frame(Country = country, Status = "ok", Error = ""),
        gap_metrics(result$series, cfg$cutoff))
      paths[[length(paths) + 1L]] <- data.frame(Country = country, result$series)
    }
  }
  table <- do.call(rbind, rows)
  ranks <- rbind(placebo_rank(table, cfg$treated),
                  placebo_rank(table, cfg$treated, cfg$rmspe_filter))
  list(table = table, series = do.call(rbind, paths), ranks = ranks)
}

run_intime <- function(raw, cfg) {
  raw <- raw[raw$Year < cfg$cutoff, , drop = FALSE]
  panel <- prepare_panel(raw, cfg, cutoff = cfg$intime_cutoff)
  pre <- sort(unique(panel$Year[panel$Year < cfg$intime_cutoff]))
  size <- floor(length(pre) / 3L)
  if (size < 1L) stop("Too few in-time training years")
  blocks <- list(pre[seq_len(size)], pre[(size + 1L):(2L * size)],
                  pre[(2L * size + 1L):length(pre)])
  fit_scm(panel, cfg, cutoff = cfg$intime_cutoff, blocks = blocks)
}

run_loo <- function(panel, cfg, main) {
  contributors <- main$weights$Country[main$weights$Weight > cfg$loo_threshold]
  rows <- list()
  paths <- list(data.frame(Omitted = "None", main$series))
  for (country in contributors) {
    result <- tryCatch(fit_scm(panel, cfg, controls = setdiff(cfg$countries,
                                                            c(cfg$treated, country))),
                       error = function(e) e)
    failed <- inherits(result, "error")
    rows[[length(rows) + 1L]] <- data.frame(
      Omitted = country, Status = if (failed) "failed" else "ok",
      Error = if (failed) conditionMessage(result) else "")
    if (!failed) paths[[length(paths) + 1L]] <- data.frame(Omitted = country, result$series)
  }
  list(log = if (length(rows)) do.call(rbind, rows) else
         data.frame(Omitted = character(), Status = character(), Error = character()),
       series = do.call(rbind, paths))
}
