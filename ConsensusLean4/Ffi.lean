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
import ConsensusLean4.Sha
import ConsensusLean4.Merkleization
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

/-- Fill `blk0`'s `parent_root` / `state_root` so the real (no longer stubbed)
`hash_tree_root` checks in `process_block_header` and the final state-root
comparison both pass. No circularity: the post-state never reads
`block.state_root`, so we (1) set `parent_root = htr(header process_slots
advances to)`, (2) run the pipeline once to obtain the post-state, (3) set
`state_root = htr(post-state)`. Used by every fixture whose block must be
accepted now that `hash_tree_root` is live (SHA-256, ConsensusLean4.Merkle). -/
private def mkConsistentBlock (state : types.State) (blk0 : types.Block) : types.Block :=
  let advancedHeader : types.BlockHeader :=
    { state.latest_block_header with
        state_root := ConsensusLean4.Merkle.hashTreeRootState state }
  let parentRoot := ConsensusLean4.Merkle.hashTreeRootBlockHeader advancedHeader
  let blk1 := { blk0 with parent_root := parentRoot, state_root := types.H256.ZERO }
  match ConsensusLean4.FastPath.stateTransitionFast state blk1 with
  | .ok (_, s2) => { blk1 with state_root := ConsensusLean4.Merkle.hashTreeRootState s2 }
  | .fail _     => blk1  -- unreachable for these fixtures
  | .div        => blk1

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

/-- Smoke entry: 2-validator genesis, advance one slot, no attestations. The block
gets consistent SSZ roots (real hash_tree_root is live) so it is accepted. -/
@[export csf_smoke_state_transition_ok]
def csfSmokeStateTransitionOk (_seed : UInt64) : UInt8 :=
  packStatePipeline
    (ConsensusLean4.FastPath.stateTransitionFast smokeGenesisState
      (mkConsistentBlock smokeGenesisState smokeBlockAtSlot1))

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

/-! ## M5b — spec-realistic attestation workload (A = MAX_ATTESTATIONS_DATA = 8).

The §1 `csf_bench_state_transition_*` fixture runs a block with **zero**
attestations, so `processAttestationsFast`'s O(A·V) hot loop never executes — it
measures only validator-Vec construction, not the STF body. This fixture loads
the block with the leanSpec maximum of 8 distinct, *valid* AggregatedAttestations
so the fast path actually runs.

The genesis is reverse-engineered from `is_valid_vote` / `slot_is_justifiable_after`
/ `current_proposer` (Funs/StateTransition.lean) so all 8 votes pass `voteIsValid`
and stay under the 2/3 finalize threshold (which would otherwise bail to the
Aeneas slow path and measure the wrong thing):
  * finalized slot F = 0; source = (slot 0, historical[0]); slot 0 ≤ F ⇒ justified.
  * 8 targets at slots {1,2,3,4,5,6,9,12}: each > F and `slot_is_justifiable_after`
    (1–5 are ≤ 5, 6/12 are pronic, 9 is a perfect square); `justified_slots`
    starts empty ⇒ every target slot is unjustified.
  * historical[i] = hashOfNat i (non-zero, distinct) ⇒ `checkpoint_exists` holds
    for both source and every target.
  * each `aggregation_bits` sets ⌈V/2⌉ of V bits: yes = ⌈V/2⌉ < 2/3·V ⇒ no bail,
    yet the inner loop still scans all V bits (the O(8·V) cost we want to measure).
  * block at slot 13 with `latest_block_header.slot` = 12 ⇒ `num_empty_slots` = 0,
    so `process_block_header` appends exactly one (ZERO) historical entry and the
    pre-seeded indices 0..12 stay intact. -/

private def attTargetSlots : List Nat := [1, 2, 3, 4, 5, 6, 9, 12]

private def buildAttHistorical : alloc.vec.Vec types.H256 :=
  buildVecFromList ((List.range 13).map hashOfNat) (alloc.vec.Vec.new types.H256)

private def buildAttBits (n : Nat) : alloc.vec.Vec Bool :=
  let half := (n + 1) / 2
  buildVecFromList (List.replicate half true ++ List.replicate (n - half) false)
    (alloc.vec.Vec.new Bool)

private def buildAttestation (n : Nat) (t : Nat) : types.AggregatedAttestation :=
  let source : types.Checkpoint := { root := hashOfNat 0, slot := 0#u64 }
  let target : types.Checkpoint :=
    { root := hashOfNat t, slot := u64OfUInt64 (UInt64.ofNat t) }
  { aggregation_bits := buildAttBits n
    data := { slot := target.slot, head := target, target := target, source := source } }

private def buildAttAttestations (n : Nat) :
    alloc.vec.Vec types.AggregatedAttestation :=
  buildVecFromList (attTargetSlots.map (buildAttestation n))
    (alloc.vec.Vec.new types.AggregatedAttestation)

private def buildBenchStateAtt (n : UInt64) : types.State :=
  let finalizedCp : types.Checkpoint := { root := hashOfNat 0, slot := 0#u64 }
  let header12 : types.BlockHeader :=
    { slot := 12#u64
      proposer_index := 0#u64
      parent_root := types.H256.ZERO
      state_root := types.H256.ZERO
      body_root := types.H256.ZERO }
  { config := { genesis_time := 0#u64 }
    slot := 12#u64
    latest_block_header := header12
    latest_justified := finalizedCp
    latest_finalized := finalizedCp
    historical_block_hashes := buildAttHistorical
    justified_slots := alloc.vec.Vec.new Bool
    validators := buildBenchValidators n.toNat
    justifications_roots := alloc.vec.Vec.new types.H256
    justifications_validators := alloc.vec.Vec.new Bool }

private def buildBenchBlockAtt (n : UInt64) : types.Block :=
  -- Proposer for slot 13 = 13 % V (current_proposer = slot % num_validators).
  -- parent_root / state_root are placeholders; mkConsistentBlock fills the real
  -- SSZ roots so the now-live hash_tree_root checks pass.
  let proposerRaw : UInt64 := if n = 0 then 0 else 13 % n
  { slot := 13#u64
    proposer_index := u64OfUInt64 proposerRaw
    parent_root := types.H256.ZERO
    state_root := types.H256.ZERO
    body := { attestations := buildAttAttestations n.toNat } }

/-- Build the V-validator genesis + 8-valid-vote block (with consistent SSZ roots)
and run the fast pipeline — now including real `hash_tree_root` (SHA-256). The
`_a` slot is the fixed spec attestation count (8), baked into `attTargetSlots`;
kept in the signature so the Rust harness plumbing stays uniform. -/
@[export csf_bench_state_transition_att_run]
def csfBenchStateTransitionAttRun (n _a _seed : UInt64) : UInt8 :=
  let state := buildBenchStateAtt n
  let block := mkConsistentBlock state (buildBenchBlockAtt n)  -- prep (cancels in Δ)
  packStatePipeline (ConsensusLean4.FastPath.stateTransitionFast state block)

/-- Paired-delta twin: run the identical prep (state build + mkConsistentBlock,
which itself runs one pipeline) but skip the *measured* pipeline. Δ = run −
buildonly isolates exactly one real-HTR state transition. -/
@[export csf_bench_state_transition_att_buildonly]
def csfBenchStateTransitionAttBuildOnly (n _a _seed : UInt64) : UInt8 :=
  let state := buildBenchStateAtt n
  let block := mkConsistentBlock state (buildBenchBlockAtt n)
  consumeState state ^^^ consumeBlock block

/-- Verification probe: `justifications_roots` length after the pipeline. With all
8 votes processed (none skipped, no 2/3 bail) the serialiser prepends a ZERO
sentinel root ⇒ length 9. The Rust harness asserts this before timing so a broken
fixture (skipped votes, or a root-mismatch early-out) can't be measured as fast. -/
@[export csf_bench_state_transition_att_cells]
def csfBenchStateTransitionAttCells (n : UInt64) : UInt8 :=
  let state := buildBenchStateAtt n
  let block := mkConsistentBlock state (buildBenchBlockAtt n)
  match ConsensusLean4.FastPath.stateTransitionFast state block with
  | .ok (_, s) => (min s.justifications_roots.val.length 255).toUInt8
  | _          => 0

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

/-! ## M7 — end-to-end: marshal → decode → pure STF.

This wires the full SSZ-bytes path (issue #4) the M6 marshal bench left
disconnected: a `ByteArray` is decoded into the typed `State` / `Block` and
fed to the pure `stateTransitionFast`. The byte layout is a simple flat,
length-prefixed binary codec (NOT canonical SSZ) defined to round-trip with
the Rust serializer in `bench-ffi-ssz.rs`; it covers every field of `State`
and `Block`. No `hash_tree_root`/SHA is involved — decoding is pure layout.

Layout: U64 = 8 bytes LE; H256 = 32 bytes; pubkey = 52 bytes; Bool = 1 byte;
`Vec α` = U64 count then `count` elements. Out-of-range reads return 0
(`ByteArray.get!` default), so the Rust side must supply every byte read. -/

@[inline] private def u8OfUInt8 (x : UInt8) : Std.U8 :=
  Std.U8.ofNat x.toNat (by
    have hlt : x.toNat < UInt8.size := x.toNat_lt
    have hsize : UInt8.size = 256 := by decide
    rw [Std.UScalar.cMax_eq_pow_cNumBits]
    show x.toNat ≤ 2 ^ Std.UScalarTy.U8.cNumBits - 1
    have hbits : Std.UScalarTy.U8.cNumBits = 8 := rfl
    rw [hbits]; omega)

@[inline] private def readU64LE (d : ByteArray) (o : Nat) : UInt64 :=
  let b : Nat → UInt64 := fun i => (d.get! (o + i)).toUInt64
  b 0 ||| (b 1 <<< 8) ||| (b 2 <<< 16) ||| (b 3 <<< 24)
    ||| (b 4 <<< 32) ||| (b 5 <<< 40) ||| (b 6 <<< 48) ||| (b 7 <<< 56)

@[inline] private def rdU64 (d : ByteArray) (o : Nat) : Std.U64 × Nat :=
  (u64OfUInt64 (readU64LE d o), o + 8)

@[inline] private def rdCount (d : ByteArray) (o : Nat) : Nat × Nat :=
  ((readU64LE d o).toNat, o + 8)

private def readH256 (d : ByteArray) (o : Nat) : types.H256 :=
  Array.make 32#usize ((List.range 32).map (fun i => u8OfUInt8 (d.get! (o + i))))

private def readPubkey (d : ByteArray) (o : Nat) : Array Std.U8 52#usize :=
  Array.make 52#usize ((List.range 52).map (fun i => u8OfUInt8 (d.get! (o + i))))

@[inline] private def rdH256 (d : ByteArray) (o : Nat) : types.H256 × Nat :=
  (readH256 d o, o + 32)

private def rdCheckpoint (d : ByteArray) (o : Nat) : types.Checkpoint × Nat :=
  ({ root := readH256 d o, slot := u64OfUInt64 (readU64LE d (o + 32)) }, o + 40)

private def rdHeader (d : ByteArray) (o : Nat) : types.BlockHeader × Nat :=
  ({ slot := u64OfUInt64 (readU64LE d o)
     proposer_index := u64OfUInt64 (readU64LE d (o + 8))
     parent_root := readH256 d (o + 16)
     state_root := readH256 d (o + 48)
     body_root := readH256 d (o + 80) }, o + 112)

private def rdVecH256 (d : ByteArray) (o : Nat) :
    alloc.vec.Vec types.H256 × Nat :=
  let (cnt, o) := rdCount d o
  let xs := (List.range cnt).map (fun i => readH256 d (o + i * 32))
  (buildVecFromList xs (alloc.vec.Vec.new types.H256), o + cnt * 32)

private def rdVecBool (d : ByteArray) (o : Nat) :
    alloc.vec.Vec Bool × Nat :=
  let (cnt, o) := rdCount d o
  let xs := (List.range cnt).map (fun i => d.get! (o + i) != 0)
  (buildVecFromList xs (alloc.vec.Vec.new Bool), o + cnt)

private def rdValidator (d : ByteArray) (o : Nat) : types.Validator × Nat :=
  ({ pubkey := readPubkey d o, index := u64OfUInt64 (readU64LE d (o + 52)) }, o + 60)

private def rdVecValidator (d : ByteArray) (o : Nat) :
    alloc.vec.Vec types.Validator × Nat :=
  let (cnt, o) := rdCount d o
  let xs := (List.range cnt).map (fun i => (rdValidator d (o + i * 60)).1)
  (buildVecFromList xs (alloc.vec.Vec.new types.Validator), o + cnt * 60)

private def rdAttData (d : ByteArray) (o : Nat) : types.AttestationData × Nat :=
  ({ slot := u64OfUInt64 (readU64LE d o)
     head := (rdCheckpoint d (o + 8)).1
     target := (rdCheckpoint d (o + 48)).1
     source := (rdCheckpoint d (o + 88)).1 }, o + 128)

private def rdAggAtt (d : ByteArray) (o : Nat) :
    types.AggregatedAttestation × Nat :=
  let (bits, o) := rdVecBool d o
  let (data, o) := rdAttData d o
  ({ aggregation_bits := bits, data := data }, o)

private def rdAggAttList (d : ByteArray) :
    Nat → Nat → List types.AggregatedAttestation →
    List types.AggregatedAttestation × Nat
  | 0,     o, acc => (acc.reverse, o)
  | k + 1, o, acc => let (a, o') := rdAggAtt d o; rdAggAttList d k o' (a :: acc)

private def rdVecAggAtt (d : ByteArray) (o : Nat) :
    alloc.vec.Vec types.AggregatedAttestation × Nat :=
  let (cnt, o) := rdCount d o
  let (xs, oEnd) := rdAggAttList d cnt o []
  (buildVecFromList xs (alloc.vec.Vec.new types.AggregatedAttestation), oEnd)

private def decodeState (d : ByteArray) (o : Nat) : types.State × Nat :=
  let (genesisTime, o) := rdU64 d o
  let (slot, o) := rdU64 d o
  let (hdr, o) := rdHeader d o
  let (lj, o) := rdCheckpoint d o
  let (lf, o) := rdCheckpoint d o
  let (hbh, o) := rdVecH256 d o
  let (js, o) := rdVecBool d o
  let (vals, o) := rdVecValidator d o
  let (jr, o) := rdVecH256 d o
  let (jv, o) := rdVecBool d o
  ({ config := { genesis_time := genesisTime }
     slot := slot
     latest_block_header := hdr
     latest_justified := lj
     latest_finalized := lf
     historical_block_hashes := hbh
     justified_slots := js
     validators := vals
     justifications_roots := jr
     justifications_validators := jv }, o)

private def decodeBlock (d : ByteArray) (o : Nat) : types.Block × Nat :=
  let (slot, o) := rdU64 d o
  let (proposer, o) := rdU64 d o
  let (parentRoot, o) := rdH256 d o
  let (stateRoot, o) := rdH256 d o
  let (atts, o) := rdVecAggAtt d o
  ({ slot := slot
     proposer_index := proposer
     parent_root := parentRoot
     state_root := stateRoot
     body := { attestations := atts } }, o)

/-- End-to-end: decode `State ++ Block` from `data`, then run the pure fast
state transition. `data` is consumed (dec_ref). -/
@[export csf_bench_state_transition_ssz_run]
def csfBenchStateTransitionSszRun (data : ByteArray) : UInt8 :=
  let (state, o) := decodeState data 0
  let (block, _) := decodeBlock data o
  packStatePipeline (ConsensusLean4.FastPath.stateTransitionFast state block)

/-- Twin: decode only, skip the pipeline. Paired-delta isolates decode cost
(`_ssz_run` − `_ssz_decode` = pure STF; `_ssz_decode` − marshal = decode). -/
@[export csf_bench_state_transition_ssz_decode]
def csfBenchStateTransitionSszDecode (data : ByteArray) : UInt8 :=
  let (state, o) := decodeState data 0
  let (block, _) := decodeBlock data o
  consumeState state ^^^ consumeBlock block

/-! ## Realism probe — scattered aggregation bits + high-entropy roots.

The M5b `*_att_*` fixture sets a *contiguous* ⌈V/2⌉-bit prefix and fills every
H256 with a single repeated byte. Both make the STF cheaper to *measure* than
real data would be: the regular bit prefix is near-ideal for the CPU branch
predictor, and single-byte roots diverge at byte 0 so `H256` comparisons
short-circuit immediately. This section rebuilds the identical workload (same V,
same 8 valid votes, same no-bail / `cells = 9` invariant) but

  * scatters the ⌈V/2⌉ set bits with a fixed Fisher-Yates permutation
    (`mix64` PRNG) so the inner `aggregation_bits` scan is unpredictable, and
  * fills every H256 with a high-entropy `mix64`-derived byte pattern
    (`hashOfNatHE`) — non-zero and injective over the historical index.

The vote count stays exactly ⌈V/2⌉ (< 2/3·V for V ≥ 4) so the fast path is
preserved and `_real_cells` still returns 9. Measuring this against the M5b
baseline isolates the data-pattern (branch-prediction + comparison) component
of the timing — the "optimistic bias" of the synthetic fixture. -/

/-- splitmix64 finalizer — deterministic 64-bit avalanche mix. -/
@[inline] private def mix64 (x : UInt64) : UInt64 :=
  let z := x + 0x9E3779B97F4A7C15
  let z := (z ^^^ (z >>> 30)) * 0xBF58476D1CE4E5B9
  let z := (z ^^^ (z >>> 27)) * 0x94D049BB133111EB
  z ^^^ (z >>> 31)

/-- High-entropy H256: each byte is a `mix64` output, with byte 0 forced
non-zero (so `is_zero` is false) and the last byte set to `k` so distinct
indices yield distinct roots. -/
private def hashOfNatHE (k : Nat) : types.H256 :=
  Array.make 32#usize ((List.range 32).map (fun j =>
    let raw : UInt8 := (mix64 (UInt64.ofNat ((k + 1) * 32 + j))).toUInt8
    let byte : UInt8 :=
      if j == 0 then 1 + (raw % 255)
      else if j == 31 then UInt8.ofNat (k % 256)
      else raw
    u8OfUInt8 byte))

/-- Exactly ⌈n/2⌉ set bits, scattered by a fixed Fisher-Yates shuffle so the
true/false pattern (scanned in index order) is unpredictable to the branch
predictor. Deterministic: the `mix64` RNG is seeded only by the index. -/
private def scatteredBitList (n : Nat) : List Bool := Id.run do
  let half := (n + 1) / 2
  let mut perm := (List.range n).toArray
  let mut i := n
  while i > 1 do
    i := i - 1
    let r := (mix64 (UInt64.ofNat (i + 1))).toNat % (i + 1)
    let tmp := perm[i]!
    perm := perm.set! i perm[r]!
    perm := perm.set! r tmp
  let mut bits := Array.replicate n false
  let mut k := 0
  while k < half do
    bits := bits.set! perm[k]! true
    k := k + 1
  pure bits.toList

private def buildAttBitsScattered (n : Nat) : alloc.vec.Vec Bool :=
  buildVecFromList (scatteredBitList n) (alloc.vec.Vec.new Bool)

private def buildAttHistoricalHE : alloc.vec.Vec types.H256 :=
  buildVecFromList ((List.range 13).map hashOfNatHE) (alloc.vec.Vec.new types.H256)

private def buildAttestationReal (n : Nat) (t : Nat) : types.AggregatedAttestation :=
  let source : types.Checkpoint := { root := hashOfNatHE 0, slot := 0#u64 }
  let target : types.Checkpoint :=
    { root := hashOfNatHE t, slot := u64OfUInt64 (UInt64.ofNat t) }
  { aggregation_bits := buildAttBitsScattered n
    data := { slot := target.slot, head := target, target := target, source := source } }

private def buildAttAttestationsReal (n : Nat) :
    alloc.vec.Vec types.AggregatedAttestation :=
  buildVecFromList (attTargetSlots.map (buildAttestationReal n))
    (alloc.vec.Vec.new types.AggregatedAttestation)

private def buildBenchStateAttReal (n : UInt64) : types.State :=
  let finalizedCp : types.Checkpoint := { root := hashOfNatHE 0, slot := 0#u64 }
  let header12 : types.BlockHeader :=
    { slot := 12#u64
      proposer_index := 0#u64
      parent_root := types.H256.ZERO
      state_root := types.H256.ZERO
      body_root := types.H256.ZERO }
  { config := { genesis_time := 0#u64 }
    slot := 12#u64
    latest_block_header := header12
    latest_justified := finalizedCp
    latest_finalized := finalizedCp
    historical_block_hashes := buildAttHistoricalHE
    justified_slots := alloc.vec.Vec.new Bool
    validators := buildBenchValidators n.toNat
    justifications_roots := alloc.vec.Vec.new types.H256
    justifications_validators := alloc.vec.Vec.new Bool }

private def buildBenchBlockAttReal (n : UInt64) : types.Block :=
  let proposerRaw : UInt64 := if n = 0 then 0 else 13 % n
  { slot := 13#u64
    proposer_index := u64OfUInt64 proposerRaw
    parent_root := types.H256.ZERO
    state_root := types.H256.ZERO
    body := { attestations := buildAttAttestationsReal n.toNat } }

/-- Realistic counterpart to `csf_bench_state_transition_att_run`: scattered
bits + high-entropy roots, otherwise identical. -/
@[export csf_bench_state_transition_att_real_run]
def csfBenchStateTransitionAttRealRun (n _a _seed : UInt64) : UInt8 :=
  let state := buildBenchStateAttReal n
  let block := mkConsistentBlock state (buildBenchBlockAttReal n)
  packStatePipeline (ConsensusLean4.FastPath.stateTransitionFast state block)

@[export csf_bench_state_transition_att_real_buildonly]
def csfBenchStateTransitionAttRealBuildOnly (n _a _seed : UInt64) : UInt8 :=
  let state := buildBenchStateAttReal n
  let block := mkConsistentBlock state (buildBenchBlockAttReal n)
  consumeState state ^^^ consumeBlock block

@[export csf_bench_state_transition_att_real_cells]
def csfBenchStateTransitionAttRealCells (n : UInt64) : UInt8 :=
  let state := buildBenchStateAttReal n
  let block := mkConsistentBlock state (buildBenchBlockAttReal n)
  match ConsensusLean4.FastPath.stateTransitionFast state block with
  | .ok (_, s) => (min s.justifications_roots.val.length 255).toUInt8
  | _          => 0
