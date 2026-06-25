// M4c smoke: drive both Aeneas pipelines end-to-end via Lean-side
// fixtures.  The full Rust→Lean ToLean marshal layer is deferred (see
// docs/ffi-implementation-plan.md M4a deviation note); for the smoke we
// call into `csf_smoke_*` Lean exports that build the State / Block
// structures themselves and report a UInt8 sentinel.
//
// Sentinels (cf. ConsensusLean4/Ffi.lean):
//   0 = Ok            1 = domain error
//   2 = Aeneas fail   3 = Aeneas div

use std::ffi::c_void;
use std::ptr;

// Provides `csf_sha256_raw`, called by the `csf_sha256` C shim that Lean's
// `@[extern "csf_sha256"]` binds to.
#[path = "sha_extern.rs"]
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

    fn csf_ping(n: u64) -> u64;
    fn csf_selftest_sha256(seed: u64) -> u8;
    fn csf_selftest_htr(seed: u64) -> u8;
    fn csf_smoke_state_transition_ok(seed: u64) -> u8;
    fn csf_smoke_state_transition_err(seed: u64) -> u8;
    fn csf_smoke_compute_lmd_ghost_head_empty(seed: u64) -> u8;
}

unsafe fn boot_lean() {
    lean_initialize_runtime_module();
    lean_initialize();
    let _ = initialize_consensus_x2dffi_x2dpoc_ConsensusLean4_Ffi(1, ptr::null_mut());
    lean_io_mark_end_initialization();
}

fn sentinel_label(s: u8) -> &'static str {
    match s {
        0 => "Ok",
        1 => "DomainErr",
        2 => "Fail",
        3 => "Div",
        _ => "?",
    }
}

fn main() {
    unsafe {
        boot_lean();

        // M1 carry-over.
        assert_eq!(csf_ping(41), 42);
        println!("[M1] csf_ping(41) = 42 ✓");

        // SHA-256 @[extern] path: Lean → csf_sha256 (C shim) → csf_sha256_raw (Rust/sha2).
        let sha = csf_selftest_sha256(0);
        assert_eq!(sha, 0, "SHA-256(\"abc\") @[extern] self-test failed (got {sha})");
        println!("[sha] csf_selftest_sha256 → 0 ✓ (Lean→C→Rust sha2, NIST \"abc\" vector)");

        // SSZ hash_tree_root self-test: uint64 LE packing + 2-leaf merkleize vs
        // the canonical SSZ zerohashes[1] = sha256(64 zeros).
        let htr = csf_selftest_htr(0);
        assert_eq!(htr, 0, "SSZ hash_tree_root self-test failed (got {htr})");
        println!("[htr] csf_selftest_htr → 0 ✓ (uint64 LE, merkleize, zerohashes[1])");

        // M4c stage 2: state_transition pipeline.
        let r_ok = csf_smoke_state_transition_ok(0);
        println!("[M4c.2] csf_smoke_state_transition_ok  → {r_ok} ({})", sentinel_label(r_ok));
        assert_eq!(r_ok, 0, "expected Ok sentinel");

        let r_err = csf_smoke_state_transition_err(0);
        println!("[M4c.2] csf_smoke_state_transition_err → {r_err} ({})", sentinel_label(r_err));
        assert_eq!(r_err, 1, "expected DomainErr sentinel");

        // M4c stage 3: fork choice pipeline.
        let r_lmd = csf_smoke_compute_lmd_ghost_head_empty(0);
        println!("[M4c.3] csf_smoke_compute_lmd_ghost_head_empty → {r_lmd} ({})",
                 sentinel_label(r_lmd));
        assert_eq!(r_lmd, 0, "expected Ok sentinel");

        println!("all smokes ok");
    }
}
