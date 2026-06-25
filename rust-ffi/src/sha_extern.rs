// SHA-256 primitive exposed to Lean via @[extern].
//
// leanSpec's `hash_tree_root` (spec/crypto/merkleization.py) uses SHA-256.
// The Lean side owns the SSZ merkleization structure (chunking, the binary
// tree, mix_in_length) and calls down to this single compression-grade
// primitive for the heavy work — matching the trust boundary in
// docs/rust-ffi-benchmarks.md §4e ("merkleize structure = Lean, primitive =
// Rust/FFI").
//
// The Lean ABI (reading the input `lean_sarray`, allocating the 32-byte output
// `lean_sarray`, dec_ref of the owned argument) lives in `csf_marshal_shim.c`
// because `lean_alloc_sarray`/`lean_sarray_cptr` are `static inline` in lean.h
// and cannot be linked from Rust. That C shim calls this function.
//
// This module is `#[path]`-included into every binary that links the Lean
// static lib (which references `csf_sha256`), so the `#[no_mangle]` symbol is
// present in each final executable.

/// Compute SHA-256 of `n` bytes at `src`, writing the 32-byte digest to `out`.
///
/// # Safety
/// `src` must point to `n` readable bytes (or `n == 0`), and `out` must point
/// to 32 writable bytes. Called only from the C shim with pointers obtained
/// from a live Lean `lean_sarray`.
#[no_mangle]
pub unsafe extern "C" fn csf_sha256_raw(src: *const u8, n: usize, out: *mut u8) {
    use sha2::{Digest, Sha256};
    let data: &[u8] = if n == 0 {
        &[]
    } else {
        std::slice::from_raw_parts(src, n)
    };
    let digest = Sha256::digest(data);
    std::ptr::copy_nonoverlapping(digest.as_ptr(), out, 32);
}
