-- FFI surface for the Rust benchmark harness.
--
-- Each `@[export csf_*]` symbol becomes a stable C entry point in
-- `.lake/build/ir/ConsensusLean4/Ffi.c.o.export` that Rust links against.
-- Conventions (cf. docs/ffi-implementation-plan.md A16/A17/A25/A27):
--   * `lean_object*` arguments are owned (single-use); the wrapper consumes
--     them and Lean's runtime is responsible for dec_ref. Rust never frees.
--   * Return value is a UInt8 sentinel:
--       0 = pipeline returned Ok
--       1 = pipeline returned a domain error (state_transition.Error etc.)
--       2 = Aeneas Result.fail (panic / overflow / out-of-bounds)
--       3 = Aeneas Result.div (non-termination)
--   * `*_noop` twins discard the inputs and return 0 immediately. Used as
--     paired-delta references so benchmarks subtract pure FFI/dec_ref cost.
import ConsensusLean4.FastPath
import ConsensusLean4.Funs
import ConsensusLean4.Types
open Aeneas Aeneas.Std ethlambda_verification

set_option maxHeartbeats 1000000

@[export csf_ping]
def csfPing (n : UInt64) : UInt64 := n + 1

@[inline] private def packStatePipeline
    (r : Aeneas.Std.Result ((core.result.Result Unit state_transition.Error)
        × types.State)) : UInt8 :=
  match r with
  | .ok  (.Ok _,  _) => 0
  | .ok  (.Err _, _) => 1
  | .fail _          => 2
  | .div             => 3

@[inline] private def packForkChoice
    (r : Aeneas.Std.Result (types.H256
        × alloc.vec.Vec (types.H256 × Std.U64))) : UInt8 :=
  match r with
  | .ok  _   => 0
  | .fail _  => 2
  | .div     => 3

/-- Run the handwritten Array-backed pipeline and pack the result. -/
@[export csf_state_transition]
def csfStateTransition (state : types.State) (block : types.Block) : UInt8 :=
  packStatePipeline (ConsensusLean4.FastPath.stateTransitionFast state block)

/-- Twin for paired-delta. Inputs are still consumed by Lean's runtime so the
boundary cost (dec_ref of the State/Block trees) is captured here too. -/
@[export csf_state_transition_noop]
def csfStateTransitionNoop (_state : types.State) (_block : types.Block) :
    UInt8 := 0

/-- Direct passthrough to the Aeneas-generated fork choice (linear in attestations,
quadratic in blocks). N (validators) does not appear in this signature. -/
@[export csf_compute_lmd_ghost_head]
def csfComputeLmdGhostHead
    (start_root : types.H256)
    (blocks : alloc.vec.Vec (types.H256 × (Std.U64 × types.H256)))
    (attestations : alloc.vec.Vec (Std.U64 × types.AttestationData))
    (min_score : Std.U64) : UInt8 :=
  packForkChoice
    (fork_choice.compute_lmd_ghost_head start_root blocks attestations min_score)

@[export csf_compute_lmd_ghost_head_noop]
def csfComputeLmdGhostHeadNoop
    (_start_root : types.H256)
    (_blocks : alloc.vec.Vec (types.H256 × (Std.U64 × types.H256)))
    (_attestations : alloc.vec.Vec (Std.U64 × types.AttestationData))
    (_min_score : Std.U64) : UInt8 := 0
