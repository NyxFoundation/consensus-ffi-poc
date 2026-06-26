// Realism probe — quantifies the "optimistic bias" of the M5b synthetic
// state_transition fixture by measuring it against a data-realistic twin in the
// SAME process (shared thermal/cache state for a fair A/B).
//
// Two configs over the same V axis, same A=8 valid votes, same no-bail /
// cells=9 invariant (cf. ConsensusLean4/Ffi.lean "Realism probe" section):
//   * baseline  — contiguous ⌈V/2⌉-bit prefix + single-repeated-byte roots
//                 (csf_bench_state_transition_att_*)
//   * realistic — Fisher-Yates-scattered ⌈V/2⌉ bits + high-entropy roots
//                 (csf_bench_state_transition_att_real_*)
//
// The delta isolates the data-pattern component of the timing: branch
// prediction on the aggregation-bit scan plus H256 comparison short-circuit.
// Everything algorithmic (V, A, # SHA blocks, control-flow path) is identical,
// so realistic ≥ baseline is the optimistic-bias factor.

use std::ffi::c_void;
use std::ptr;
use std::time::{Duration, Instant};

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
    fn csf_bench_state_transition_att_cells(n: u64) -> u8;

    fn csf_bench_state_transition_att_real_run(n: u64, a: u64, seed: u64) -> u8;
    fn csf_bench_state_transition_att_real_buildonly(n: u64, a: u64, seed: u64) -> u8;
    fn csf_bench_state_transition_att_real_cells(n: u64) -> u8;
}

unsafe fn boot_lean() {
    lean_initialize_runtime_module();
    lean_initialize();
    let _ = initialize_consensus_x2dffi_x2dpoc_ConsensusLean4_Ffi(1, ptr::null_mut());
    lean_io_mark_end_initialization();
}

type BenchFn = unsafe extern "C" fn(u64, u64, u64) -> u8;

struct Config {
    run: BenchFn,
    buildonly: BenchFn,
}

const A_FIXED: u64 = 8;
const TARGET_TRIAL_DURATION: Duration = Duration::from_millis(100);
const N_AXIS: &[u64] = &[4, 8, 64, 512, 4096];
const TRIALS: usize = 7;

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

fn calibrate_iters(run: BenchFn, n: u64, a: u64) -> usize {
    for _ in 0..5 {
        let _ = unsafe { run(n, a, 0) };
    }
    const SAMPLE: usize = 20;
    let t0 = Instant::now();
    for k in 0..SAMPLE {
        let _ = unsafe { run(n, a, k as u64) };
    }
    let per_call_ns = (t0.elapsed().as_nanos() / SAMPLE as u128).max(1);
    let raw = (TARGET_TRIAL_DURATION.as_nanos() / per_call_ns) as usize;
    raw.clamp(1, 1_000_000)
}

/// Pipeline Δ = median(run) − median(buildonly) over `TRIALS` trials.
fn bench_pipeline(cfg: &Config, n: u64, a: u64) -> u128 {
    let iters = calibrate_iters(cfg.run, n, a);
    let mut run_per: Vec<u128> = Vec::with_capacity(TRIALS);
    let mut bo_per: Vec<u128> = Vec::with_capacity(TRIALS);

    for trial in 0..TRIALS {
        let seed_base = (trial as u64) * 1_000_000;

        let t0 = Instant::now();
        for k in 0..iters {
            let _ = unsafe { (cfg.run)(n, a, seed_base + k as u64) };
        }
        run_per.push(t0.elapsed().as_nanos() / iters as u128);

        let t0 = Instant::now();
        for k in 0..iters {
            let _ = unsafe { (cfg.buildonly)(n, a, seed_base + k as u64) };
        }
        bo_per.push(t0.elapsed().as_nanos() / iters as u128);
    }

    run_per.sort();
    bo_per.sort();
    let mid = TRIALS / 2;
    run_per[mid].saturating_sub(bo_per[mid])
}

fn run() {
    unsafe { boot_lean(); }

    let baseline = Config {
        run: csf_bench_state_transition_att_run,
        buildonly: csf_bench_state_transition_att_buildonly,
    };
    let realistic = Config {
        run: csf_bench_state_transition_att_real_run,
        buildonly: csf_bench_state_transition_att_real_buildonly,
    };

    // Both fixtures must keep the 8 votes on the fast path (cells = 9), else the
    // timings compare different control-flow paths and the A/B is meaningless.
    let bc = unsafe { csf_bench_state_transition_att_cells(64) };
    let rc = unsafe { csf_bench_state_transition_att_real_cells(64) };
    assert_eq!(bc, 9, "baseline fixture broken: cells = {bc}, expected 9");
    assert_eq!(rc, 9, "realistic fixture broken: cells = {rc}, expected 9");
    println!("[fixture] baseline cells = {bc} ✓  realistic cells = {rc} ✓ (both: 8 valid votes, fast path)");
    println!();

    let mut rows: Vec<(u64, u128, u128)> = Vec::new();
    for &n in N_AXIS {
        // Interleave the two configs at each V so they share cache/thermal state.
        let b = bench_pipeline(&baseline, n, A_FIXED);
        let r = bench_pipeline(&realistic, n, A_FIXED);
        rows.push((n, b, r));
    }

    println!(
        "# state_transition realism A/B (A={A_FIXED} valid attestations, {TRIALS} trials, \
         V ≤ leanSpec VALIDATOR_REGISTRY_LIMIT=4096)"
    );
    println!();
    println!("| V | baseline Δ | realistic Δ | realistic − baseline | realistic / baseline |");
    println!("|---:|---:|---:|---:|---:|");
    for &(n, b, r) in &rows {
        let diff = r as i128 - b as i128;
        let ratio = if b > 0 { r as f64 / b as f64 } else { f64::NAN };
        let sign = if diff >= 0 { "+" } else { "−" };
        println!(
            "| {} | {} | {} | {}{} | {:.3}× |",
            n,
            fmt_duration_ns(b),
            fmt_duration_ns(r),
            sign,
            fmt_duration_ns(diff.unsigned_abs()),
            ratio,
        );
    }

    // Machine-readable block for the SVG generator: V,baseline_ns,realistic_ns
    println!();
    println!("<!-- PLOTDATA");
    for &(n, b, r) in &rows {
        println!("{},{},{}", n, b, r);
    }
    println!("-->");
}

fn main() {
    std::thread::Builder::new()
        .stack_size(2 << 30)
        .spawn(run)
        .expect("failed to spawn bench worker thread")
        .join()
        .expect("bench worker thread panicked");
}
