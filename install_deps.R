options(repos = c(CRAN = "https://cloud.r-project.org"), timeout = 180)
install.packages(c("readxl", "ggplot2", "remotes"))
remotes::install_version("Synth", version = "1.1-10", upgrade = "never")
remotes::install_version("osqp", version = "1.0.0", upgrade = "never")
remotes::install_github(
  "ebenmichael/augsynth@7e70072232fe75057aa8b5d7af08c7e1aef53ae8",
  upgrade = "never"
)
stopifnot(requireNamespace("readxl", quietly = TRUE),
          requireNamespace("Synth", quietly = TRUE),
          requireNamespace("augsynth", quietly = TRUE),
          requireNamespace("ggplot2", quietly = TRUE))
