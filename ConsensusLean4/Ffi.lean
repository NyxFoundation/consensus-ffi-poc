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

/-! ## M5 — parameterised bench fixtures.

Each pair (`csf_bench_*_run`, `csf_bench_*_buildonly`) shares a common
builder so the Rust harness can subtract the construction cost via
paired-delta. Inputs are primitive `UInt64` so no Rust-side ToLean
marshal layer is needed.

For state_transition we keep the workload simple: V (= n) validators with
empty justification roots and no attestations on the block. The N axis
shows up linearly in `processAttestationsFast`'s `collapseJustifications`
(allocates / writes the `R*V` flat bool vector even when R == 0 → V
zeroes seeded by the ZERO sentinel root) plus the `validators` Vec
construction itself. Attestation-rich workloads need a richer fixture
(non-zero historical roots, justified-slot windows, distinct target
checkpoints) — left as future work; the current shape matches what M3's
fast path benchmarks in PR #3 measured.

For compute_lmd_ghost_head the fixture chains B linear blocks starting
from the zero root and assigns A attestations across them, exercising
the Aeneas-generated O(linear in attestations, quadratic in blocks)
walk. -/

@[inline] private def benchValidator : types.Validator :=
  { pubkey := Array.repeat 52#usize 0#u8, index := 0#u64 }

private def buildVecFromList {α : Type} (xs : List α)
    (default : alloc.vec.Vec α) : alloc.vec.Vec α :=
  if h : xs.length ≤ Aeneas.Std.Usize.max then ⟨xs, h⟩ else default

private def buildBenchValidators (n : Nat) : alloc.vec.Vec types.Validator :=
  buildVecFromList (List.replicate n benchValidator)
    (alloc.vec.Vec.new types.Validator)

@[inline] private def u64OfUInt64 (x : UInt64) : Std.U64 :=
  Std.U64.ofNat x.toNat (by
    have hlt : x.toNat < UInt64.size := x.toNat_lt
    have hsize : UInt64.size = 18446744073709551616 := by decide
    rw [Std.UScalar.cMax_eq_pow_cNumBits]
    show x.toNat ≤ 2 ^ Std.UScalarTy.U64.cNumBits - 1
    have hbits : Std.UScalarTy.U64.cNumBits = 64 := rfl
    rw [hbits]; omega)

private def buildBenchState (n : UInt64) : types.State :=
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
    validators := buildBenchValidators n.toNat
    justifications_roots := alloc.vec.Vec.new types.H256
    justifications_validators := alloc.vec.Vec.new Bool }

private def buildBenchBlock (n : UInt64) : types.Block :=
  -- Block at slot 1, proposer = 1 % N (round-robin over the validator set).
  let proposerRaw : UInt64 := if n = 0 then 0 else 1 % n
  { slot := 1#u64
    proposer_index := u64OfUInt64 proposerRaw
    parent_root := types.H256.ZERO
    state_root := types.H256.ZERO
    body := { attestations := alloc.vec.Vec.new types.AggregatedAttestation } }

/-- Build the State + Block for the requested N and run the fast pipeline. -/
@[export csf_bench_state_transition_run]
def csfBenchStateTransitionRun
    (n : UInt64) (_a _seed : UInt64) : UInt8 :=
  let state := buildBenchState n
  let block := buildBenchBlock n
  packStatePipeline
    (ConsensusLean4.FastPath.stateTransitionFast state block)

-- DCE escape hatches. `@[noinline]` forces the call to remain in the
-- emitted IR; XOR'ing the results back into the return value blocks Lean's
-- dead-code elimination from dropping the build entirely (without these
-- the buildonly twin runs in ~1 ns and the paired-delta becomes useless).
@[noinline] private def consumeState (_s : types.State) : UInt8 := 0
@[noinline] private def consumeBlock (_b : types.Block) : UInt8 := 0

/-- Twin: builds the same State + Block but skips the pipeline. The Rust
harness subtracts this from the run timing to isolate pipeline cost from
construction cost (paired-delta). -/
@[export csf_bench_state_transition_buildonly]
def csfBenchStateTransitionBuildOnly
    (n : UInt64) (_a _seed : UInt64) : UInt8 :=
  let state := buildBenchState n
  let block := buildBenchBlock n
  consumeState state ^^^ consumeBlock block

/-! ## Fork-choice bench fixtures. -/

private def hashOfNat (k : Nat) : types.H256 :=
  -- Distinct non-zero hash: every byte = 1 + (k mod 254). Using a single
  -- repeated byte avoids per-cell allocation noise vs. a varying pattern.
  let b : UInt8 := 1 + (k % 254).toUInt8
  let bU : Std.U8 := Std.U8.ofNat b.toNat (by
    have hlt : b.toNat < UInt8.size := b.toNat_lt
    have hsize : UInt8.size = 256 := by decide
    rw [Std.UScalar.cMax_eq_pow_cNumBits]
    show b.toNat ≤ 2 ^ Std.UScalarTy.U8.cNumBits - 1
    have hbits : Std.UScalarTy.U8.cNumBits = 8 := rfl
    rw [hbits]; omega)
  Array.repeat 32#usize bU

private def buildForkChoiceBlocks (b : UInt64) :
    alloc.vec.Vec (types.H256 × (Std.U64 × types.H256)) :=
  -- block 0 chains from start_root (ZERO), block i (i>0) chains from block i-1.
  let bn := b.toNat
  let xs : List (types.H256 × (Std.U64 × types.H256)) :=
    (List.range bn).map fun i =>
      let parent := if i = 0 then types.H256.ZERO else hashOfNat (i - 1)
      let slot   := u64OfUInt64 (UInt64.ofNat (i + 1))
      (hashOfNat i, (slot, parent))
  buildVecFromList xs (alloc.vec.Vec.new (types.H256 × (Std.U64 × types.H256)))

private def buildForkChoiceAttestations (b a : UInt64) :
    alloc.vec.Vec (Std.U64 × types.AttestationData) :=
  -- A attestations targeting the most recent block's root. Validator
  -- indices wrap modulo a sentinel to keep them distinct.
  let an := a.toNat
  let bn := b.toNat
  let targetIdx := if bn = 0 then 0 else bn - 1
  let target : types.Checkpoint :=
    { root := hashOfNat targetIdx
      slot := u64OfUInt64 (UInt64.ofNat (targetIdx + 1)) }
  let zeroCp : types.Checkpoint := { root := types.H256.ZERO, slot := 0#u64 }
  let attData : types.AttestationData :=
    { slot := target.slot, head := target, target := target, source := zeroCp }
  let xs : List (Std.U64 × types.AttestationData) :=
    (List.range an).map fun i =>
      (u64OfUInt64 (UInt64.ofNat i), attData)
  buildVecFromList xs (alloc.vec.Vec.new (Std.U64 × types.AttestationData))

/-- Build B-block fork + A-attestation set, then run the Aeneas fork-choice. -/
@[export csf_bench_compute_lmd_ghost_head_run]
def csfBenchComputeLmdGhostHeadRun
    (b a _seed : UInt64) : UInt8 :=
  let blocks := buildForkChoiceBlocks b
  let atts := buildForkChoiceAttestations b a
  packForkChoice
    (fork_choice.compute_lmd_ghost_head types.H256.ZERO blocks atts 0#u64)

@[noinline] private def consumeBlocksVec
    (_v : alloc.vec.Vec (types.H256 × (Std.U64 × types.H256))) : UInt8 := 0
@[noinline] private def consumeAttsVec
    (_v : alloc.vec.Vec (Std.U64 × types.AttestationData)) : UInt8 := 0

/-- Twin: only build the inputs, then return without invoking fork choice. -/
@[export csf_bench_compute_lmd_ghost_head_buildonly]
def csfBenchComputeLmdGhostHeadBuildOnly
    (b a _seed : UInt64) : UInt8 :=
  let blocks := buildForkChoiceBlocks b
  let atts := buildForkChoiceAttestations b a
  consumeBlocksVec blocks ^^^ consumeAttsVec atts

/-! ## M6 — FFI marshalling cost.

The §1/§2 benches cross only primitive `UInt64`, so they measure Lean-side
compute with the (near-zero) boundary cost cancelled out. This pair measures
the cost the *real* SSZ-bytes boundary (issue #4) would add: a `ByteArray`
(`lean_sarray_object`) is built on the Rust side via the `csf_make_bytearray`
C shim (alloc + memcpy O(size)), handed to the export as an owned argument,
and dec_ref'd by Lean's runtime on return.

No SSZ codec and no `hash_tree_root`/SHA are involved — `ByteArray` is a flat
buffer, so (de)serialization is pure byte layout. `_touch` reads every byte
(XOR-fold), a lower bound on what a real decoder pays to scan its input;
`_noop` only consumes the argument, isolating alloc + memcpy + dec_ref. -/

/-- Touch every byte (decode-scan lower bound). Consumes `data` (dec_ref). -/
@[export csf_bench_marshal_touch]
def csfBenchMarshalTouch (data : ByteArray) : UInt8 :=
  data.foldl (fun acc x => acc ^^^ x) 0

/-- Consume `data` without reading it. Paired-delta twin: the gap from
`_touch` is the Lean-side byte-scan, leaving alloc + memcpy + dec_ref. -/
@[export csf_bench_marshal_noop]
def csfBenchMarshalNoop (_data : ByteArray) : UInt8 := 0
