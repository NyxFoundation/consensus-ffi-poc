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
--
-- The "real" ToLean marshal layer (A23) is deferred — boxed-lean_object*
-- ABI for Aeneas's UScalar/BitVec/Array types is non-trivial and the
-- smoke goal is reachable with primitive-arg Lean-side builders. The
-- builders below take only `UInt64` / `UInt8` and assemble the State /
-- Block on the Lean side; bench harnesses call them once per iteration
-- before starting the timer, so marshal cost is excluded from the
-- pipeline measurement just like the original plan intended.
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

/-! ## Lean-side smoke fixtures

Hard-coded V=2 inputs so the M4c smoke can drive both pipelines without
the full Rust↔Lean marshal layer. Bench scaling (variable N) requires
either a generalised builder or proper Rust-side ToLean — both deferred. -/

private def smokeValidatorsVec : alloc.vec.Vec types.Validator :=
  let xs : List types.Validator :=
    [ { pubkey := Array.repeat 52#usize 0#u8, index := 0#u64 }
    , { pubkey := Array.repeat 52#usize 0#u8, index := 1#u64 } ]
  ⟨xs, by simp [xs]; scalar_tac⟩

private def smokeGenesisState : types.State :=
  let zeroCp : types.Checkpoint := { root := types.H256.ZERO, slot := 0#u64 }
  let zeroHeader : types.BlockHeader :=
    { slot := 0#u64
      proposer_index := 0#u64
      parent_root := types.H256.ZERO
      state_root := types.H256.ZERO
      body_root := types.H256.ZERO }
  { config := { genesis_time := 0#u64 }
    slot := 0#u64
    latest_block_header := zeroHeader
    latest_justified := zeroCp
    latest_finalized := zeroCp
    historical_block_hashes := alloc.vec.Vec.new types.H256
    justified_slots := alloc.vec.Vec.new Bool
    validators := smokeValidatorsVec
    justifications_roots := alloc.vec.Vec.new types.H256
    justifications_validators := alloc.vec.Vec.new Bool }

-- For 2 validators at slot 1, expected proposer = 1 % 2 = 1.
private def smokeBlockAtSlot1 : types.Block :=
  { slot := 1#u64
    proposer_index := 1#u64
    parent_root := types.H256.ZERO
    state_root := types.H256.ZERO
    body := { attestations := alloc.vec.Vec.new types.AggregatedAttestation } }

-- Same proposer as above but slot=0 reused → process_slots returns
-- StateSlotIsNewer (sentinel 1, the domain-error branch).
private def smokeBlockBadSlot : types.Block :=
  { slot := 0#u64
    proposer_index := 0#u64
    parent_root := types.H256.ZERO
    state_root := types.H256.ZERO
    body := { attestations := alloc.vec.Vec.new types.AggregatedAttestation } }

-- The dummy `_seed` arg keeps Lean's compiler from emitting these as
-- module-level constants (which would land in BSS instead of TEXT and need
-- `extern static` on the Rust side); a function with one scalar arg gets
-- a proper TEXT symbol that Rust can `extern fn` against.

/-- Smoke entry: 2-validator genesis, advance one slot, no attestations. -/
@[export csf_smoke_state_transition_ok]
def csfSmokeStateTransitionOk (_seed : UInt64) : UInt8 :=
  packStatePipeline
    (ConsensusLean4.FastPath.stateTransitionFast smokeGenesisState smokeBlockAtSlot1)

/-- Smoke entry: same state, broken block.slot → domain error sentinel 1. -/
@[export csf_smoke_state_transition_err]
def csfSmokeStateTransitionErr (_seed : UInt64) : UInt8 :=
  packStatePipeline
    (ConsensusLean4.FastPath.stateTransitionFast smokeGenesisState smokeBlockBadSlot)

/-- Smoke entry for fork choice: empty blocks → fall through to (start_root, []). -/
@[export csf_smoke_compute_lmd_ghost_head_empty]
def csfSmokeComputeLmdGhostHeadEmpty (_seed : UInt64) : UInt8 :=
  packForkChoice
    (fork_choice.compute_lmd_ghost_head
      types.H256.ZERO
      (alloc.vec.Vec.new (types.H256 × (Std.U64 × types.H256)))
      (alloc.vec.Vec.new (Std.U64 × types.AttestationData))
      0#u64)
