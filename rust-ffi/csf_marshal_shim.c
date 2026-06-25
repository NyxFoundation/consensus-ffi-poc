/* FFI marshalling shim for the M6 bench (see ConsensusLean4/Ffi.lean).
 *
 * `lean_alloc_sarray` / `lean_sarray_cptr` are `static inline` in lean.h, so
 * Rust cannot link them directly. This shim, compiled against lean.h (build.rs
 * adds <toolchain>/include), exposes a single non-inline entry point that
 * builds an owned Lean `ByteArray` from a raw buffer.
 *
 * The returned object is passed (owned) to a `csf_bench_marshal_*` export,
 * which Lean's runtime dec_refs on return — the caller must not free it.
 */
#include <lean/lean.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

/* Build an owned Lean ByteArray (lean_sarray_object) holding a copy of `src`. */
lean_object *csf_make_bytearray(const uint8_t *src, size_t n) {
  lean_object *arr = lean_alloc_sarray(1, n, n);
  if (n) {
    memcpy(lean_sarray_cptr(arr), src, n);
  }
  return arr;
}

/* SHA-256 entry point for Lean's `@[extern "csf_sha256"]`.
 *
 * Signature matches Lean's compiled `ByteArray -> ByteArray`:
 * `data` is an owned `lean_sarray` argument (consumed here); the return is a
 * freshly-allocated owned 32-byte `lean_sarray`. The actual hashing is done in
 * Rust (`csf_sha256_raw`, src/sha_extern.rs, sha2 crate); this wrapper only
 * bridges the Lean object ABI that needs lean.h's static-inline accessors. */
void csf_sha256_raw(const uint8_t *src, size_t n, uint8_t *out);

lean_object *csf_sha256(lean_object *data) {
  size_t n = lean_sarray_size(data);
  const uint8_t *src = lean_sarray_cptr(data);
  lean_object *out = lean_alloc_sarray(1, 32, 32);
  csf_sha256_raw(src, n, lean_sarray_cptr(out));
  lean_dec(data); /* owned argument */
  return out;
}
