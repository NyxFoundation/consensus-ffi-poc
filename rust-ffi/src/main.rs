// M1 smoke: confirm the Lean ↔ Rust FFI boundary works end-to-end.
//
// Initialization order is exact and must run once per process:
//   1. lean_initialize_runtime_module — sets up allocator, thread-local state.
//   2. lean_initialize                — installs the IO world.
//   3. initialize_<package>_<entry>    — top-level only; the runtime walks
//      the import graph transitively.
//   4. lean_io_mark_end_initialization — flips the runtime out of init mode.

use std::ffi::c_void;
use std::ptr;

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
    fn csf_ping(n: u64) -> u64;
}

unsafe fn boot_lean() {
    lean_initialize_runtime_module();
    lean_initialize();
    let _ = initialize_consensus_x2dlean4_ConsensusLean4_Ffi(1, ptr::null_mut());
    lean_io_mark_end_initialization();
}

fn main() {
    unsafe {
        boot_lean();

        let r = csf_ping(41);
        assert_eq!(r, 42, "csf_ping(41) returned {r}, expected 42");
        println!("csf_ping(41) = {r} ✓");

        let r2 = csf_ping(0);
        assert_eq!(r2, 1);
        let r3 = csf_ping(u64::MAX - 1);
        assert_eq!(r3, u64::MAX);
        println!("edge cases ok");
    }
}
