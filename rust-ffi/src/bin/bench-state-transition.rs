// M5b — state_transition V-axis bench harness (spec-realistic).
//
// Drives `csf_bench_state_transition_att_run` and its `_buildonly` paired-delta
// twin. The block carries A = MAX_ATTESTATIONS_DATA = 8 *valid* attestations so
// the O(A·V) fast path (processAttestationsFast) actually runs — unlike the
// earlier empty-block fixture, which measured only validator-Vec construction.
// Builders live entirely on the Lean side (cf. ConsensusLean4/Ffi.lean M5b
// section) so the harness only passes primitive `u64` arguments.
//
// V axis is leanSpec-bounded: VALIDATOR_REGISTRY_LIMIT = 2^12 = 4096
// (forks/lstar/config.py). Default cells: V ∈ {4, 8, 64, 512, 4096} × 5 trials.
// Pass `--include-1m` to add V=1M with 1 trial — a *mainnet out-of-spec
// reference* (real beacon chain ~1M validators), physically unreachable in this
// model where state with validator_count > 4096 fails SSZ validation.
// Pass `--single-n=N` to run only one cell — used for per-process
// `ru_maxrss` isolation as required by docs/ffi-feasibility.md A10.

use std::env;
use std::ffi::c_void;
use std::ptr;
use std::time::{Duration, Instant};

// Provides `csf_sha256_raw` for the `csf_sha256` shim that ConsensusLean4
// references via `@[extern]`; every binary linking the Lean lib needs it.
#[path = "../sha_extern.rs"]
mod sha_extern;

#[link(name = "Init_shared")]
extern "C" {
    fn lean_initialize_runtime_module();
    fn lean_initialize();
    fn lean_io_mark_end_initialization();
}

extern "C" {
    fn initialize_consensus_x2dffi_x2dpoc_ConsensusLean4_Ffi(
        builtin: u8,
        world: *mut c_void,
    ) -> *mut c_void;

    fn csf_bench_state_transition_att_run(n: u64, a: u64, seed: u64) -> u8;
    fn csf_bench_state_transition_att_buildonly(n: u64, a: u64, seed: u64) -> u8;
    // Verification probe: justifications_roots length after the pipeline.
    // 8 valid votes processed (no skip, no 2/3 bail) ⇒ 9 (incl. zero sentinel).
    fn csf_bench_state_transition_att_cells(n: u64) -> u8;
}

unsafe fn boot_lean() {
    lean_initialize_runtime_module();
    lean_initialize();
    let _ = initialize_consensus_x2dffi_x2dpoc_ConsensusLean4_Ffi(1, ptr::null_mut());
    lean_io_mark_end_initialization();
}

const A_FIXED: u64 = 8; // spec MAX_ATTESTATIONS_DATA (distinct AttestationData / block)
const TARGET_TRIAL_DURATION: Duration = Duration::from_millis(100);
const DEFAULT_N_AXIS: &[u64] = &[4, 8, 64, 512, 4096]; // leanSpec V range (≤ VALIDATOR_REGISTRY_LIMIT)
const REFERENCE_N: u64 = 1_000_000; // mainnet out-of-spec reference (opt-in via --include-1m)

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

fn calibrate_iters(n: u64, a: u64) -> usize {
    // 5 warmup calls to settle branch predictor / TLB, then time 20 calls
    // and back out an iter count that hits the target trial duration.
    for _ in 0..5 {
        let _ = unsafe { csf_bench_state_transition_att_run(n, a, 0) };
    }
    const SAMPLE: usize = 20;
    let t0 = Instant::now();
    for k in 0..SAMPLE {
        let _ = unsafe { csf_bench_state_transition_att_run(n, a, k as u64) };
    }
    let elapsed = t0.elapsed();
    let per_call_ns = (elapsed.as_nanos() / SAMPLE as u128).max(1);
    let target_ns = TARGET_TRIAL_DURATION.as_nanos();
    let raw = (target_ns / per_call_ns) as usize;
    raw.clamp(1, 1_000_000)
}

#[derive(Clone)]
struct CellResult {
    n: u64,
    iters: usize,
    trials: usize,
    run_median_ns: u128,
    bo_median_ns: u128,
    pipeline_ns: u128,
    run_iqr_ns: u128,
    sentinel: u8,
}

fn bench_cell(n: u64, a: u64, trials: usize) -> CellResult {
    // Sentinel sanity: confirm the pipeline returns Ok before timing.
    let sentinel = unsafe { csf_bench_state_transition_att_run(n, a, 0) };

    let iters = if trials == 1 { 1 } else { calibrate_iters(n, a) };
    let mut run_per_iter: Vec<u128> = Vec::with_capacity(trials);
    let mut bo_per_iter: Vec<u128> = Vec::with_capacity(trials);

    for trial in 0..trials {
        let seed_base = (trial as u64) * 1_000_000;

        let t0 = Instant::now();
        for k in 0..iters {
            let _ = unsafe {
                csf_bench_state_transition_att_run(n, a, seed_base + k as u64)
            };
        }
        let elapsed = t0.elapsed();
        run_per_iter.push(elapsed.as_nanos() / iters as u128);

        let t0 = Instant::now();
        for k in 0..iters {
            let _ = unsafe {
                csf_bench_state_transition_att_buildonly(n, a, seed_base + k as u64)
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
    // IQR for samples below 4 collapses to 0; treat that as "n/a".
    let run_iqr_ns = if trials >= 4 {
        let q1 = run_per_iter[trials / 4];
        let q3 = run_per_iter[(3 * trials) / 4];
        q3.saturating_sub(q1)
    } else {
        0
    };

    CellResult {
        n,
        iters,
        trials,
        run_median_ns: run_median,
        bo_median_ns: bo_median,
        pipeline_ns,
        run_iqr_ns,
        sentinel,
    }
}

fn spec_note(n: u64) -> &'static str {
    if n > 4096 {
        " ⚠ mainnet, out-of-spec (> VALIDATOR_REGISTRY_LIMIT=4096)"
    } else {
        ""
    }
}

fn print_results_table(results: &[CellResult]) {
    println!(
        "# state_transition bench (Array fast path, A={A_FIXED} valid attestations, \
         V ≤ leanSpec VALIDATOR_REGISTRY_LIMIT=4096)"
    );
    println!();
    println!("| V | trials | iters/trial | run median | buildonly | **pipeline (Δ)** | IQR (run) | sentinel |");
    println!("|---:|---:|---:|---:|---:|---:|---:|:---:|");
    for r in results {
        let iqr = if r.run_iqr_ns > 0 {
            fmt_duration_ns(r.run_iqr_ns)
        } else {
            "n/a".to_string()
        };
        println!(
            "| {}{} | {} | {} | {} | {} | **{}** | {} | {} |",
            r.n,
            spec_note(r.n),
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
    println!("| V | pipeline | target <200ms | outer <800ms | judgment |");
    println!("|---:|---:|:---:|:---:|:---:|");
    for r in results {
        let pipeline_ms = r.pipeline_ns as f64 / 1_000_000.0;
        let target_ok = pipeline_ms < 200.0;
        let outer_ok = pipeline_ms < 800.0;
        let judge = match (target_ok, outer_ok) {
            (true, _) => "🟢 green",
            (false, true) => "🟡 yellow",
            (false, false) => "🔴 red",
        };
        println!(
            "| {}{} | {} | {} | {} | {} |",
            r.n,
            spec_note(r.n),
            fmt_duration_ns(r.pipeline_ns),
            if target_ok { "✓" } else { "✗" },
            if outer_ok { "✓" } else { "✗" },
            judge,
        );
    }
}

fn run() {
    let args: Vec<String> = env::args().skip(1).collect();
    let include_1m = args.iter().any(|s| s == "--include-1m");
    let single_n: Option<u64> = args
        .iter()
        .find_map(|s| s.strip_prefix("--single-n="))
        .and_then(|v| v.parse().ok());

    unsafe { boot_lean(); }

    // Fixture self-check: the A=8 workload only measures the STF if all 8 votes
    // are *valid*. After the pipeline `justifications_roots` must hold 9 entries
    // (zero sentinel + 8 distinct target roots). Anything else means votes were
    // skipped (invalid) or the 2/3 threshold bailed to the slow path — either way
    // the timings below would be meaningless, so refuse to measure.
    let cells = unsafe { csf_bench_state_transition_att_cells(64) };
    assert_eq!(
        cells, 9,
        "valid-vote fixture broken: expected 9 justification roots (zero sentinel + 8 \
         targets), got {cells} — votes were skipped or the 2/3 threshold bailed"
    );
    println!("[fixture] att_cells(V=64) = {cells} ✓ (8 valid votes on the fast path)");
    println!();

    let rss_start = ru_maxrss_kb();
    let t_total = Instant::now();

    let mut results: Vec<CellResult> = Vec::new();

    if let Some(n) = single_n {
        // Per-process cell isolation: trials count depends on cell.
        let trials = if n >= REFERENCE_N { 1 } else { 5 };
        results.push(bench_cell(n, A_FIXED, trials));
    } else {
        for &n in DEFAULT_N_AXIS {
            results.push(bench_cell(n, A_FIXED, 5));
        }
        if include_1m {
            results.push(bench_cell(REFERENCE_N, A_FIXED, 1));
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

fn main() {
    // The A=8 fixture builds Lean `List`-backed structures (validators,
    // aggregation bitfields, the R·V justification array). At the out-of-spec
    // V=1M reference these recurse deep enough to blow the 8 MB main-thread
    // stack, so run everything (including Lean init) on one large-stack worker
    // thread. Lean's per-thread runtime is initialized inside that thread.
    std::thread::Builder::new()
        .stack_size(2 << 30) // 2 GiB; spec range needs far less, 1M needs headroom
        .spawn(run)
        .expect("failed to spawn bench worker thread")
        .join()
        .expect("bench worker thread panicked");
}
