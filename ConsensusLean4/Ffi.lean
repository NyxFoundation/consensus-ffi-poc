-- FFI surface for the Rust benchmark harness.
-- Each `@[export csf_*]` symbol becomes a stable C entry point in
-- `.lake/build/ir/ConsensusLean4/Ffi.c.o.export` that Rust links against.

set_option maxHeartbeats 1000000

@[export csf_ping]
def csfPing (n : UInt64) : UInt64 := n + 1
