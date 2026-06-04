// M7 — end-to-end SSZ-bytes pipeline: marshal → decode → pure STF.
//
// Connects what M6 (bench-ffi-marshal) left split: a State+Block is serialized
// on the Rust side to a flat length-prefixed buffer, marshalled into a Lean
// ByteArray (csf_make_bytearray), decoded into the typed `State`/`Block`
// (ConsensusLean4/Ffi.lean M7), and fed to the pure `stateTransitionFast`.
//
// The fixture matches §1's buildBenchState(n)/buildBenchBlock(n) byte-for-byte
// (N validators, empty justification/attestation vectors, block at slot 1,
// proposer 1%N), so the decoded input is identical to the scalar-built one and
// the STF cost is directly comparable. Correctness gate: ssz_run must return
// sentinel 0 (Ok) — a wrong codec would yield a different sentinel or crash.
//
// Decomposition per N (each call = make_bytearray + one export):
//   marshal    = make + csf_bench_marshal_noop                 (alloc+memcpy+dec_ref)
//   ssz_decode = make + csf_bench_state_transition_ssz_decode  (+ decode)
//   ssz_run    = make + csf_bench_state_transition_ssz_run     (+ decode + STF)
// → decode = ssz_decode − marshal,  STF = ssz_run − ssz_decode.
//
// No SSZ canonical wire format and no hash_tree_root/SHA: decoding is pure byte
// layout. Methodology mirrors the sibling harnesses (calibrate to ~200ms/trial,
// median of 11 trials, black_box).

use std::env;
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
    fn csf_make_bytearray(src: *const u8, n: usize) -> *mut c_void;
    fn csf_bench_marshal_noop(data: *mut c_void) -> u8;
    fn csf_bench_state_transition_ssz_decode(data: *mut c_void) -> u8;
    fn csf_bench_state_transition_ssz_run(data: *mut c_void) -> u8;
}

unsafe fn boot_lean() {
    lean_initialize_runtime_module();
    lean_initialize();
    let _ = initialize_consensus_x2dlean4_ConsensusLean4_Ffi(1, ptr::null_mut());
    lean_io_mark_end_initialization();
}

// ---- Rust serializer: must round-trip with ConsensusLean4/Ffi.lean M7 ----

fn push_u64(b: &mut Vec<u8>, x: u64) {
    b.extend_from_slice(&x.to_le_bytes());
}
fn push_zeros(b: &mut Vec<u8>, n: usize) {
    b.resize(b.len() + n, 0);
}

/// Serialize State++Block matching buildBenchState(n)/buildBenchBlock(n).
fn serialize_fixture(n: u64) -> Vec<u8> {
    let mut b = Vec::new();
    // --- State ---
    push_u64(&mut b, 0); // config.genesis_time
    push_u64(&mut b, 0); // slot
    push_zeros(&mut b, 112); // latest_block_header (all zero)
    push_zeros(&mut b, 40); // latest_justified  {ZERO, 0}
    push_zeros(&mut b, 40); // latest_finalized  {ZERO, 0}
    push_u64(&mut b, 0); // historical_block_hashes: count
    push_u64(&mut b, 0); // justified_slots: count
    push_u64(&mut b, n); // validators: count
    for _ in 0..n {
        push_zeros(&mut b, 52); // pubkey
        push_u64(&mut b, 0); // index
    }
    push_u64(&mut b, 0); // justifications_roots: count
    push_u64(&mut b, 0); // justifications_validators: count
    // --- Block ---
    push_u64(&mut b, 1); // slot
    push_u64(&mut b, if n == 0 { 0 } else { 1 % n }); // proposer_index
    push_zeros(&mut b, 32); // parent_root
    push_zeros(&mut b, 32); // state_root
    push_u64(&mut b, 0); // body.attestations: count
    b
}

// ---- timing ----

const N_AXIS: &[u64] = &[100, 1_000, 10_000, 100_000];
const REFERENCE_N: u64 = 1_000_000;
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
    let _ = time_loop(2, buf, call);
    const SAMPLE: u64 = 5;
    let ns = time_loop(SAMPLE, buf, call).max(1);
    let per_call = (ns as f64 / SAMPLE as f64).max(1.0);
    ((TARGET_TRIAL.as_nanos() as f64 / per_call) as u64).clamp(1, 50_000_000)
}

fn bench(buf: &[u8], call: unsafe extern "C" fn(*mut c_void) -> u8) -> f64 {
    let iters = calibrate(buf, call);
    let mut v: Vec<f64> = Vec::with_capacity(TRIALS);
    for _ in 0..TRIALS {
        v.push(time_loop(iters, buf, call) as f64 / iters as f64);
    }
    v.sort_by(|a, b| a.partial_cmp(b).unwrap());
    v[TRIALS / 2]
}

struct Row {
    n: u64,
    bytes: usize,
    marshal: f64,
    decode: f64,
    stf: f64,
    total: f64,
}

fn bench_cell(n: u64) -> Row {
    let buf = serialize_fixture(n);

    // Correctness gate: the decoded fixture must transition cleanly (Ok = 0).
    let sentinel = unsafe { csf_bench_state_transition_ssz_run(csf_make_bytearray(buf.as_ptr(), buf.len())) };
    assert_eq!(sentinel, 0, "N={n}: ssz_run sentinel must be 0 (Ok), got {sentinel} — codec mismatch");

    let marshal = bench(&buf, csf_bench_marshal_noop);
    let decode_total = bench(&buf, csf_bench_state_transition_ssz_decode);
    let run_total = bench(&buf, csf_bench_state_transition_ssz_run);
    Row {
        n,
        bytes: buf.len(),
        marshal,
        decode: (decode_total - marshal).max(0.0),
        stf: (run_total - decode_total).max(0.0),
        total: run_total,
    }
}

fn main() {
    let include_1m = env::args().any(|s| s == "--include-1m");
    unsafe { boot_lean(); }

    let mut rows: Vec<Row> = N_AXIS.iter().map(|&n| bench_cell(n)).collect();
    if include_1m {
        rows.push(bench_cell(REFERENCE_N));
    }

    println!("# End-to-end SSZ-bytes pipeline: marshal → decode → pure STF");
    println!();
    println!("Fixture = §1 buildBenchState(n)/buildBenchBlock(n), serialized. Codec gate: sentinel 0 (Ok).");
    println!();
    println!("| N | payload | marshal | decode | STF | total (e2e) |");
    println!("|---:|---:|---:|---:|---:|---:|");
    for r in &rows {
        println!(
            "| {} | {} | {} | {} | {} | **{}** |",
            r.n,
            if r.bytes < 1024 * 1024 {
                format!("{:.1} KB", r.bytes as f64 / 1024.0)
            } else {
                format!("{:.1} MB", r.bytes as f64 / (1024.0 * 1024.0))
            },
            fmt_ns(r.marshal),
            fmt_ns(r.decode),
            fmt_ns(r.stf),
            fmt_ns(r.total),
        );
    }
    println!();
    println!(
        "> marshal = alloc+memcpy+dec_ref; decode = ssz_decode−marshal (bytes→typed State/Block); \
         STF = ssz_run−ssz_decode (pure stateTransitionFast). Trials={TRIALS}. \
         Flat codec, no canonical SSZ / hash_tree_root."
    );
}
