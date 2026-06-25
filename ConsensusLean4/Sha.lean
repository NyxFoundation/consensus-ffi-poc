-- SHA-256 primitive, provided by Rust via FFI (sha2 crate) behind the
-- `csf_sha256` C shim (rust-ffi/csf_marshal_shim.c + src/sha_extern.rs).
--
-- leanSpec's `hash_tree_root` (spec/crypto/merkleization.py) is SHA-256. The
-- SSZ merkleization *structure* lives in `ConsensusLean4.Merkleization` (pure
-- Lean); this module is just the boundary to the native primitive. Kept in its
-- own module so both `Merkleization` and `Ffi` can import it without a cycle.
--
-- `lean_alloc_sarray`/`lean_sarray_cptr` are static-inline in lean.h, so the
-- Lean object ABI (read input sarray, allocate the 32-byte output, dec_ref the
-- owned argument) is done in the C shim; the shim calls Rust for the hashing.

/-- SHA-256 of `data`, returning the 32-byte digest as a `ByteArray`. -/
@[extern "csf_sha256"]
opaque csfSha256 (data : ByteArray) : ByteArray

/-- Self-test: SHA-256("abc") = ba7816bf…20015ad (NIST FIPS-180 vector).
Returns 0 on match, 1 on mismatch. The Rust harness asserts 0 at startup to
verify the `@[extern]` primitive is wired before anything relies on it. -/
@[export csf_selftest_sha256]
def csfSelftestSha256 (_seed : UInt64) : UInt8 :=
  let input : ByteArray := ⟨#[0x61, 0x62, 0x63]⟩ -- "abc"
  let got := csfSha256 input
  let want : ByteArray := ⟨#[
    0xba, 0x78, 0x16, 0xbf, 0x8f, 0x01, 0xcf, 0xea,
    0x41, 0x41, 0x40, 0xde, 0x5d, 0xae, 0x22, 0x23,
    0xb0, 0x03, 0x61, 0xa3, 0x96, 0x17, 0x7a, 0x9c,
    0xb4, 0x10, 0xff, 0x61, 0xf2, 0x00, 0x15, 0xad]⟩
  if got.size == 32 && (List.range 32).all (fun i => got.get! i == want.get! i) then 0 else 1
