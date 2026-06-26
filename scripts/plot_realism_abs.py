#!/usr/bin/env python3
"""Generate docs/assets/bench-realism-abs.svg — STF processing time vs validators.

Same source data as plot_realism.py (the four `bench-state-transition-realism`
process runs), but plotted as the *absolute* STF pipeline time per validator
count V instead of the realistic/baseline ratio. This matches the framing of
the other scaling charts (bench-scaling.svg, htr-cost.svg): processing time on
the y-axis, validator count V on the x-axis, log-log.

The pipeline time is the paired delta run − buildonly median, i.e. the
state_transition cost with its fixture-construction overhead cancelled out.
Both data variants are drawn so the reader can see they coincide within
run-to-run noise; the curves are the STF scaling, not the A/B residual.

Machine: AMD Ryzen 9 PRO 8945HS, 2026-06-26.
"""

from pathlib import Path
from statistics import median

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

# (V, baseline_ns, realistic_ns) per run — verbatim from the PLOTDATA blocks.
RUNS = [
    [(4, 488742, 493820), (8, 565465, 537549), (64, 1149330, 1135613),
     (512, 6220110, 5521174), (4096, 43457489, 42634077)],
    [(4, 487026, 535914), (8, 538965, 547931), (64, 1080952, 1149880),
     (512, 5423117, 5977652), (4096, 47708752, 41437883)],
    [(4, 545417, 557108), (8, 499315, 520265), (64, 1104868, 1082984),
     (512, 6378971, 5764746), (4096, 45539901, 44288330)],
    [(4, 482889, 510865), (8, 544242, 560696), (64, 1150596, 1209577),
     (512, 5574544, 5898013), (4096, 44828630, 43922793)],
]

VS = [4, 8, 64, 512, 4096]


def collect(idx):
    """Return {V: [ns across runs]} for column idx (1=baseline, 2=realistic)."""
    out = {v: [] for v in VS}
    for run in RUNS:
        for row in run:
            out[row[0]].append(row[idx])
    return out


def stats_us(series):
    """median, lower-err, upper-err in microseconds for an errorbar plot."""
    med = [median(series[v]) / 1e3 for v in VS]
    lo = [(median(series[v]) - min(series[v])) / 1e3 for v in VS]
    hi = [(max(series[v]) - median(series[v])) / 1e3 for v in VS]
    return med, lo, hi


def main():
    b_med, b_lo, b_hi = stats_us(collect(1))
    r_med, r_lo, r_hi = stats_us(collect(2))

    fig, ax = plt.subplots(figsize=(7.2, 4.4))

    ax.errorbar(VS, b_med, yerr=[b_lo, b_hi], marker="o", capsize=3,
                linewidth=1.6, label="baseline-pattern data", color="#1f77b4")
    ax.errorbar(VS, r_med, yerr=[r_lo, r_hi], marker="s", capsize=3,
                linewidth=1.6, label="realistic-pattern data", color="#d62728")

    ax.set_xscale("log", base=2)
    ax.set_yscale("log")
    ax.set_xticks(VS)
    ax.set_xticklabels([str(v) for v in VS])
    ax.set_xlabel("validators  V  (leanSpec range, V ≤ 4096)")
    ax.set_ylabel("STF pipeline time  (µs, run − buildonly median)")
    ax.set_title("state_transition processing time vs validators  (4-run median, error bars = min..max)")
    ax.grid(True, which="both", linewidth=0.4, alpha=0.5)

    # Annotate the absolute STF time at each V (use the baseline curve).
    for i, v in enumerate(VS):
        t = b_med[i]
        label = f"{t/1e3:.2f} ms" if t >= 1e3 else f"{t:.0f} µs"
        ax.annotate(label, xy=(v, t), xytext=(0, -14), textcoords="offset points",
                    ha="center", fontsize=8, color="#555555")

    ax.legend(loc="upper left", fontsize=8, framealpha=0.9)

    out = Path(__file__).resolve().parents[1] / "docs" / "assets" / "bench-realism-abs.svg"
    fig.savefig(out, format="svg", bbox_inches="tight")
    print(f"wrote {out}")
    print("STF pipeline time (baseline, µs):",
          {v: round(b_med[i], 1) for i, v in enumerate(VS)})


if __name__ == "__main__":
    main()
