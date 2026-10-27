raw_variables <- c("GDP per Capita", "Total Cattle", "Total Number of Pigs",
                   "Total Number of Goats", "Average Years of Education",
                   "Educational Inequality Gini Coefficient", "Population",
                   "SO2 Emissions per Capita", "Cropland per Capita")

read_raw_panel <- function(cfg) {
  stopifnot(file.exists(cfg$data_file))
  missing <- setdiff(cfg$countries, readxl::excel_sheets(cfg$data_file))
  if (length(missing)) stop("Missing sheets: ", paste(missing, collapse = ", "))
  panels <- lapply(cfg$countries, function(country) {
    x <- as.data.frame(readxl::read_excel(cfg$data_file, sheet = country))
    if (!"Indicator" %in% names(x) || anyDuplicated(x$Indicator))
      stop("Missing/duplicate Indicator in ", country)
    if (length(setdiff(raw_variables, x$Indicator)) ||
        length(setdiff(as.character(cfg$years), names(x))))
      stop("Missing input variable or year in ", country)
    z <- x[match(raw_variables, x$Indicator), as.character(cfg$years), drop = FALSE]
    z <- as.data.frame(t(as.matrix(z)), stringsAsFactors = FALSE)
    names(z) <- raw_variables
    for (v in raw_variables) {
      old <- z[[v]]
      z[[v]] <- suppressWarnings(as.numeric(old))
      if (any(!is.na(old) & is.na(z[[v]])) || any(is.infinite(z[[v]])))
        stop("Non-numeric/non-finite input: ", country, " / ", v)
    }
    data.frame(Country = country, Year = cfg$years, z, check.names = FALSE)
  })
  raw <- do.call(rbind, panels)
  rownames(raw) <- NULL
  raw
}

# Linear interpolation inside a segment, constant fill at its ends.
fill_segment <- function(x, time) {
  observed <- which(!is.na(x))
  if (!length(observed)) stop("No observations in an interpolation segment")
  if (length(observed) == 1L) return(rep(x[observed], length(x)))
  stats::approx(time[observed], x[observed], xout = time, rule = 2)$y
}

fill_series <- function(x, years, cutoff, mode) {
  if (mode == "legacy_replay") return(fill_segment(x, seq_along(x)))
  if (mode != "pre_only") stop("Unknown preprocessing mode: ", mode)
  out <- x
  for (before in c(TRUE, FALSE)) {
    idx <- which((years < cutoff) == before)
    if (length(idx)) out[idx] <- fill_segment(x[idx], years[idx])
  }
  out
}

prepare_panel <- function(raw, cfg, cutoff = cfg$cutoff) {
  # Call on the raw panel once per cutoff (1944 for the main fit, 1935 for the in-time placebo).
  pieces <- lapply(sort(unique(raw$Country)), function(country) {
    x <- raw[raw$Country == country, , drop = FALSE]
    x <- x[order(x$Year), , drop = FALSE]
    for (v in raw_variables)
      x[[v]] <- fill_series(x[[v]], x$Year, cutoff, cfg$preprocess_mode)
    if (any(x$Population <= 0)) stop("Non-positive population: ", country)
    data.frame(
      Country = country, Year = x$Year,
      GDP_per_Capita = x[["GDP per Capita"]],
      Factor_Livestock = (x[["Total Cattle"]] + 0.25 * x[["Total Number of Pigs"]] +
                          0.1 * x[["Total Number of Goats"]]) / x$Population,
      Factor_Education_Adj = x[["Average Years of Education"]] *
        (1 - x[["Educational Inequality Gini Coefficient"]] / 100),
      Population = x$Population,
      SO2_Emissions_per_Capita = x[["SO2 Emissions per Capita"]],
      Cropland_per_Capita = x[["Cropland per Capita"]]
    )
  })
  panel <- do.call(rbind, pieces)
  panel$ID <- match(panel$Country, sort(cfg$countries))
  if (anyDuplicated(panel[c("ID", "Year")]) ||
      any(!is.finite(as.matrix(panel[c("GDP_per_Capita", cfg$predictors)]))))
    stop("Invalid model panel")
  rownames(panel) <- NULL
  panel
}

raw_missing_mask <- function(raw) {
  do.call(rbind, lapply(raw_variables, function(v) {
    data.frame(Country = raw$Country, Year = raw$Year,
               Variable = v, Missing = is.na(raw[[v]]))
  }))
}
