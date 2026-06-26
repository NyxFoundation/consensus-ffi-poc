#!/usr/bin/env python3
"""Generate docs/assets/bench-realism-clean.svg — STF processing time vs validators,
measured under clean single-process isolation.

Unlike plot_realism_abs.py (whose data comes from the sustained-load
`bench-state-transition-realism` binary that interleaves both fixtures with a
per-cell calibrate, keeping the CPU under continuous load), this chart's data
comes from the §1b clean harness `bench-state-transition` run once per (V,fixture)
in its OWN process (`--single-n=N`, `--realistic` to select the fixture), with a
cooldown before every process so the boost clock is not depressed by sustained
load. Both fixture families go through the identical harness, so the two curves
are directly comparable.

The pipeline time is the paired delta run − buildonly median, i.e. the
state_transition cost with its fixture-construction overhead cancelled out.

Machine: AMD Ryzen 9 PRO 8945HS (16 threads), governor=performance,
EPP=performance, boost on. Kali Linux Rolling, kernel 6.18.12. 2026-06-26 ~10:00,
idle machine (resident clickhouse container frozen during the run). 3 isolated
processes per cell; the point is the median, error bars are min..max.
"""

from pathlib import Path
from statistics import median

import matplotlib

matplotlib.use("Agg")
# Keep glyphs as <text> (searchable, diff-friendly, smaller) to match the
# sibling docs/assets/bench-*.svg rather than path-tracing every character.
matplotlib.rcParams["svg.fonttype"] = "none"
import matplotlib.pyplot as plt

# (V, baseline_ns, variant_ns) per round — verbatim pipeline Δ from the clean
# per-process runs (run − buildonly median). 3 rounds, each cell its own process.
RUNS = [
    [(4, 500505, 484011), (8, 494727, 513860), (64, 1147906, 1221616),
     (512, 5770899, 6099421), (4096, 41362683, 41963933)],
    [(4, 465938, 492497), (8, 523817, 530381), (64, 1110647, 1196569),
     (512, 5786186, 5788166), (4096, 42110075, 41900606)],
    [(4, 469475, 507212), (8, 546896, 503244), (64, 1097685, 1184341),
     (512, 5864254, 6045838), (4096, 42060853, 43892274)],
]

VS = [4, 8, 64, 512, 4096]


def collect(idx):
    """Return {V: [ns across rounds]} for column idx (1=baseline, 2=variant)."""
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
                linewidth=1.6, label="baseline", color="#1f77b4")
    ax.errorbar(VS, r_med, yerr=[r_lo, r_hi], marker="s", capsize=3,
                linewidth=1.6, label="variant", color="#d62728")

    ax.set_xscale("log", base=2)
    ax.set_yscale("log")
    ax.set_xticks(VS)
    ax.set_xticklabels([str(v) for v in VS])
    ax.set_xlabel("validators  V  (leanSpec range, V ≤ 4096)")
    ax.set_ylabel("STF pipeline time  (µs, run − buildonly median)")
    ax.set_title("state_transition processing time vs validators  (3-run median, error bars = min..max)")
    ax.grid(True, which="both", linewidth=0.4, alpha=0.5)

    # Annotate the absolute STF time at each V (use the baseline curve).
    for i, v in enumerate(VS):
        t = b_med[i]
        label = f"{t/1e3:.2f} ms" if t >= 1e3 else f"{t:.0f} µs"
        ax.annotate(label, xy=(v, t), xytext=(0, -14), textcoords="offset points",
                    ha="center", fontsize=8, color="#555555")

    ax.legend(loc="upper left", fontsize=8, framealpha=0.9)

    out = Path(__file__).resolve().parents[1] / "docs" / "assets" / "bench-realism-clean.svg"
    fig.savefig(out, format="svg", bbox_inches="tight")
    print(f"wrote {out}")
    print("baseline median (µs):", {v: round(b_med[i], 1) for i, v in enumerate(VS)})
    print("variant  median (µs):", {v: round(r_med[i], 1) for i, v in enumerate(VS)})


if __name__ == "__main__":
    main()
