#!/usr/bin/env python3
"""Generate docs/assets/bench-realism-clean.svg — STF processing time vs validators,
measured under clean single-process isolation on the realistic attestation fixture.

This is the §1b clean harness `bench-state-transition` run once per V in its OWN
process (`--single-n=N`), with a cooldown before every process so the boost clock
is not depressed by sustained load — each cell is thermally isolated.

The plotted curve is the realistic fixture (scattered aggregation bits +
high-entropy roots — the data shape that represents real attestations); it is the
canonical clean STF cost.

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

# (V, realistic_ns) per round — verbatim pipeline Δ from the clean per-process
# runs (run − buildonly median). 3 rounds, each cell its own process.
RUNS = [
    [(4, 484011), (8, 513860), (64, 1221616), (512, 6099421), (4096, 41963933)],
    [(4, 492497), (8, 530381), (64, 1196569), (512, 5788166), (4096, 41900606)],
    [(4, 507212), (8, 503244), (64, 1184341), (512, 6045838), (4096, 43892274)],
]

VS = [4, 8, 64, 512, 4096]


def collect():
    """Return {V: [ns across rounds]} for the realistic pipeline Δ."""
    out = {v: [] for v in VS}
    for run in RUNS:
        for row in run:
            out[row[0]].append(row[1])
    return out


def stats_us(series):
    """median, lower-err, upper-err in microseconds for an errorbar plot."""
    med = [median(series[v]) / 1e3 for v in VS]
    lo = [(median(series[v]) - min(series[v])) / 1e3 for v in VS]
    hi = [(max(series[v]) - median(series[v])) / 1e3 for v in VS]
    return med, lo, hi


def main():
    med, lo, hi = stats_us(collect())

    fig, ax = plt.subplots(figsize=(7.2, 4.4))

    ax.errorbar(VS, med, yerr=[lo, hi], marker="o", capsize=3,
                linewidth=1.6, color="#1f77b4")

    ax.set_xscale("log", base=2)
    ax.set_yscale("log")
    ax.set_xticks(VS)
    ax.set_xticklabels([str(v) for v in VS])
    ax.set_xlabel("validators  V  (leanSpec range, V ≤ 4096)")
    ax.set_ylabel("STF pipeline time  (µs, run − buildonly median)")
    ax.set_title("state_transition processing time vs validators  (3-run median, error bars = min..max)")
    ax.grid(True, which="both", linewidth=0.4, alpha=0.5)

    # Annotate the absolute STF time at each V.
    for i, v in enumerate(VS):
        t = med[i]
        label = f"{t/1e3:.2f} ms" if t >= 1e3 else f"{t:.0f} µs"
        ax.annotate(label, xy=(v, t), xytext=(0, -14), textcoords="offset points",
                    ha="center", fontsize=8, color="#555555")

    out = Path(__file__).resolve().parents[1] / "docs" / "assets" / "bench-realism-clean.svg"
    fig.savefig(out, format="svg", bbox_inches="tight")
    print(f"wrote {out}")
    print("clean STF pipeline time (µs):", {v: round(med[i], 1) for i, v in enumerate(VS)})


if __name__ == "__main__":
    main()
