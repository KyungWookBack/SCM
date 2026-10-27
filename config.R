# Analysis settings. See README.md.
cfg <- list(
  data_file = file.path("data", "Final_Data.xlsx"),
  treated = "NorthKorea",
  countries = c("Argentina", "Brazil", "Chile", "Greece", "India", "Mexico",
                "NorthKorea", "Portugal", "Singapore", "Spain"),
  years = c(1911:1943, 1954:2013),
  cutoff = 1944L,
  predictors = c("Factor_Livestock", "Factor_Education_Adj", "Population",
                 "SO2_Emissions_per_Capita", "Cropland_per_Capita"),
  gdp_blocks = list(1911:1920, 1921:1930, 1931:1940, 1941:1943),
  # pre_only: interpolate on calendar years, separately before and after the cutoff.
  # legacy_replay: the original row-index interpolation across both periods (appendix only).
  preprocess_mode = "pre_only",
  seed = 1219L,
  run_placebos = TRUE,
  run_intime = TRUE,
  run_loo = TRUE,
  intime_cutoff = 1935L,
  loo_threshold = 0.001,
  rmspe_filter = 5,
  # augsynth conformal intervals; off by default (see README).
  run_conformal = FALSE
)
