"""Build the paper's figures, tables and number macros from a completed R run."""

from pathlib import Path
import argparse
import json
import numpy as np
import pandas as pd
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import StrMethodFormatter

parser = argparse.ArgumentParser()
parser.add_argument("--results", type=Path, required=True)
parser.add_argument("--legacy", type=Path, required=True)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
res, legacy, out = args.results, args.legacy, args.output
figs, tables = out / "figures", out / "tables"
figs.mkdir(parents=True, exist_ok=True)
tables.mkdir(parents=True, exist_ok=True)
assert (res / "status.txt").read_text().startswith("FINISHED_REQUESTED_STEPS")


def read(name, folder=res):
    return pd.read_csv(folder / name, keep_default_na=False)


series = {m: read(f"{m}_series.csv") for m in ["scm", "ascm"]}
sensitivity = res / "lambda_sensitivity"
minimum_series = read("ascm_series.csv", sensitivity)
cv = read("cv_grid.csv", sensitivity)
comparison = read("comparison.csv", sensitivity).set_index("Model")
weights = {m: read(f"{m}_weights_all.csv").set_index("Country").Weight for m in series}
balance = read("scm_balance.csv")
panel = read("panel_used.csv")
loo = read("scm_loo_series.csv")
intime = read("scm_intime_1935.csv")
for m in series:
    assert len(read(f"{m}_placebo_metrics.csv")) == 10
    assert (read(f"{m}_placebo_metrics.csv").Status == "ok").all()
    assert abs(weights[m].sum() - 1) < 1e-7
    assert (series[m].loc[series[m].Year >= 1954, "Gap"] < 0).all()
assert (read("scm_loo_log.csv").Status == "ok").all()
assert (loo.loc[loo.Year >= 1954, "Gap"] < 0).all()
assert (minimum_series.loc[minimum_series.Year >= 1954, "Gap"] < 0).all()

plt.rcParams.update(
    {
        "font.family": "DejaVu Sans",
        "font.size": 10,
        "axes.spines.top": False,
        "axes.spines.right": False,
        "axes.titleweight": "normal",
        "axes.labelsize": 10,
        "legend.fontsize": 8.5,
        "pdf.fonttype": 42,
        "axes.grid": True,
        "grid.alpha": 0.2,
        "grid.linewidth": 0.5,
        "savefig.facecolor": "white",
    }
)
red, blue, teal = "#b83e3e", "#2e5e88", "#287c72"


def line(ax, x, y, **kw):
    x, y = np.asarray(x), np.asarray(y)
    splits = np.r_[0, np.where(np.diff(x) != 1)[0] + 1, len(x)]
    for k, (a, b) in enumerate(zip(splits[:-1], splits[1:])):
        opts = kw.copy()
        if k:
            opts["label"] = "_nolegend_"
        ax.plot(x[a:b], y[a:b], **opts)


def gap_window(ax):
    ax.axvspan(1944, 1953, color="#ececec", alpha=0.8, zorder=0)
    ax.set_xlabel("Year")
    ax.yaxis.set_major_formatter(StrMethodFormatter("{x:,.0f}"))


def save(fig, stem):
    fig.tight_layout(pad=1.1)
    fig.savefig(figs / f"{stem}.pdf", bbox_inches="tight")
    fig.savefig(figs / f"{stem}.png", dpi=170, bbox_inches="tight")
    plt.close(fig)


s = series["scm"]
fig, ax = plt.subplots(1, 2, figsize=(10.6, 4))
for a in ax:
    gap_window(a)
line(ax[0], s.Year, s.Actual, color=red, lw=1.7, label="North Korea")
line(ax[0], s.Year, s.Synthetic, color=blue, lw=1.7, ls="--", label="SCM")
a = series["ascm"]
line(ax[0], a.Year, a.Synthetic, color=teal, lw=1.6, ls=":", label="ASCM (1-SE)")
ax[0].set(title="GDP per capita", ylabel="2011 international dollars", ylim=(0, 31000))
for m, color, ls, label in [("scm", blue, "--", "SCM"), ("ascm", teal, ":", "ASCM (1-SE)")]:
    z = series[m]
    line(ax[1], z.Year, z.Gap, color=color, ls=ls, lw=1.7, label=label)
ax[1].axhline(0, color="#444", lw=0.7)
ax[1].set(title="Observed minus synthetic GDP", ylabel="2011 international dollars")
for x in ax:
    x.legend(frameon=False, loc="best")
save(fig, "paths_and_gaps")

fig, ax = plt.subplots(1, 2, figsize=(10.6, 3.9))
pre = s[s.Year < 1944]
ax[0].plot(pre.Year, pre.Actual, color=red, lw=1.7, label="North Korea")
ax[0].plot(pre.Year, pre.Synthetic, color=blue, lw=1.6, ls="--", label="SCM")
apre = a[a.Year < 1944]
ax[0].plot(apre.Year, apre.Synthetic, color=teal, lw=1.6, ls=":", label="ASCM (1-SE)")
ax[0].set(title="Full pretreatment fit", xlabel="Year", ylabel="2011 international dollars")
ax[1].plot(intime.Year, intime.Actual, color=red, lw=1.7, label="North Korea")
ax[1].plot(intime.Year, intime.Synthetic, color=blue, lw=1.6, ls="--", label="1935 placebo fit")
ax[1].axvspan(1935, 1943, color="#f4e9ce", alpha=0.6, zorder=0)
ax[1].axvline(1935, color="#777", lw=0.8, ls=":")
ax[1].set(title="Fit through 1934 and evaluation through 1943", xlabel="Year")
for x in ax:
    x.yaxis.set_major_formatter(StrMethodFormatter("{x:,.0f}"))
    x.legend(frameon=False)
save(fig, "pretreatment_and_1935")

fig, ax = plt.subplots(1, 2, figsize=(10.6, 4.2), sharex=True)
for m, x, title in zip(["scm", "ascm"], ax, ["Standard SCM", "ASCM (1-SE)"]):
    t = read(f"{m}_placebo_metrics.csv").sort_values("Ratio")
    names = t.Country.replace({"NorthKorea": "North Korea"})
    colors = [red if c == "NorthKorea" else "#a8b0b5" for c in t.Country]
    x.barh(names, t.Ratio, color=colors, height=0.72)
    x.set(title=title, xlabel="Post/pre-MSPE ratio", axisbelow=True, xlim=(0, 2800))
    x.xaxis.set_major_formatter(StrMethodFormatter("{x:,.0f}"))
    x.grid(axis="y", visible=False)
save(fig, "placebo_ratios")

with plt.rc_context({"font.size": 11}):
    fig, ax = plt.subplots(1, 2, figsize=(8.8, 4.5), sharey=True)
    for m, x, title in zip(["scm", "ascm"], ax, ["Standard SCM", "ASCM (1-SE)"]):
        z = read(f"{m}_placebo_series.csv")
        for country, g in z[z.Country != "NorthKorea"].groupby("Country"):
            line(x, g.Year, g.Gap, color="#c2c7ca", lw=0.8, alpha=0.9)
        for country, c, ls, label in [
            ("India", "#666666", "--", "India"),
            ("Singapore", blue, "-.", "Singapore"),
            ("NorthKorea", red, "-", "North Korea"),
        ]:
            g = z[z.Country == country]
            line(x, g.Year, g.Gap, color=c, lw=1.6, ls=ls, label=label)
        gap_window(x)
        x.axhline(0, color="#444444", lw=0.7)
        x.set(title=title, ylim=(-32000, 45000))
    ax[0].set_ylabel("Gap in 2011 international dollars per capita")
    handles, labels_legend = ax[0].get_legend_handles_labels()
    fig.legend(handles, labels_legend, loc="lower center", ncol=3, frameon=False, fontsize=10)
    fig.tight_layout(rect=(0, 0.10, 1, 1))
    fig.savefig(figs / "placebo_gaps.pdf", bbox_inches="tight")
    fig.savefig(figs / "placebo_gaps.png", dpi=170, bbox_inches="tight")
    plt.close(fig)

best = cv.loc[cv.Minimum].iloc[0]
selected = cv.loc[cv.One_SE_selected].iloc[0]
fig, ax = plt.subplots(figsize=(7, 3.9))
ax.plot(cv.Lambda, cv.MSE, color="#555555", marker="o", ms=3, lw=1)
ax.fill_between(
    cv.Lambda,
    cv.MSE - cv.SE,
    cv.MSE + cv.SE,
    color="#dddddd",
    alpha=0.7,
    label="CV mean plus or minus one fold-based SE",
)
ax.axhline(best.MSE + best.SE, color="#777777", ls="--", lw=1, label="One-SE eligibility threshold")
ax.scatter([best.Lambda], [best.MSE], color=blue, s=35, zorder=5, label="Minimum CV error")
ax.scatter([selected.Lambda], [selected.MSE], color=red, s=35, zorder=5, label="One-SE selection")
ax.set_xscale("log")
ax.set(xlabel="Ridge penalty", ylabel="Cross-validation mean squared error")
ax.yaxis.set_major_formatter(StrMethodFormatter("{x:,.0f}"))
ax.legend(frameon=False, fontsize=8, loc="lower left")
save(fig, "ridge_cv")

fig, ax = plt.subplots(figsize=(8, 4.3))
gap_window(ax)
line(ax, s.Year, s.Actual, color=red, lw=1.8, label="North Korea")
styles = {
    "None": (blue, "--", "Full SCM"),
    "Brazil": ("#777777", "-", "Omit Brazil"),
    "Singapore": (teal, "-.", "Omit Singapore"),
}
for donor, z in loo.groupby("Omitted", sort=False):
    c, ls, label = styles[donor]
    line(ax, z.Year, z.Synthetic, color=c, ls=ls, lw=1.55, label=label)
ax.set(ylabel="GDP per capita in 2011 international dollars", ylim=(0, 31000))
ax.legend(frameon=False, ncol=2, loc="upper left")
save(fig, "donor_deletion")

labels = {
    "Factor_Livestock": "Livestock index",
    "Factor_Education_Adj": "Adjusted education",
    "Population": "Population (thousands)",
    "SO2_Emissions_per_Capita": r"SO$_2$ emissions per capita",
    "Cropland_per_Capita": "Cropland per capita",
    **{
        f"special.GDP_per_Capita.{start}.{end}": f"GDP ({start}--{end})"
        for start, end in [(1911, 1920), (1921, 1930), (1931, 1940), (1941, 1943)]
    },
}


def write_table(name, headers, rows):
    columns = "l" + "r" * (len(headers) - 1)
    text = "\\begin{tabular}{" + columns + "}\n\\toprule\n"
    text += " & ".join(headers) + r" \\" + "\n\\midrule\n"
    text += "\n".join(" & ".join(map(str, row)) + r" \\" for row in rows)
    text += "\n\\bottomrule\n\\end{tabular}\n"
    (tables / name).write_text(text)


rows = []
for country in weights["scm"].sort_values(ascending=False).index:
    rows.append([country, f"{weights['scm'][country]:.5f}", f"{weights['ascm'][country]:.5f}"])
write_table("weights.tex", ["Country", "SCM", "ASCM (1-SE)"], rows)

ascm_balance = read("ascm_balance.csv").set_index("Predictor")
rows = []
for row in balance.itertuples():
    key = row.Predictor
    if key.startswith("special."):
        _, _, start, end = key.split(".")
        av = series["ascm"].query(f"{start} <= Year <= {end}").Synthetic.mean()
    else:
        av = ascm_balance.loc[key, "Synthetic"]
    precision = 0 if (key == "Population" or key.startswith("special.")) else 4
    fmt = lambda v: f"{v:,.{precision}f}"
    rows.append(
        [
            labels[key],
            fmt(row.Actual),
            fmt(row.Synthetic),
            fmt(av),
            fmt(row.Donor_mean),
            f"{100*row.V:.1f}",
        ]
    )
write_table("balance.tex", ["Predictor", "Actual", "SCM", "ASCM", "Donor mean", r"$V$ (\%)"], rows)

rows = []
for year in [1970, 1990, 2013]:
    z = {m: series[m].query("Year == @year").iloc[0] for m in series}
    rows.append(
        [
            year,
            f"{z['scm'].Actual:,.0f}",
            f"{z['scm'].Synthetic:,.0f}",
            f"{z['ascm'].Synthetic:,.0f}",
            f"{z['scm'].Gap:,.0f}",
            f"{z['ascm'].Gap:,.0f}",
        ]
    )
write_table(
    "outcomes.tex", ["Year", "Actual", "SCM path", "ASCM path", "SCM gap", "ASCM gap"], rows
)

rows = []
for m in series:
    for name, folder in [("Original", legacy), ("Corrected", res)]:
        z = read(f"{m}_series.csv", folder)
        met = read(f"{m}_metrics.csv", folder).iloc[0]
        rows.append(
            [m.upper(), name, f"{met.Pre_RMSPE:.1f}", f"{z.loc[z.Year==2013,'Gap'].iloc[0]:,.0f}"]
        )
write_table("preprocessing.tex", ["Model", "Imputation", "Pre-RMSPE", "2013 gap"], rows)

mask = read("raw_missing_mask.csv")
availability = []
for variables, label in [
    (["Average Years of Education"], "Years of education"),
    (["Cropland per Capita"], "Cropland per capita"),
    (["SO2 Emissions per Capita"], r"SO$_2$ emissions per capita"),
    (["Total Cattle", "Total Number of Pigs", "Total Number of Goats"], "Each livestock count"),
    (["Educational Inequality Gini Coefficient"], "Education Gini"),
    (["Population"], "Population"),
    (["GDP per Capita"], "GDP per capita"),
]:
    counts = []
    for end in [1943, 1934]:
        z = mask[(mask.Year <= end) & mask.Variable.isin(variables)]
        n = z.groupby(["Country", "Variable"]).Missing.agg(lambda s: (~s).sum())
        counts.append(str(n.min()) if n.min() == n.max() else f"{n.min()}--{n.max()}")
    availability.append([label, *counts])
write_table("availability.tex", ["Workbook input", "1911--1943", "1911--1934"], availability)

rows = []
for model, label in [
    ("Standard_SCM", "Standard SCM"),
    ("ASCM_initial", "ASCM initial"),
    ("ASCM_one_SE", "ASCM (1-SE)"),
    ("ASCM_min_CV", "ASCM (minimum CV)"),
]:
    z = comparison.loc[model]
    rows.append([label, f"{z.Pre_RMSPE:.1f}", f"{z.Synthetic_2013:,.0f}", f"{z.Gap_2013:,.0f}"])
write_table("augmentation.tex", ["Fit", "Pre-RMSPE", "2013 synthetic", "2013 gap"], rows)

minimum_weights = read("ascm_weights_all.csv", sensitivity).set_index("Country").Weight
rows = []
for country in minimum_weights.abs().sort_values(ascending=False).index:
    rows.append([country, f"{weights['ascm'][country]:.4f}", f"{minimum_weights[country]:.4f}"])
write_table("ridge_weights.tex", ["Country", "ASCM (1-SE)", "ASCM (minimum CV)"], rows)


def yrow(m, year):
    return series[m].query("Year == @year").iloc[0]


end = {m: yrow(m, 2013) for m in series}
loo_end = -loo.loc[loo.Year == 2013, "Gap"]
nums = {
    "GDPWeight": f"{100*balance.loc[balance.Predictor.str.startswith('special.'),'V'].sum():.1f}",
    "BrazilWeight": f"{100*weights['scm']['Brazil']:.1f}",
    "SingaporeWeight": f"{100*weights['scm']['Singapore']:.1f}",
    "SCMPreRMSPE": f"{read('scm_metrics.csv').Pre_RMSPE.iloc[0]:.0f}",
    "ASCMPreRMSPE": f"{read('ascm_metrics.csv').Pre_RMSPE.iloc[0]:.0f}",
    "PlaceboPre": f"{read('scm_intime_metrics.csv').Pre_RMSPE.iloc[0]:.0f}",
    "PlaceboPost": f"{np.sqrt(read('scm_intime_metrics.csv').Post_MSPE.iloc[0]):.0f}",
    "SCMGapEnd": f"{-end['scm'].Gap:,.0f}",
    "ASCMGapEnd": f"{-end['ascm'].Gap:,.0f}",
    "ObservedEnd": f"{end['scm'].Actual:,.0f}",
    "SCMPathEnd": f"{end['scm'].Synthetic:,.0f}",
    "ASCMPathEnd": f"{end['ascm'].Synthetic:,.0f}",
    "LOOMinGap": f"{loo_end.min():,.0f}",
    "LOOMaxGap": f"{loo_end.max():,.0f}",
    "ASCMNegativeMass": f"{-100*weights['ascm'][weights['ascm']<0].sum():.2f}",
    "SCMRatio": f"{read('scm_metrics.csv').Ratio.iloc[0]:,.0f}",
    "ASCMRatio": f"{read('ascm_metrics.csv').Ratio.iloc[0]:,.0f}",
    "PlaceboHeldoutMean": f"{intime.loc[intime.Year>=1935,'Gap'].mean():.0f}",
    "ASCMMinGapEnd": f"{-comparison.loc['ASCM_min_CV','Gap_2013']:,.0f}",
    "ASCMMinPathEnd": f"{comparison.loc['ASCM_min_CV','Synthetic_2013']:,.0f}",
    "ASCMMinPreRMSPE": f"{comparison.loc['ASCM_min_CV','Pre_RMSPE']:.0f}",
    "PenaltyGapChange": f"{100*(comparison.loc['ASCM_min_CV','Gap_2013']/comparison.loc['ASCM_one_SE','Gap_2013']-1):.1f}",
    "CVMinimumError": f"{best.MSE:,.0f}",
    "CVOneSEError": f"{selected.MSE:,.0f}",
    "CVMinimumSE": f"{best.SE:,.0f}",
    "CVMinimumLambda": f"{best.Lambda/1e5:.2f}" + r"\times10^{5}",
    "CVSelectedLambda": f"{selected.Lambda/1e8:.2f}" + r"\times10^{8}",
    "CVEligible": str(int(cv.Within_one_SE.sum())),
    "MinimumNegativeMass": f"{100*read('ascm_weight_diagnostics.csv',sensitivity).Negative_mass.iloc[0]:.2f}",
}
sg_gdp = panel[(panel.Country == "Singapore") & (panel.Year == 2013)].GDP_per_Capita.iloc[0]
sg_contribution = sg_gdp * weights["scm"]["Singapore"]
nums["SingaporeContribution"] = f"{sg_contribution:,.0f}"
nums["SingaporeShare"] = f"{100*sg_contribution/end['scm'].Synthetic:.1f}"
scm_placebos = read("scm_placebo_metrics.csv").set_index("Country")
scm_paths = read("scm_placebo_series.csv")
for country, key in [
    ("Singapore", "SingaporeGapEnd"),
    ("Spain", "SpainGapEnd"),
    ("India", "IndiaGapEnd"),
]:
    v = scm_paths[(scm_paths.Country == country) & (scm_paths.Year == 2013)].Gap.iloc[0]
    nums[key] = f"{abs(v):,.0f}"
nums["SingaporePreRMSPE"] = f"{scm_placebos.loc['Singapore','Pre_RMSPE']:.0f}"
nums["SingaporePostRMSPE"] = f"{np.sqrt(scm_placebos.loc['Singapore','Post_MSPE']):,.0f}"
nums["NorthPostRMSPE"] = f"{np.sqrt(scm_placebos.loc['NorthKorea','Post_MSPE']):,.0f}"
nums["SingaporeRatio"] = f"{scm_placebos.loc['Singapore','Ratio']:.0f}"
macros = "\n".join(r"\newcommand{\%s}{%s}" % (k, v.replace(",", "{,}")) for k, v in nums.items())
(tables / "numbers.tex").write_text(macros + "\n")
(out / "computed_numbers.json").write_text(json.dumps(nums, indent=2))
print(json.dumps(nums, indent=2))
