# One Peninsula, Two Destinies

Code, data and manuscript for *One Peninsula, Two Destinies: A Synthetic Control Analysis of Korea's Economic Divergence* (Back, Bai and Hong, Korea University).

We fit standard and ridge-augmented synthetic controls for North Korean GDP per capita using nine donor countries, training on 1911–1943 and comparing 1954–2013. The compiled paper is `paper/SCM_revised.pdf`.

## Layout

```
config.R                   analysis settings (donors, predictors, cutoffs, options)
run.R                      main run: SCM, ASCM, donor placebos, 1935 placebo, leave-one-out
run_lambda_sensitivity.R   refits ASCM at the CV-minimum ridge penalty
R/                         data preparation, estimators, diagnostics, export
tests/test_helpers.R       unit checks for the helpers and the workbook
build_exhibits.py          turns a results directory into the paper's figures and tables
data/Final_Data.xlsx       input panel (see data/README.md)
results/corrected          the run used for every number in the paper
results/legacy             replay of the original preprocessing (appendix only)
paper/                     LaTeX source, generated figures/tables, compiled PDF
```

## Reproducing

R 4.3 with `readxl`, `ggplot2`, `Synth` 1.1-10, `osqp` 1.0.0 and `augsynth` at commit `7e70072` (pinned in `install_deps.R`).

```
Rscript install_deps.R
Rscript tests/test_helpers.R
Rscript run.R                       # writes results/pre_only_<timestamp>_<pid>/
Rscript run_lambda_sensitivity.R results/pre_only_<timestamp>_<pid>
Rscript run.R --legacy --quick      # original-imputation replay for the appendix
```

Each results directory records the configuration, the MD5 of the input workbook, `sessionInfo()`, all weights, balance tables, series and fitted model objects.

To rebuild the paper's exhibits (needs numpy, pandas, matplotlib):

```
python3 build_exhibits.py --results results/corrected --legacy results/legacy --output paper
cd paper && latexmk -pdf SCM_revised.tex
```

`paper/tables/numbers.tex` holds every number quoted in the text as a LaTeX macro, so the manuscript and the exhibits come from the same run.

## Notes on the analysis

Missing covariate values are interpolated separately on each side of the fitting cutoff, so no post-treatment observation enters a pre-treatment predictor. The 1935 placebo is prepared from the raw workbook with its own cutoff at 1934. The original workflow interpolated across the joined periods; `run.R --legacy` reproduces it and `results/legacy` is the replay reported in the appendix.

The ridge penalty for ASCM follows augsynth's one-SE rule. `run_lambda_sensitivity.R` refits at the CV minimum and saves the comparison under `results/corrected/lambda_sensitivity/`.

augsynth's conformal intervals can be produced with `run.R --conformal`; they are not reported in the paper because their permutation assumptions were not established for this series.

## License

Code is released under the MIT License. See `data/README.md` for the data sources and their terms.
