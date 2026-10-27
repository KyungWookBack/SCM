write_table <- function(x, path) utils::write.csv(x, path, row.names = FALSE, na = "NA")

# Each uninterrupted run of years gets a distinct line group, including LOO.
plot_segments <- function(years) cumsum(c(TRUE, diff(years) != 1L))

save_line_plot <- function(data, value, group, title, path, cutoff) {
  data <- data[order(data[[group]], data$Year), , drop = FALSE]
  data$Segment <- ave(data$Year, data[[group]], FUN = plot_segments)
  p <- ggplot2::ggplot(data, ggplot2::aes(x = Year, y = .data[[value]],
       colour = .data[[group]], group = interaction(.data[[group]], Segment))) +
    ggplot2::geom_line(linewidth = 0.7) +
    ggplot2::geom_vline(xintercept = cutoff, linetype = "dotted", colour = "grey50") +
    ggplot2::labs(title = title, x = NULL, y = value, colour = NULL) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom", panel.grid.minor = ggplot2::element_blank())
  if (value == "Gap") p <- p + ggplot2::geom_hline(yintercept = 0, linetype = "dashed")
  ggplot2::ggsave(path, p, width = 9, height = 5, dpi = 180)
}

export_main <- function(result, directory, cfg) {
  stem <- tolower(result$model)
  write_table(result$series, file.path(directory, paste0(stem, "_series.csv")))
  write_table(result$weights, file.path(directory, paste0(stem, "_weights_all.csv")))
  write_table(result$balance, file.path(directory, paste0(stem, "_balance.csv")))
  write_table(gap_metrics(result$series, cfg$cutoff),
              file.path(directory, paste0(stem, "_metrics.csv")))
  w <- result$weights$Weight
  write_table(data.frame(Sum = sum(w), Minimum = min(w), Negative_mass = -sum(w[w < 0]),
                         Absolute_mass = sum(abs(w))),
              file.path(directory, paste0(stem, "_weight_diagnostics.csv")))
  if (stem == "ascm") {
    diagnostic <- c("lambda", "l2_imbalance", "scaled_l2_imbalance")
    values <- vapply(diagnostic, function(key) {
      value <- result$fit[[key]]
      if (length(value) == 1L) as.numeric(value) else NA_real_
    }, numeric(1))
    write_table(data.frame(Diagnostic = diagnostic, Value = values),
                file.path(directory, "ascm_fit_diagnostics.csv"))
  }
  z <- result$series
  trajectories <- rbind(data.frame(Year = z$Year, GDP_per_Capita = z$Actual, Series = "Actual"),
                         data.frame(Year = z$Year, GDP_per_Capita = z$Synthetic, Series = result$model))
  save_line_plot(trajectories, "GDP_per_Capita", "Series", paste(result$model, "trajectory"),
                  file.path(directory, paste0(stem, "_trajectory.png")), cfg$cutoff)
  z$Series <- result$model
  save_line_plot(z, "Gap", "Series", paste(result$model, "gap: actual minus synthetic"),
                  file.path(directory, paste0(stem, "_gap.png")), cfg$cutoff)
}

export_placebos <- function(result, stem, directory, cfg) {
  write_table(result$table, file.path(directory, paste0(stem, "_placebo_metrics.csv")))
  write_table(result$series, file.path(directory, paste0(stem, "_placebo_series.csv")))
  write_table(result$ranks, file.path(directory, paste0(stem, "_placebo_ranks.csv")))
  save_line_plot(result$series, "Gap", "Country", paste(toupper(stem), "donor placebos"),
                  file.path(directory, paste0(stem, "_placebo_gaps.png")), cfg$cutoff)
}
