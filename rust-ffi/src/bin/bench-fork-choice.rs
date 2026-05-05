// M5 — compute_lmd_ghost_head (B, A)-axis bench harness.
//
// Drives `csf_bench_compute_lmd_ghost_head_run` and its `_buildonly`
// paired-delta twin. The Aeneas-generated fork choice runs verbatim —
// no fast-path equivalent exists (cf. docs/ffi-feasibility.md §2.4).
//
// Default cells: (B, A) ∈ {100} × {32, 128}, 5 trials each — small
// because the Aeneas `alloc.vec.Vec` is `List`-backed and compute_block_
// weights walks it ~quadratically. Empirically B=100 ≈ 200 ms per call,
// B=1K ≈ 60 s per call (super-quadratic in practice), B=10K extrapolates
// to multi-hour. Larger cells are opt-in:
//   * `--include-1k`  — adds B=1K × {32,128} (~6 min / cell)
//   * `--include-10k` — adds B=10K × {32,128} (hour scale per cell, NOT
//     recommended unless verifying scaling)
// `--single-cell=B,A` runs one cell per process for ru_maxrss isolation
// (A10 in docs/ffi-feasibility.md).

use std::env;
use std::ffi::c_void;
use std::ptr;
use std::time::{Duration, Instant};

#[link(name = "Init_shared")]
extern "C" {
    fn lean_initialize_runtime_module();
    fn lean_initialize();
    fn lean_io_mark_end_initialization();
}

extern "C" {
    fn initialize_consensus_x2dlean4_ConsensusLean4_Ffi(
        builtin: u8,
        world: *mut c_void,
    ) -> *mut c_void;

    fn csf_bench_compute_lmd_ghost_head_run(b: u64, a: u64, seed: u64) -> u8;
    fn csf_bench_compute_lmd_ghost_head_buildonly(b: u64, a: u64, seed: u64) -> u8;
}

unsafe fn boot_lean() {
    lean_initialize_runtime_module();
    lean_initialize();
    let _ = initialize_consensus_x2dlean4_ConsensusLean4_Ffi(1, ptr::null_mut());
    lean_io_mark_end_initialization();
}

const TARGET_TRIAL_DURATION: Duration = Duration::from_millis(100);
const DEFAULT_B_AXIS: &[u64] = &[100];
const OPT_IN_1K: u64 = 1_000;
const OPT_IN_10K: u64 = 10_000;
const DEFAULT_A_AXIS: &[u64] = &[32, 128];

fn fmt_duration_ns(ns: u128) -> String {
    if ns < 1_000 {
        format!("{} ns", ns)
    } else if ns < 1_000_000 {
        format!("{:.1} µs", ns as f64 / 1_000.0)
    } else if ns < 1_000_000_000 {
        format!("{:.2} ms", ns as f64 / 1_000_000.0)
    } else {
        format!("{:.2} s", ns as f64 / 1_000_000_000.0)
    }
}

fn ru_maxrss_kb() -> i64 {
    let mut ru: libc::rusage = unsafe { std::mem::zeroed() };
    let _ = unsafe { libc::getrusage(libc::RUSAGE_SELF, &mut ru as *mut _) };
    ru.ru_maxrss
}

fn calibrate_iters(b: u64, a: u64) -> usize {
    // 1 warmup, then sample as many calls as fit in a 3-second budget
    // (capped at 100). At ~hour-scale per call (B=10K) this avoids
    // burning hours on calibration alone.
    let _ = unsafe { csf_bench_compute_lmd_ghost_head_run(b, a, 0) };

    const MAX_SAMPLE: usize = 100;
    let calib_budget = Duration::from_secs(3);
    let t_calib = Instant::now();
    let mut samples: u128 = 0;
    let mut sample_count: usize = 0;
    while sample_count < MAX_SAMPLE && t_calib.elapsed() < calib_budget {
        let t0 = Instant::now();
        let _ = unsafe {
            csf_bench_compute_lmd_ghost_head_run(b, a, sample_count as u64)
        };
        samples += t0.elapsed().as_nanos();
        sample_count += 1;
    }
    if sample_count == 0 {
        return 1;
    }
    let per_call_ns = (samples / sample_count as u128).max(1);
    let target_ns = TARGET_TRIAL_DURATION.as_nanos();
    let raw = (target_ns / per_call_ns) as usize;
    raw.clamp(1, 1_000_000)
}

#[derive(Clone)]
struct CellResult {
    b: u64,
    a: u64,
    iters: usize,
    trials: usize,
    run_median_ns: u128,
    bo_median_ns: u128,
    pipeline_ns: u128,
    run_iqr_ns: u128,
    sentinel: u8,
}

fn bench_cell(b: u64, a: u64, requested_trials: usize) -> CellResult {
    let sentinel = unsafe { csf_bench_compute_lmd_ghost_head_run(b, a, 0) };

    let iters = calibrate_iters(b, a);

    // Adapt trial count to per-call cost: keep total cell time below
    // ~60 s. Very slow cells (B=10K) collapse to 1 trial; small cells
    // get the full sample.
    let est_per_iter_ns = {
        // One quick probe to estimate (uses last calibration data
        // implicitly via the sentinel call cost — re-time once).
        let t0 = Instant::now();
        let _ = unsafe { csf_bench_compute_lmd_ghost_head_run(b, a, 9_999_999) };
        t0.elapsed().as_nanos()
    };
    let est_trial_ns = est_per_iter_ns * 2 * iters as u128; // run + buildonly
    let cell_budget_ns: u128 = 60 * 1_000_000_000;
    let max_trials = if est_trial_ns == 0 {
        requested_trials
    } else {
        ((cell_budget_ns / est_trial_ns).max(1) as usize).min(requested_trials)
    };
    let trials = max_trials.max(1);

    let mut run_per_iter: Vec<u128> = Vec::with_capacity(trials);
    let mut bo_per_iter: Vec<u128> = Vec::with_capacity(trials);

    for trial in 0..trials {
        let seed_base = (trial as u64) * 1_000_000;

        let t0 = Instant::now();
        for k in 0..iters {
            let _ = unsafe {
                csf_bench_compute_lmd_ghost_head_run(b, a, seed_base + k as u64)
            };
        }
        let elapsed = t0.elapsed();
        run_per_iter.push(elapsed.as_nanos() / iters as u128);

        let t0 = Instant::now();
        for k in 0..iters {
            let _ = unsafe {
                csf_bench_compute_lmd_ghost_head_buildonly(b, a, seed_base + k as u64)
            };
        }
        let elapsed = t0.elapsed();
        bo_per_iter.push(elapsed.as_nanos() / iters as u128);
    }

    run_per_iter.sort();
    bo_per_iter.sort();
    let mid = trials / 2;
    let run_median = run_per_iter[mid];
    let bo_median = bo_per_iter[mid];
    let pipeline_ns = run_median.saturating_sub(bo_median);
    let run_iqr_ns = if trials >= 4 {
        let q1 = run_per_iter[trials / 4];
        let q3 = run_per_iter[(3 * trials) / 4];
        q3.saturating_sub(q1)
    } else {
        0
    };

    CellResult {
        b,
        a,
        iters,
        trials,
        run_median_ns: run_median,
        bo_median_ns: bo_median,
        pipeline_ns,
        run_iqr_ns,
        sentinel,
    }
}

fn print_results_table(results: &[CellResult]) {
    println!("# compute_lmd_ghost_head bench (Aeneas direct, no fast path)");
    println!();
    println!("| B | A | trials | iters/trial | run median | buildonly | **pipeline (Δ)** | IQR (run) | sentinel |");
    println!("|---:|---:|---:|---:|---:|---:|---:|---:|:---:|");
    for r in results {
        let iqr = if r.run_iqr_ns > 0 {
            fmt_duration_ns(r.run_iqr_ns)
        } else {
            "n/a".to_string()
        };
        println!(
            "| {} | {} | {} | {} | {} | {} | **{}** | {} | {} |",
            r.b,
            r.a,
            r.trials,
            r.iters,
            fmt_duration_ns(r.run_median_ns),
            fmt_duration_ns(r.bo_median_ns),
            fmt_duration_ns(r.pipeline_ns),
            iqr,
            r.sentinel,
        );
    }
}

fn print_budget_table(results: &[CellResult]) {
    println!();
    println!("## Budget judgment (per docs/timing-budget.md §5)");
    println!();
    println!("| B | A | pipeline | target <100ms | outer <800ms | judgment |");
    println!("|---:|---:|---:|:---:|:---:|:---:|");
    for r in results {
        let pipeline_ms = r.pipeline_ns as f64 / 1_000_000.0;
        let target_ok = pipeline_ms < 100.0;
        let outer_ok = pipeline_ms < 800.0;
        let judge = match (target_ok, outer_ok) {
            (true, _) => "🟢 green",
            (false, true) => "🟡 yellow",
            (false, false) => "🔴 red",
        };
        println!(
            "| {} | {} | {} | {} | {} | {} |",
            r.b,
            r.a,
            fmt_duration_ns(r.pipeline_ns),
            if target_ok { "✓" } else { "✗" },
            if outer_ok { "✓" } else { "✗" },
            judge,
        );
    }
}

fn parse_single_cell(s: &str) -> Option<(u64, u64)> {
    let mut parts = s.splitn(2, ',');
    let b = parts.next()?.parse().ok()?;
    let a = parts.next()?.parse().ok()?;
    Some((b, a))
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    let single_cell: Option<(u64, u64)> = args
        .iter()
        .find_map(|s| s.strip_prefix("--single-cell="))
        .and_then(parse_single_cell);
    let include_1k = args.iter().any(|s| s == "--include-1k");
    let include_10k = args.iter().any(|s| s == "--include-10k");

    unsafe { boot_lean(); }

    let rss_start = ru_maxrss_kb();
    let t_total = Instant::now();

    let mut results: Vec<CellResult> = Vec::new();

    if let Some((b, a)) = single_cell {
        let trials = if b >= OPT_IN_1K { 1 } else { 5 };
        results.push(bench_cell(b, a, trials));
    } else {
        for &b in DEFAULT_B_AXIS {
            for &a in DEFAULT_A_AXIS {
                results.push(bench_cell(b, a, 5));
            }
        }
        if include_1k {
            for &a in DEFAULT_A_AXIS {
                results.push(bench_cell(OPT_IN_1K, a, 1));
            }
        }
        if include_10k {
            for &a in DEFAULT_A_AXIS {
                results.push(bench_cell(OPT_IN_10K, a, 1));
            }
        }
    }

    let total_elapsed = t_total.elapsed();
    let rss_end = ru_maxrss_kb();

    print_results_table(&results);
    print_budget_table(&results);

    println!();
    println!("## Process metrics");
    println!();
    println!("| metric | value |");
    println!("|---|---:|");
    println!("| total elapsed | {:.2}s |", total_elapsed.as_secs_f64());
    println!("| ru_maxrss start | {} MB |", rss_start / 1024);
    println!("| ru_maxrss end | {} MB |", rss_end / 1024);
    println!("| ru_maxrss delta | {} MB |", (rss_end - rss_start) / 1024);
}
