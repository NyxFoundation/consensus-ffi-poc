// M6 — FFI marshalling-cost bench.
//
// bench-ffi-overhead showed the *primitive* boundary crossing is ~free. This
// harness measures what the real SSZ-bytes boundary (issue #4) adds: building a
// Lean `ByteArray` on the Rust side (alloc + memcpy O(size), via the
// `csf_make_bytearray` C shim), crossing into Lean as an owned argument, and
// Lean dec_ref'ing it on return — as a function of payload size.
//
// Two Lean exports per call (cf. ConsensusLean4/Ffi.lean M6):
//   * `csf_bench_marshal_touch` — XOR-folds every byte (decode-scan lower bound)
//   * `csf_bench_marshal_noop`  — consumes the arg only (alloc + memcpy + dec_ref)
// per-call(touch) − per-call(noop) = the Lean-side byte scan.
//
// Size axis is keyed to the §1 validator count N: a Validator here is
// pubkey(52) + index(8) = 60 bytes, so payload S = N * 60. This is a flat
// representative buffer, NOT canonical SSZ — no codec, no hash_tree_root/SHA.
// Methodology mirrors the other harnesses: calibrate iters to ~200ms/trial,
// median of 11 trials, black_box to defeat DCE.

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
    fn initialize_consensus_x2dlean4_ConsensusLean4_Ffi(builtin: u8, world: *mut c_void)
        -> *mut c_void;

    // C shim: build an owned Lean ByteArray (lean_sarray_object) from a buffer.
    fn csf_make_bytearray(src: *const u8, n: usize) -> *mut c_void;

    // Lean exports; each consumes (dec_refs) the passed ByteArray.
    fn csf_bench_marshal_touch(data: *mut c_void) -> u8;
    fn csf_bench_marshal_noop(data: *mut c_void) -> u8;
}

unsafe fn boot_lean() {
    lean_initialize_runtime_module();
    lean_initialize();
    let _ = initialize_consensus_x2dlean4_ConsensusLean4_Ffi(1, ptr::null_mut());
    lean_io_mark_end_initialization();
}

const VALIDATOR_BYTES: usize = 60; // pubkey(52) + index(8)
const N_AXIS: &[u64] = &[1, 100, 1_000, 10_000, 100_000, 1_000_000];
const TARGET_TRIAL: Duration = Duration::from_millis(200);
const TRIALS: usize = 11;

fn fmt_ns(ns: f64) -> String {
    if ns < 1_000.0 {
        format!("{:.1} ns", ns)
    } else if ns < 1_000_000.0 {
        format!("{:.2} µs", ns / 1_000.0)
    } else {
        format!("{:.2} ms", ns / 1_000_000.0)
    }
}

fn fmt_bytes(b: usize) -> String {
    if b < 1024 {
        format!("{} B", b)
    } else if b < 1024 * 1024 {
        format!("{:.1} KB", b as f64 / 1024.0)
    } else {
        format!("{:.1} MB", b as f64 / (1024.0 * 1024.0))
    }
}

/// Time `iters` calls of `(make_bytearray + export)` over `buf`, accumulating
/// the sentinel through black_box. Returns total nanoseconds.
fn time_loop(iters: u64, buf: &[u8], call: unsafe extern "C" fn(*mut c_void) -> u8) -> u128 {
    let p = buf.as_ptr();
    let n = buf.len();
    let mut acc: u8 = 0;
    let t0 = Instant::now();
    for _ in 0..iters {
        let obj = unsafe { csf_make_bytearray(black_box(p), black_box(n)) };
        acc ^= unsafe { call(obj) };
    }
    let elapsed = t0.elapsed().as_nanos();
    black_box(acc);
    elapsed
}

fn calibrate(buf: &[u8], call: unsafe extern "C" fn(*mut c_void) -> u8) -> u64 {
    let _ = time_loop(2, buf, call); // warm pages / branch predictor
    const SAMPLE: u64 = 5;
    let ns = time_loop(SAMPLE, buf, call).max(1);
    let per_call = (ns as f64 / SAMPLE as f64).max(1.0);
    let raw = (TARGET_TRIAL.as_nanos() as f64 / per_call) as u64;
    raw.clamp(1, 50_000_000)
}

fn bench(buf: &[u8], call: unsafe extern "C" fn(*mut c_void) -> u8) -> (u64, f64) {
    let iters = calibrate(buf, call);
    let mut per_call: Vec<f64> = Vec::with_capacity(TRIALS);
    for _ in 0..TRIALS {
        let ns = time_loop(iters, buf, call);
        per_call.push(ns as f64 / iters as f64);
    }
    per_call.sort_by(|a, b| a.partial_cmp(b).unwrap());
    (iters, per_call[TRIALS / 2])
}

fn gbps(bytes: usize, ns: f64) -> f64 {
    // bytes / seconds / 1e9
    (bytes as f64 / (ns / 1e9)) / 1e9
}

fn main() {
    unsafe { boot_lean(); }

    // Sanity: a 3-byte ByteArray {1,2,3} XOR-folds to 0.
    let probe = unsafe { csf_bench_marshal_touch(csf_make_bytearray([1u8, 2, 3].as_ptr(), 3)) };
    assert_eq!(probe, 0, "XOR-fold of {{1,2,3}} should be 0, got {probe}");

    println!("# FFI marshalling cost (Rust→Lean ByteArray, no SSZ codec / no SHA)");
    println!();
    println!("Validator = {VALIDATOR_BYTES} B (pubkey 52 + index 8); payload S = N · {VALIDATOR_BYTES}.");
    println!();
    println!("| N | payload S | marshal (noop) | full (marshal+scan) | scan Δ | marshal GB/s | marshal ns/byte |");
    println!("|---:|---:|---:|---:|---:|---:|---:|");

    for &n in N_AXIS {
        let s = (n as usize) * VALIDATOR_BYTES;
        // Distinct, non-zero content so memcpy/scan can't be elided as a zero page.
        let buf: Vec<u8> = (0..s).map(|i| (i as u8).wrapping_mul(31).wrapping_add(7)).collect();

        let (_it_n, noop) = bench(&buf, csf_bench_marshal_noop);
        let (_it_f, full) = bench(&buf, csf_bench_marshal_touch);
        let scan = (full - noop).max(0.0);

        let marshal_gbps = if s > 0 { gbps(s, noop) } else { 0.0 };
        let marshal_npb = if s > 0 { noop / s as f64 } else { 0.0 };

        println!(
            "| {} | {} | {} | {} | {} | {} | {} |",
            n,
            fmt_bytes(s),
            fmt_ns(noop),
            fmt_ns(full),
            fmt_ns(scan),
            if s > 0 { format!("{:.1}", marshal_gbps) } else { "—".into() },
            if s > 0 { format!("{:.3} ns", marshal_npb) } else { "—".into() },
        );
    }

    println!();
    println!(
        "> marshal = alloc + memcpy + boundary + dec_ref (`_noop`). scan Δ = Lean XOR-fold over S bytes. \
         Trials={TRIALS}, target {}ms/trial. Floor only: flat buffer, no SSZ codec / hash_tree_root.",
        TARGET_TRIAL.as_millis(),
    );
}
