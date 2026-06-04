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
