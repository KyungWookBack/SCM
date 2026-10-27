# Unit checks for the helpers and the workbook. No model fitting.
# Run from project root: Rscript tests/test_helpers.R
source("config.R")
for (file in c("data", "models", "diagnostics", "export"))
  source(file.path("R", paste0(file, ".R")))
expect_error <- function(expr) {
  failed <- tryCatch({ force(expr); FALSE }, error = function(e) TRUE)
  stopifnot(failed)
}

# A post-cutoff shock cannot change the pre-cutoff interpolation.
y <- c(1939L, 1940L, 1941L, 1942L, 1943L, 1954L, 1960L)
x <- c(10, 20, NA, NA, NA, NA, 100)
changed <- x
changed[length(x)] <- 1000000
safe <- fill_series(x, y, 1944L, "pre_only")
safe_changed <- fill_series(changed, y, 1944L, "pre_only")
stopifnot(identical(safe[y < 1944], safe_changed[y < 1944]))
legacy <- fill_series(x, y, 1944L, "legacy_replay")
legacy_changed <- fill_series(changed, y, 1944L, "legacy_replay")
stopifnot(any(legacy[y < 1944] != legacy_changed[y < 1944]))
stopifnot(identical(fill_segment(c(0, NA, 10), c(1911, 1912, 1921)), c(0, 1, 10)))
expect_error(fill_segment(c(NA_real_, NA_real_), 1:2))

# Weights are matched by ID, and negative weights are kept.
map <- data.frame(ID = c(9L, 10L), Country = c("Singapore", "Spain"))
w <- named_weights(c("10", "9"), c(-0.1, 1.1), map, c(9L, 10L))
stopifnot(w$Country[1] == "Spain", w$Weight[1] == -0.1,
          w$Weight[match("Singapore", w$Country)] == 1.1)
expect_error(named_weights(c("9", "9"), c(0.5, 0.5), map, c(9L, 10L)))

# Nine donor placebos plus the treated unit: the smallest possible rank fraction is 0.1.
tab <- data.frame(Country = c("NorthKorea", paste0("donor", 1:9)),
                  Status = "ok", Ratio = 10:1, Pre_RMSPE = 1)
stopifnot(placebo_rank(tab, "NorthKorea")$Rank_fraction == 0.1)
tab$Status[10] <- "failed"
stopifnot(is.na(placebo_rank(tab, "NorthKorea")$Rank_fraction))
tab$Status[10] <- "ok"
tab$Ratio[10] <- Inf
stopifnot(is.na(placebo_rank(tab, "NorthKorea")$Rank_fraction))
stopifnot(identical(plot_segments(c(1942L, 1943L, 1954L, 1955L)), c(1L, 1L, 2L, 2L)))

stopifnot(requireNamespace("readxl", quietly = TRUE))
raw <- read_raw_panel(cfg)
stopifnot(nrow(raw) == 930L, !anyDuplicated(raw[c("Country", "Year")]))
for (cutoff in c(1935L, 1944L)) {
  view <- if (cutoff == 1935L) raw[raw$Year < cfg$cutoff, ] else raw
  panel <- prepare_panel(view, cfg, cutoff)
  perturbed <- view
  for (v in raw_variables)
    perturbed[[v]][perturbed$Year >= cutoff] <- perturbed[[v]][perturbed$Year >= cutoff] * 10
  panel2 <- prepare_panel(perturbed, cfg, cutoff)
  stopifnot(isTRUE(all.equal(panel[panel$Year < cutoff, ], panel2[panel2$Year < cutoff, ])))
}
cat("All checks passed.\n")
