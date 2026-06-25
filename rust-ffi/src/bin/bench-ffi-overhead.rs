// Pure FFI boundary-cost bench.
//
// Unlike bench-state-transition / bench-fork-choice (which paired-delta the
// FFI crossing *out* to isolate Lean-side compute), this harness measures the
// crossing itself. It calls `csf_ping` (Lean: `fun n => n + 1`, the cheapest
// possible @[export]) in a tight loop and reports per-call cost, then compares
// against an equivalent Rust-local opaque call to separate "Rust→Lean boundary
// overhead" from "ordinary non-inlinable function-call overhead".
//
// Primitive args only (u64 -> u64), so this is the *floor* of FFI cost: the
// C ABI call/return plus whatever the Lean runtime trampoline adds. Structured
// lean_object* marshalling + dec_ref is NOT measured here — that layer (A23 /
// issue #4) does not exist in this build.
//
// Methodology: per-call cost = (tight loop of N calls, accumulated through
// black_box to defeat DCE) / N. Calibrate N to ~200ms/trial, take the median
// of 15 trials, report min and IQR for spread.

use std::ffi::c_void;
use std::hint::black_box;
use std::ptr;
use std::time::{Duration, Instant};

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

    // Lean: `@[export csf_ping] def csfPing (n : UInt64) : UInt64 := n + 1`
    fn csf_ping(n: u64) -> u64;
}

unsafe fn boot_lean() {
    lean_initialize_runtime_module();
    lean_initialize();
    let _ = initialize_consensus_x2dffi_x2dpoc_ConsensusLean4_Ffi(1, ptr::null_mut());
    lean_io_mark_end_initialization();
}

// Rust-local twin of csf_ping. `#[inline(never)]` + a distinct symbol keeps the
// optimizer from folding it into the loop, so it stands in for "a normal opaque
// function call that does NOT cross the FFI boundary".
#[inline(never)]
#[no_mangle]
extern "C" fn rust_ping(n: u64) -> u64 {
    black_box(n).wrapping_add(1)
}

const TARGET_TRIAL: Duration = Duration::from_millis(200);
const TRIALS: usize = 15;

fn fmt_per_call(ns: f64) -> String {
    if ns < 1_000.0 {
        format!("{:.2} ns", ns)
    } else {
        format!("{:.3} µs", ns / 1_000.0)
    }
}

/// Time `iters` calls of `f`, accumulating the result through black_box so the
/// loop cannot be optimised away. Returns total nanoseconds.
fn time_loop<F: Fn(u64) -> u64>(iters: u64, f: F) -> u128 {
    let mut acc: u64 = 0;
    let t0 = Instant::now();
    for k in 0..iters {
        acc = acc.wrapping_add(f(black_box(k)));
    }
    let elapsed = t0.elapsed().as_nanos();
    black_box(acc);
    elapsed
}

fn calibrate<F: Fn(u64) -> u64>(f: &F) -> u64 {
    // Warm up, then time a fixed sample and back out iters for the target.
    let _ = time_loop(10_000, f);
    const SAMPLE: u64 = 200_000;
    let ns = time_loop(SAMPLE, f).max(1);
    let per_call = (ns as f64 / SAMPLE as f64).max(0.001);
    let raw = (TARGET_TRIAL.as_nanos() as f64 / per_call) as u64;
    raw.clamp(100_000, 2_000_000_000)
}

struct Stats {
    iters: u64,
    median_ns: f64,
    min_ns: f64,
    iqr_ns: f64,
}

fn bench<F: Fn(u64) -> u64>(f: F) -> Stats {
    let iters = calibrate(&f);
    let mut per_call: Vec<f64> = Vec::with_capacity(TRIALS);
    for _ in 0..TRIALS {
        let ns = time_loop(iters, &f);
        per_call.push(ns as f64 / iters as f64);
    }
    per_call.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let median = per_call[TRIALS / 2];
    let min = per_call[0];
    let q1 = per_call[TRIALS / 4];
    let q3 = per_call[(3 * TRIALS) / 4];
    Stats { iters, median_ns: median, min_ns: min, iqr_ns: q3 - q1 }
}

fn main() {
    unsafe { boot_lean(); }

    // Sanity: confirm the boundary is live and returns n+1.
    let probe = unsafe { csf_ping(41) };
    assert_eq!(probe, 42, "csf_ping(41) should be 42, got {probe}");

    let ffi = bench(|n| unsafe { csf_ping(n) });
    let local = bench(|n| rust_ping(n));
    let overhead = ffi.median_ns - local.median_ns;

    println!("# Pure FFI boundary-cost bench (csf_ping: u64 -> u64, Lean `n+1`)");
    println!();
    println!("| call path | iters/trial | median | min | IQR |");
    println!("|---|---:|---:|---:|---:|");
    println!(
        "| **FFI** `csf_ping` (Rust→Lean) | {} | **{}** | {} | {} |",
        ffi.iters, fmt_per_call(ffi.median_ns), fmt_per_call(ffi.min_ns), fmt_per_call(ffi.iqr_ns),
    );
    println!(
        "| Rust-local `rust_ping` (no boundary) | {} | {} | {} | {} |",
        local.iters, fmt_per_call(local.median_ns), fmt_per_call(local.min_ns), fmt_per_call(local.iqr_ns),
    );
    println!();
    println!(
        "**FFI boundary overhead (FFI median − local median): {} per call**",
        fmt_per_call(overhead),
    );
    println!();
    println!(
        "> Floor only: primitive `u64` args, no `lean_object*` marshalling / dec_ref. \
         Trials={TRIALS}, target {}ms/trial.",
        TARGET_TRIAL.as_millis(),
    );
}
