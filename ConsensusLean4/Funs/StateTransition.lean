-- Manually split from the Aeneas-generated `ConsensusLean4/Funs.lean`.
-- Contains the `state_transition.*` namespace; see `ConsensusLean4/Funs.lean` for
-- the umbrella import.
import Aeneas
import ConsensusLean4.Types
import ConsensusLean4.FunsExternal
import ConsensusLean4.Funs.Types
import ConsensusLean4.Funs.JustifiedSlots
open Aeneas Aeneas.Std Result ControlFlow Error
set_option linter.dupNamespace false
set_option linter.hashCommand false
set_option linter.unusedVariables false

set_option maxHeartbeats 1000000

noncomputable section

namespace ethlambda_verification

/-- [ethlambda_verification::state_transition::serialize_justifications]: loop body 0:
    Source: 'crates/verification/src/state_transition.rs', lines 427:4-430:5 -/
@[rust_loop_body]
def state_transition.serialize_justifications_loop0.body
  (justifications : alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  (roots : alloc.vec.Vec types.H256) (i : Std.Usize) :
  Result (ControlFlow ((alloc.vec.Vec types.H256) × Std.Usize) (alloc.vec.Vec
    types.H256))
  := do
  let i1 := alloc.vec.Vec.len justifications
  if i < i1
  then
    let (h, _) ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice (types.H256 ×
        (alloc.vec.Vec Bool))) justifications i
    let roots1 ← alloc.vec.Vec.push roots h
    let i2 ← i + 1#usize
    ok (cont (roots1, i2))
  else ok (done roots)

/-- [ethlambda_verification::state_transition::serialize_justifications]: loop 0:
    Source: 'crates/verification/src/state_transition.rs', lines 427:4-430:5 -/
@[rust_loop]
def state_transition.serialize_justifications_loop0
  (justifications : alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  (roots : alloc.vec.Vec types.H256) (i : Std.Usize) :
  Result (alloc.vec.Vec types.H256)
  := do
  loop
    (fun (roots1, i1) => state_transition.serialize_justifications_loop0.body
      justifications roots1 i1)
    (roots, i)

/-- [ethlambda_verification::state_transition::serialize_justifications]: loop body 2:
    Source: 'crates/verification/src/state_transition.rs', lines 436:8-443:9 -/
@[rust_loop_body]
def state_transition.serialize_justifications_loop1_loop0.body
  (key : types.H256) (roots : alloc.vec.Vec types.H256) (j : Std.Usize) :
  Result (ControlFlow ((alloc.vec.Vec types.H256) × Std.Usize) ((alloc.vec.Vec
    types.H256) × Std.Usize))
  := do
  if j > 0#usize
  then
    let i ← j - 1#usize
    let h ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice types.H256)
        roots i
    let o ← types.H256.Insts.CoreCmpOrd.cmp h key
    let b ← core.cmp.Ordering.Insts.CoreCmpPartialEqOrdering.eq o Ordering.gt
    if b
    then
      let h1 ←
        alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice types.H256)
          roots i
      let (_, index_mut_back) ←
        alloc.vec.Vec.index_mut (core.slice.index.SliceIndexUsizeSlice
          types.H256) roots j
      let roots1 := index_mut_back h1
      ok (cont (roots1, i))
    else ok (done (roots, j))
  else ok (done (roots, j))

/-- [ethlambda_verification::state_transition::serialize_justifications]: loop 2:
    Source: 'crates/verification/src/state_transition.rs', lines 436:8-443:9 -/
@[rust_loop]
def state_transition.serialize_justifications_loop1_loop0
  (roots : alloc.vec.Vec types.H256) (key : types.H256) (j : Std.Usize) :
  Result ((alloc.vec.Vec types.H256) × Std.Usize)
  := do
  loop
    (fun (roots1, j1) =>
      state_transition.serialize_justifications_loop1_loop0.body key roots1 j1)
    (roots, j)

/-- [ethlambda_verification::state_transition::serialize_justifications]: loop body 1:
    Source: 'crates/verification/src/state_transition.rs', lines 433:4-446:5 -/
@[rust_loop_body]
def state_transition.serialize_justifications_loop1.body
  (roots : alloc.vec.Vec types.H256) (si : Std.Usize) :
  Result (ControlFlow ((alloc.vec.Vec types.H256) × Std.Usize) (alloc.vec.Vec
    types.H256))
  := do
  let i := alloc.vec.Vec.len roots
  if si < i
  then
    let key ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice types.H256)
        roots si
    let (roots1, j) ←
      state_transition.serialize_justifications_loop1_loop0 roots key si
    let (_, index_mut_back) ←
      alloc.vec.Vec.index_mut (core.slice.index.SliceIndexUsizeSlice
        types.H256) roots1 j
    let si1 ← si + 1#usize
    let roots2 := index_mut_back key
    ok (cont (roots2, si1))
  else ok (done roots)

/-- [ethlambda_verification::state_transition::serialize_justifications]: loop 1:
    Source: 'crates/verification/src/state_transition.rs', lines 433:4-446:5 -/
@[rust_loop]
def state_transition.serialize_justifications_loop1
  (roots : alloc.vec.Vec types.H256) (si : Std.Usize) :
  Result (alloc.vec.Vec types.H256)
  := do
  loop
    (fun (roots1, si1) => state_transition.serialize_justifications_loop1.body
      roots1 si1)
    (roots, si)

/-- [ethlambda_verification::state_transition::serialize_justifications]: loop body 3:
    Source: 'crates/verification/src/state_transition.rs', lines 452:4-455:5 -/
@[rust_loop_body]
def state_transition.serialize_justifications_loop2.body
  (total_bits : Std.Usize) (justifications_validators : alloc.vec.Vec Bool)
  (bi : Std.Usize) :
  Result (ControlFlow ((alloc.vec.Vec Bool) × Std.Usize) (alloc.vec.Vec Bool))
  := do
  if bi < total_bits
  then
    let justifications_validators1 ←
      alloc.vec.Vec.push justifications_validators false
    let bi1 ← bi + 1#usize
    ok (cont (justifications_validators1, bi1))
  else ok (done justifications_validators)

/-- [ethlambda_verification::state_transition::serialize_justifications]: loop 3:
    Source: 'crates/verification/src/state_transition.rs', lines 452:4-455:5 -/
@[rust_loop]
def state_transition.serialize_justifications_loop2
  (total_bits : Std.Usize) (justifications_validators : alloc.vec.Vec Bool)
  (bi : Std.Usize) :
  Result (alloc.vec.Vec Bool)
  := do
  loop
    (fun (justifications_validators1, bi1) =>
      state_transition.serialize_justifications_loop2.body total_bits
      justifications_validators1 bi1)
    (justifications_validators, bi)

/-- [ethlambda_verification::state_transition::serialize_justifications]: loop body 6:
    Source: 'crates/verification/src/state_transition.rs', lines 466:16-474:17 -/
@[rust_loop_body]
def state_transition.serialize_justifications_loop3_loop0_loop0.body
  (justifications : alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  (validator_count : Std.Usize) (root_idx : Std.Usize) (ji : Std.Usize)
  (justifications_validators : alloc.vec.Vec Bool) (vi : Std.Usize) :
  Result (ControlFlow ((alloc.vec.Vec Bool) × Std.Usize) (alloc.vec.Vec Bool))
  := do
  let p ←
    alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice (types.H256 ×
      (alloc.vec.Vec Bool))) justifications ji
  let (_, v) := p
  let i := alloc.vec.Vec.len v
  if vi < i
  then
    if vi < validator_count
    then
      let (_, v1) := p
      let b ←
        alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice Bool) v1 vi
      let justifications_validators1 ←
        if b
        then
          do
          let i1 ← root_idx * validator_count
          let flat_idx ← i1 + vi
          let i2 := alloc.vec.Vec.len justifications_validators
          if flat_idx < i2
          then
            let (_, index_mut_back) ←
              alloc.vec.Vec.index_mut (core.slice.index.SliceIndexUsizeSlice
                Bool) justifications_validators flat_idx
            ok (index_mut_back true)
          else ok justifications_validators
        else ok justifications_validators
      let vi1 ← vi + 1#usize
      ok (cont (justifications_validators1, vi1))
    else ok (done justifications_validators)
  else ok (done justifications_validators)

/-- [ethlambda_verification::state_transition::serialize_justifications]: loop 6:
    Source: 'crates/verification/src/state_transition.rs', lines 466:16-474:17 -/
@[rust_loop]
def state_transition.serialize_justifications_loop3_loop0_loop0
  (justifications : alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  (validator_count : Std.Usize)
  (justifications_validators : alloc.vec.Vec Bool) (root_idx : Std.Usize)
  (ji : Std.Usize) (vi : Std.Usize) :
  Result (alloc.vec.Vec Bool)
  := do
  loop
    (fun (justifications_validators1, vi1) =>
      state_transition.serialize_justifications_loop3_loop0_loop0.body
      justifications validator_count root_idx ji justifications_validators1
      vi1)
    (justifications_validators, vi)

/-- [ethlambda_verification::state_transition::serialize_justifications]: loop body 5:
    Source: 'crates/verification/src/state_transition.rs', lines 462:8-478:9 -/
@[rust_loop_body]
def state_transition.serialize_justifications_loop3_loop0.body
  (justifications : alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  (validator_count : Std.Usize)
  (justifications_validators : alloc.vec.Vec Bool) (root_idx : Std.Usize)
  (root : types.H256) (ji : Std.Usize) :
  Result (ControlFlow Std.Usize (alloc.vec.Vec Bool))
  := do
  let i := alloc.vec.Vec.len justifications
  if ji < i
  then
    let p ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice (types.H256 ×
        (alloc.vec.Vec Bool))) justifications ji
    let (h, _) := p
    let b ← types.H256.Insts.CoreCmpPartialEqH256.eq h root
    if b
    then
      let justifications_validators1 ←
        state_transition.serialize_justifications_loop3_loop0_loop0
          justifications validator_count justifications_validators root_idx ji
          0#usize
      ok (done justifications_validators1)
    else let ji1 ← ji + 1#usize
         ok (cont ji1)
  else ok (done justifications_validators)

/-- [ethlambda_verification::state_transition::serialize_justifications]: loop 5:
    Source: 'crates/verification/src/state_transition.rs', lines 462:8-478:9 -/
@[rust_loop]
def state_transition.serialize_justifications_loop3_loop0
  (justifications : alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  (validator_count : Std.Usize)
  (justifications_validators : alloc.vec.Vec Bool) (root_idx : Std.Usize)
  (root : types.H256) (ji : Std.Usize) :
  Result (alloc.vec.Vec Bool)
  := do
  loop
    (fun ji1 => state_transition.serialize_justifications_loop3_loop0.body
      justifications validator_count justifications_validators root_idx root
      ji1)
    ji

/-- [ethlambda_verification::state_transition::serialize_justifications]: loop body 4:
    Source: 'crates/verification/src/state_transition.rs', lines 458:4-480:5 -/
@[rust_loop_body]
def state_transition.serialize_justifications_loop3.body
  (justifications : alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  (validator_count : Std.Usize) (roots : alloc.vec.Vec types.H256)
  (justifications_validators : alloc.vec.Vec Bool) (root_idx : Std.Usize) :
  Result (ControlFlow ((alloc.vec.Vec Bool) × Std.Usize) (alloc.vec.Vec Bool))
  := do
  let i := alloc.vec.Vec.len roots
  if root_idx < i
  then
    let root ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice types.H256)
        roots root_idx
    let justifications_validators1 ←
      state_transition.serialize_justifications_loop3_loop0 justifications
        validator_count justifications_validators root_idx root 0#usize
    let root_idx1 ← root_idx + 1#usize
    ok (cont (justifications_validators1, root_idx1))
  else ok (done justifications_validators)

/-- [ethlambda_verification::state_transition::serialize_justifications]: loop 4:
    Source: 'crates/verification/src/state_transition.rs', lines 458:4-480:5 -/
@[rust_loop]
def state_transition.serialize_justifications_loop3
  (justifications : alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  (validator_count : Std.Usize) (roots : alloc.vec.Vec types.H256)
  (justifications_validators : alloc.vec.Vec Bool) (root_idx : Std.Usize) :
  Result (alloc.vec.Vec Bool)
  := do
  loop
    (fun (justifications_validators1, root_idx1) =>
      state_transition.serialize_justifications_loop3.body justifications
      validator_count roots justifications_validators1 root_idx1)
    (justifications_validators, root_idx)

/-- [ethlambda_verification::state_transition::serialize_justifications]:
    Source: 'crates/verification/src/state_transition.rs', lines 419:0-484:1 -/
def state_transition.serialize_justifications
  (state : types.State)
  (justifications : alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  (validator_count : Std.Usize) :
  Result types.State
  := do
  let roots ←
    state_transition.serialize_justifications_loop0 justifications
      (alloc.vec.Vec.new types.H256) 0#usize
  let roots1 ← state_transition.serialize_justifications_loop1 roots 1#usize
  let i := alloc.vec.Vec.len roots1
  let total_bits ← i * validator_count
  let justifications_validators ←
    state_transition.serialize_justifications_loop2 total_bits
      (alloc.vec.Vec.new Bool) 0#usize
  let justifications_validators1 ←
    state_transition.serialize_justifications_loop3 justifications
      validator_count roots1 justifications_validators 0#usize
  ok
    {
      state
        with
        justifications_roots := roots1,
        justifications_validators := justifications_validators1
    }

/-- [ethlambda_verification::state_transition::isqrt]: loop body 0:
    Source: 'crates/verification/src/state_transition.rs', lines 534:4-537:5 -/
@[rust_loop_body]
def state_transition.isqrt_loop.body
  (n : Std.U64) (x : Std.U64) (y : Std.U64) :
  Result (ControlFlow (Std.U64 × Std.U64) Std.U64)
  := do
  if y < x
  then let i ← n / y
       let i1 ← y + i
       let y1 ← i1 / 2#u64
       ok (cont (y, y1))
  else ok (done x)

/-- [ethlambda_verification::state_transition::isqrt]: loop 0:
    Source: 'crates/verification/src/state_transition.rs', lines 534:4-537:5 -/
@[rust_loop]
def state_transition.isqrt_loop
  (n : Std.U64) (x : Std.U64) (y : Std.U64) : Result Std.U64 := do
  loop
    (fun (x1, y1) => state_transition.isqrt_loop.body n x1 y1)
    (x, y)

/-- [ethlambda_verification::state_transition::isqrt]:
    Source: 'crates/verification/src/state_transition.rs', lines 528:0-539:1 -/
def state_transition.isqrt (n : Std.U64) : Result Std.U64 := do
  if n = 0#u64
  then ok 0#u64
  else
    let i ← n + 1#u64
    let y ← i / 2#u64
    state_transition.isqrt_loop n n y

/-- [ethlambda_verification::state_transition::slot_is_justifiable_after]:
    Source: 'crates/verification/src/state_transition.rs', lines 502:0-525:1
    Visibility: public -/
def state_transition.slot_is_justifiable_after
  (slot : Std.U64) (finalized_slot : Std.U64) : Result Bool := do
  if slot < finalized_slot
  then ok false
  else
    let delta ← slot - finalized_slot
    if delta <= 5#u64
    then ok true
    else
      let s ← state_transition.isqrt delta
      let i ← s * s
      if i = delta
      then ok true
      else
        let o ← lift (U64.checked_mul delta 4#u64)
        match o with
        | none => ok false
        | some v =>
          let o1 ← lift (U64.checked_add v 1#u64)
          match o1 with
          | none => ok false
          | some val =>
            let sv ← state_transition.isqrt val
            let i1 ← sv * sv
            if i1 = val
            then let i2 ← val % 2#u64
                 ok (i2 = 1#u64)
            else ok false

/-- [ethlambda_verification::state_transition::try_finalize]: loop body 0:
    Source: 'crates/verification/src/state_transition.rs', lines 370:4-376:5 -/
@[rust_loop_body]
def state_transition.try_finalize_loop0.body
  (state : types.State) (target : types.Checkpoint) (s : Std.U64) :
  Result (ControlFlow Std.U64 (types.State × Bool))
  := do
  if s < target.slot
  then
    let b ←
      state_transition.slot_is_justifiable_after s state.latest_finalized.slot
    if b
    then ok (done (state, true))
    else let s1 ← s + 1#u64
         ok (cont s1)
  else ok (done (state, false))

/-- [ethlambda_verification::state_transition::try_finalize]: loop 0:
    Source: 'crates/verification/src/state_transition.rs', lines 370:4-376:5 -/
@[rust_loop]
def state_transition.try_finalize_loop0
  (state : types.State) (target : types.Checkpoint) (s : Std.U64) :
  Result (types.State × Bool)
  := do
  loop
    (fun s1 => state_transition.try_finalize_loop0.body state target s1)
    s

/-- [ethlambda_verification::state_transition::try_finalize]: loop body 2:
    Source: 'crates/verification/src/state_transition.rs', lines 396:8-402:9 -/
@[rust_loop_body]
def state_transition.try_finalize_loop1_loop0.body
  (root_to_slot : alloc.vec.Vec (types.H256 × Std.U64)) (root : types.H256)
  (ri : Std.Usize) :
  Result (ControlFlow Std.Usize (Option Std.U64))
  := do
  let i := alloc.vec.Vec.len root_to_slot
  if ri < i
  then
    let p ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice (types.H256 ×
        Std.U64)) root_to_slot ri
    let (h, _) := p
    let b ← types.H256.Insts.CoreCmpPartialEqH256.eq h root
    if b
    then let (_, i1) := p
         ok (done (some i1))
    else let ri1 ← ri + 1#usize
         ok (cont ri1)
  else ok (done none)

/-- [ethlambda_verification::state_transition::try_finalize]: loop 2:
    Source: 'crates/verification/src/state_transition.rs', lines 396:8-402:9 -/
@[rust_loop]
def state_transition.try_finalize_loop1_loop0
  (root_to_slot : alloc.vec.Vec (types.H256 × Std.U64)) (root : types.H256)
  (ri : Std.Usize) :
  Result (Option Std.U64)
  := do
  loop
    (fun ri1 => state_transition.try_finalize_loop1_loop0.body root_to_slot
      root ri1)
    ri

/-- [ethlambda_verification::state_transition::try_finalize]: loop body 1:
    Source: 'crates/verification/src/state_transition.rs', lines 391:4-414:5 -/
@[rust_loop_body]
def state_transition.try_finalize_loop1.body
  (i : Std.U64)
  (justifications : alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  (root_to_slot : alloc.vec.Vec (types.H256 × Std.U64))
  (pruned : alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  (pi : Std.Usize) :
  Result (ControlFlow ((alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool))) ×
    Std.Usize) (alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool))))
  := do
  let i1 := alloc.vec.Vec.len justifications
  if pi < i1
  then
    let (root, _) ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice (types.H256 ×
        (alloc.vec.Vec Bool))) justifications pi
    let slot_for_root ←
      state_transition.try_finalize_loop1_loop0 root_to_slot root 0#usize
    let pruned1 ←
      match slot_for_root with
      | none => ok pruned
      | some slot =>
        if slot > i
        then
          do
          let (h, v) ←
            alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice
              (types.H256 × (alloc.vec.Vec Bool))) justifications pi
          let p := (h, v)
          let (_, v1) := p
          let v2 ← alloc.vec.CloneVec.clone core.clone.CloneBool v1
          alloc.vec.Vec.push pruned (h, v2)
        else ok pruned
    let pi1 ← pi + 1#usize
    ok (cont (pruned1, pi1))
  else ok (done pruned)

/-- [ethlambda_verification::state_transition::try_finalize]: loop 1:
    Source: 'crates/verification/src/state_transition.rs', lines 391:4-414:5 -/
@[rust_loop]
def state_transition.try_finalize_loop1
  (i : Std.U64)
  (justifications : alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  (root_to_slot : alloc.vec.Vec (types.H256 × Std.U64))
  (pruned : alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  (pi : Std.Usize) :
  Result (alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  := do
  loop
    (fun (pruned1, pi1) => state_transition.try_finalize_loop1.body i
      justifications root_to_slot pruned1 pi1)
    (pruned, pi)

/-- [ethlambda_verification::state_transition::try_finalize]:
    Source: 'crates/verification/src/state_transition.rs', lines 360:0-416:1 -/
def state_transition.try_finalize
  (state : types.State) (source : types.Checkpoint) (target : types.Checkpoint)
  (justifications : alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  (root_to_slot : alloc.vec.Vec (types.H256 × Std.U64)) :
  Result (types.State × (alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool))))
  := do
  let s ← source.slot + 1#u64
  let (state1, has_gap) ← state_transition.try_finalize_loop0 state target s
  if has_gap
  then ok (state1, justifications)
  else
    let i ← source.slot - state1.latest_finalized.slot
    let delta ← lift (UScalar.cast .Usize i)
    let v ← justified_slots.shift_window state1.justified_slots delta
    let pruned ←
      state_transition.try_finalize_loop1 source.slot justifications
        root_to_slot (alloc.vec.Vec.new (types.H256 × (alloc.vec.Vec Bool)))
        0#usize
    ok ({ state1 with latest_finalized := source, justified_slots := v },
      pruned)

/-- [ethlambda_verification::state_transition::checkpoint_exists]:
    Source: 'crates/verification/src/state_transition.rs', lines 486:0-493:1 -/
def state_transition.checkpoint_exists
  (state : types.State) (checkpoint : types.Checkpoint) : Result Bool := do
  let idx ← lift (UScalar.cast .Usize checkpoint.slot)
  let i := alloc.vec.Vec.len state.historical_block_hashes
  if idx < i
  then
    let h ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice types.H256)
        state.historical_block_hashes idx
    types.H256.Insts.CoreCmpPartialEqH256.eq h checkpoint.root
  else ok false

/-- [ethlambda_verification::state_transition::is_valid_vote]:
    Source: 'crates/verification/src/state_transition.rs', lines 317:0-357:1 -/
def state_transition.is_valid_vote
  (state : types.State) (source : types.Checkpoint) (target : types.Checkpoint)
  :
  Result Bool
  := do
  let b ←
    justified_slots.is_slot_justified state.justified_slots
      state.latest_finalized.slot source.slot
  if b
  then
    let b1 ←
      justified_slots.is_slot_justified state.justified_slots
        state.latest_finalized.slot target.slot
    if b1
    then ok false
    else
      let b2 ← types.H256.is_zero source.root
      if b2
      then ok false
      else
        let b3 ← types.H256.is_zero target.root
        if b3
        then ok false
        else
          let b4 ← state_transition.checkpoint_exists state source
          if b4
          then
            let b5 ← state_transition.checkpoint_exists state target
            if b5
            then
              if target.slot <= source.slot
              then ok false
              else
                let b6 ←
                  state_transition.slot_is_justifiable_after target.slot
                    state.latest_finalized.slot
                if b6
                then ok true
                else ok false
            else ok false
          else ok false
  else ok false

/-- [ethlambda_verification::state_transition::remove_justification]: loop body 0:
    Source: 'crates/verification/src/state_transition.rs', lines 307:4-312:5 -/
@[rust_loop_body]
def state_transition.remove_justification_loop.body
  (justifications : alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  (root : types.H256)
  (new_justifications : alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  (nj : Std.Usize) :
  Result (ControlFlow ((alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool))) ×
    Std.Usize) (alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool))))
  := do
  let i := alloc.vec.Vec.len justifications
  if nj < i
  then
    let p ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice (types.H256 ×
        (alloc.vec.Vec Bool))) justifications nj
    let (h, _) := p
    let b ← types.H256.Insts.CoreCmpPartialEqH256.eq h root
    let new_justifications1 ←
      if b
      then ok new_justifications
      else
        do
        let (h1, _) := p
        let (_, v) := p
        let v1 ← alloc.vec.CloneVec.clone core.clone.CloneBool v
        alloc.vec.Vec.push new_justifications (h1, v1)
    let nj1 ← nj + 1#usize
    ok (cont (new_justifications1, nj1))
  else ok (done new_justifications)

/-- [ethlambda_verification::state_transition::remove_justification]: loop 0:
    Source: 'crates/verification/src/state_transition.rs', lines 307:4-312:5 -/
@[rust_loop]
def state_transition.remove_justification_loop
  (justifications : alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  (root : types.H256)
  (new_justifications : alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  (nj : Std.Usize) :
  Result (alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  := do
  loop
    (fun (new_justifications1, nj1) =>
      state_transition.remove_justification_loop.body justifications root
      new_justifications1 nj1)
    (new_justifications, nj)

/-- [ethlambda_verification::state_transition::remove_justification]:
    Source: 'crates/verification/src/state_transition.rs', lines 304:0-314:1 -/
@[reducible]
def state_transition.remove_justification
  (justifications : alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  (root : types.H256) :
  Result (alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  := do
  state_transition.remove_justification_loop justifications root
    (alloc.vec.Vec.new (types.H256 × (alloc.vec.Vec Bool))) 0#usize

/-- [ethlambda_verification::state_transition::count_votes]: loop body 0:
    Source: 'crates/verification/src/state_transition.rs', lines 294:4-299:5 -/
@[rust_loop_body]
def state_transition.count_votes_loop.body
  (votes : alloc.vec.Vec Bool) (count : Std.Usize) (i : Std.Usize) :
  Result (ControlFlow (Std.Usize × Std.Usize) Std.Usize)
  := do
  let i1 := alloc.vec.Vec.len votes
  if i < i1
  then
    let b ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice Bool) votes i
    let count1 ← if b
                   then count + 1#usize
                   else ok count
    let i2 ← i + 1#usize
    ok (cont (count1, i2))
  else ok (done count)

/-- [ethlambda_verification::state_transition::count_votes]: loop 0:
    Source: 'crates/verification/src/state_transition.rs', lines 294:4-299:5 -/
@[rust_loop]
def state_transition.count_votes_loop
  (votes : alloc.vec.Vec Bool) (count : Std.Usize) (i : Std.Usize) :
  Result Std.Usize
  := do
  loop
    (fun (count1, i1) => state_transition.count_votes_loop.body votes count1
      i1)
    (count, i)

/-- [ethlambda_verification::state_transition::count_votes]:
    Source: 'crates/verification/src/state_transition.rs', lines 291:0-301:1 -/
@[reducible]
def state_transition.count_votes
  (votes : alloc.vec.Vec Bool) : Result Std.Usize := do
  state_transition.count_votes_loop votes 0#usize 0#usize

/-- [ethlambda_verification::state_transition::find_or_create_votes]: loop body 1:
    Source: 'crates/verification/src/state_transition.rs', lines 282:4-285:5 -/
@[rust_loop_body]
def state_transition.find_or_create_votes_loop0_loop0.body
  (validator_count : Std.Usize) (new_votes : alloc.vec.Vec Bool)
  (k : Std.Usize) :
  Result (ControlFlow ((alloc.vec.Vec Bool) × Std.Usize) (alloc.vec.Vec Bool))
  := do
  if k < validator_count
  then
    let new_votes1 ← alloc.vec.Vec.push new_votes false
    let k1 ← k + 1#usize
    ok (cont (new_votes1, k1))
  else ok (done new_votes)

/-- [ethlambda_verification::state_transition::find_or_create_votes]: loop 1:
    Source: 'crates/verification/src/state_transition.rs', lines 282:4-285:5 -/
@[rust_loop]
def state_transition.find_or_create_votes_loop0_loop0
  (validator_count : Std.Usize) (new_votes : alloc.vec.Vec Bool)
  (k : Std.Usize) :
  Result (alloc.vec.Vec Bool)
  := do
  loop
    (fun (new_votes1, k1) =>
      state_transition.find_or_create_votes_loop0_loop0.body validator_count
      new_votes1 k1)
    (new_votes, k)

/-- [ethlambda_verification::state_transition::find_or_create_votes]: loop body 0:
    Source: 'crates/verification/src/state_transition.rs', lines 274:4-288:1 -/
@[rust_loop_body]
def state_transition.find_or_create_votes_loop0.body
  (justifications : alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  (root : types.H256) (validator_count : Std.Usize) (ji : Std.Usize) :
  Result (ControlFlow Std.Usize (Std.Usize × (alloc.vec.Vec (types.H256 ×
    (alloc.vec.Vec Bool)))))
  := do
  let i := alloc.vec.Vec.len justifications
  if ji < i
  then
    let p ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice (types.H256 ×
        (alloc.vec.Vec Bool))) justifications ji
    let (h, _) := p
    let b ← types.H256.Insts.CoreCmpPartialEqH256.eq h root
    if b
    then ok (done (ji, justifications))
    else let ji1 ← ji + 1#usize
         ok (cont ji1)
  else
    let new_votes ←
      state_transition.find_or_create_votes_loop0_loop0 validator_count
        (alloc.vec.Vec.new Bool) 0#usize
    let justifications1 ← alloc.vec.Vec.push justifications (root, new_votes)
    let i1 := alloc.vec.Vec.len justifications1
    let ji1 ← i1 - 1#usize
    ok (done (ji1, justifications1))

/-- [ethlambda_verification::state_transition::find_or_create_votes]: loop 0:
    Source: 'crates/verification/src/state_transition.rs', lines 274:4-288:1 -/
@[rust_loop]
def state_transition.find_or_create_votes_loop0
  (justifications : alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  (root : types.H256) (validator_count : Std.Usize) (ji : Std.Usize) :
  Result (Std.Usize × (alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool))))
  := do
  loop
    (fun ji1 => state_transition.find_or_create_votes_loop0.body justifications
      root validator_count ji1)
    ji

/-- [ethlambda_verification::state_transition::find_or_create_votes]:
    Source: 'crates/verification/src/state_transition.rs', lines 268:0-288:1 -/
@[reducible]
def state_transition.find_or_create_votes
  (justifications : alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  (root : types.H256) (validator_count : Std.Usize) :
  Result (Std.Usize × (alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool))))
  := do
  state_transition.find_or_create_votes_loop0 justifications root
    validator_count 0#usize

/-- [ethlambda_verification::state_transition::process_single_attestation]: loop body 0:
    Source: 'crates/verification/src/state_transition.rs', lines 241:8-246:9 -/
@[rust_loop_body]
def state_transition.process_single_attestation_loop.body
  (v : alloc.vec.Vec Bool) (votes_idx : Std.Usize)
  (justifications : alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  (vid : Std.Usize) :
  Result (ControlFlow ((alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool))) ×
    Std.Usize) (alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool))))
  := do
  let i := alloc.vec.Vec.len v
  if vid < i
  then
    let b ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice Bool) v vid
    let justifications1 ←
      if b
      then
        do
        let (p, index_mut_back) ←
          alloc.vec.Vec.index_mut (core.slice.index.SliceIndexUsizeSlice
            (types.H256 × (alloc.vec.Vec Bool))) justifications votes_idx
        let (h, v1) := p
        let (_, index_mut_back1) ←
          alloc.vec.Vec.index_mut (core.slice.index.SliceIndexUsizeSlice Bool)
            v1 vid
        let v2 := index_mut_back1 true
        ok (index_mut_back (h, v2))
      else ok justifications
    let vid1 ← vid + 1#usize
    ok (cont (justifications1, vid1))
  else ok (done justifications)

/-- [ethlambda_verification::state_transition::process_single_attestation]: loop 0:
    Source: 'crates/verification/src/state_transition.rs', lines 241:8-246:9 -/
@[rust_loop]
def state_transition.process_single_attestation_loop
  (v : alloc.vec.Vec Bool)
  (justifications : alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  (votes_idx : Std.Usize) (vid : Std.Usize) :
  Result (alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  := do
  loop
    (fun (justifications1, vid1) =>
      state_transition.process_single_attestation_loop.body v votes_idx
      justifications1 vid1)
    (justifications, vid)

/-- [ethlambda_verification::state_transition::process_single_attestation]:
    Source: 'crates/verification/src/state_transition.rs', lines 221:0-265:1 -/
def state_transition.process_single_attestation
  (state : types.State) (attestation : types.AggregatedAttestation)
  (validator_count : Std.Usize)
  (justifications : alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  (root_to_slot : alloc.vec.Vec (types.H256 × Std.U64)) :
  Result (types.State × (alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool))))
  := do
  let b ←
    state_transition.is_valid_vote state attestation.data.source
      attestation.data.target
  if b
  then
    let (votes_idx, justifications1) ←
      state_transition.find_or_create_votes justifications
        attestation.data.target.root validator_count
    let i := alloc.vec.Vec.len attestation.aggregation_bits
    if i <= validator_count
    then
      let justifications2 ←
        state_transition.process_single_attestation_loop
          attestation.aggregation_bits justifications1 votes_idx 0#usize
      let p ←
        alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice (types.H256
          × (alloc.vec.Vec Bool))) justifications2 votes_idx
      let (_, v) := p
      let vote_count ← state_transition.count_votes v
      let i1 ← 3#usize * vote_count
      let i2 ← 2#usize * validator_count
      if i1 >= i2
      then
        let v1 ←
          justified_slots.set_justified state.justified_slots
            state.latest_finalized.slot attestation.data.target.slot
        let justifications3 ←
          state_transition.remove_justification justifications2
            attestation.data.target.root
        state_transition.try_finalize
          {
            state
              with
              latest_justified := attestation.data.target,
              justified_slots := v1
          } attestation.data.source attestation.data.target justifications3
          root_to_slot
      else ok (state, justifications2)
    else
      let p ←
        alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice (types.H256
          × (alloc.vec.Vec Bool))) justifications1 votes_idx
      let (_, v) := p
      let vote_count ← state_transition.count_votes v
      let i1 ← 3#usize * vote_count
      let i2 ← 2#usize * validator_count
      if i1 >= i2
      then
        let v1 ←
          justified_slots.set_justified state.justified_slots
            state.latest_finalized.slot attestation.data.target.slot
        let justifications2 ←
          state_transition.remove_justification justifications1
            attestation.data.target.root
        state_transition.try_finalize
          {
            state
              with
              latest_justified := attestation.data.target,
              justified_slots := v1
          } attestation.data.source attestation.data.target justifications2
          root_to_slot
      else ok (state, justifications1)
  else ok (state, justifications)

/-- [ethlambda_verification::state_transition::process_attestations]: loop body 2:
    Source: 'crates/verification/src/state_transition.rs', lines 162:8-171:9 -/
@[rust_loop_body]
def state_transition.process_attestations_loop0_loop0_loop0.body
  (v : alloc.vec.Vec Bool) (validator_count : Std.Usize) (ri : Std.Usize)
  (votes : alloc.vec.Vec Bool) (vi : Std.Usize) :
  Result (ControlFlow ((alloc.vec.Vec Bool) × Std.Usize) (alloc.vec.Vec Bool))
  := do
  if vi < validator_count
  then
    let i ← ri * validator_count
    let flat_idx ← i + vi
    let i1 := alloc.vec.Vec.len v
    let voted ←
      if flat_idx < i1
      then
        alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice Bool) v
          flat_idx
      else ok false
    let votes1 ← alloc.vec.Vec.push votes voted
    let vi1 ← vi + 1#usize
    ok (cont (votes1, vi1))
  else ok (done votes)

/-- [ethlambda_verification::state_transition::process_attestations]: loop 2:
    Source: 'crates/verification/src/state_transition.rs', lines 162:8-171:9 -/
@[rust_loop]
def state_transition.process_attestations_loop0_loop0_loop0
  (v : alloc.vec.Vec Bool) (validator_count : Std.Usize) (ri : Std.Usize)
  (votes : alloc.vec.Vec Bool) (vi : Std.Usize) :
  Result (alloc.vec.Vec Bool)
  := do
  loop
    (fun (votes1, vi1) =>
      state_transition.process_attestations_loop0_loop0_loop0.body v
      validator_count ri votes1 vi1)
    (votes, vi)

/-- [ethlambda_verification::state_transition::process_attestations]: loop body 1:
    Source: 'crates/verification/src/state_transition.rs', lines 158:4-174:5 -/
@[rust_loop_body]
def state_transition.process_attestations_loop0_loop0.body
  (v : alloc.vec.Vec types.H256) (v1 : alloc.vec.Vec Bool)
  (validator_count : Std.Usize)
  (justifications : alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  (ri : Std.Usize) :
  Result (ControlFlow ((alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool))) ×
    Std.Usize) (alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool))))
  := do
  let i := alloc.vec.Vec.len v
  if ri < i
  then
    let root ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice types.H256) v
        ri
    let votes ←
      state_transition.process_attestations_loop0_loop0_loop0 v1
        validator_count ri (alloc.vec.Vec.new Bool) 0#usize
    let justifications1 ← alloc.vec.Vec.push justifications (root, votes)
    let ri1 ← ri + 1#usize
    ok (cont (justifications1, ri1))
  else ok (done justifications)

/-- [ethlambda_verification::state_transition::process_attestations]: loop 1:
    Source: 'crates/verification/src/state_transition.rs', lines 158:4-174:5 -/
@[rust_loop]
def state_transition.process_attestations_loop0_loop0
  (v : alloc.vec.Vec types.H256) (v1 : alloc.vec.Vec Bool)
  (validator_count : Std.Usize)
  (justifications : alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  (ri : Std.Usize) :
  Result (alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  := do
  loop
    (fun (justifications1, ri1) =>
      state_transition.process_attestations_loop0_loop0.body v v1
      validator_count justifications1 ri1)
    (justifications, ri)

/-- [ethlambda_verification::state_transition::process_attestations]: loop body 4:
    Source: 'crates/verification/src/state_transition.rs', lines 185:12-194:13 -/
@[rust_loop_body]
def state_transition.process_attestations_loop0_loop1_loop0.body
  (root_to_slot : alloc.vec.Vec (types.H256 × Std.U64)) (slot : Std.U64)
  (root : types.H256) (mi : Std.Usize) :
  Result (ControlFlow Std.Usize ((alloc.vec.Vec (types.H256 × Std.U64)) ×
    Bool))
  := do
  let i := alloc.vec.Vec.len root_to_slot
  if mi < i
  then
    let p ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice (types.H256 ×
        Std.U64)) root_to_slot mi
    let (h, _) := p
    let b ← types.H256.Insts.CoreCmpPartialEqH256.eq h root
    if b
    then
      let (_, i1) := p
      if slot > i1
      then
        let (p1, index_mut_back) ←
          alloc.vec.Vec.index_mut (core.slice.index.SliceIndexUsizeSlice
            (types.H256 × Std.U64)) root_to_slot mi
        let (h1, _) := p1
        let root_to_slot1 := index_mut_back (h1, slot)
        ok (done (root_to_slot1, true))
      else ok (done (root_to_slot, true))
    else let mi1 ← mi + 1#usize
         ok (cont mi1)
  else ok (done (root_to_slot, false))

/-- [ethlambda_verification::state_transition::process_attestations]: loop 4:
    Source: 'crates/verification/src/state_transition.rs', lines 185:12-194:13 -/
@[rust_loop]
def state_transition.process_attestations_loop0_loop1_loop0
  (root_to_slot : alloc.vec.Vec (types.H256 × Std.U64)) (slot : Std.U64)
  (root : types.H256) (mi : Std.Usize) :
  Result ((alloc.vec.Vec (types.H256 × Std.U64)) × Bool)
  := do
  loop
    (fun mi1 => state_transition.process_attestations_loop0_loop1_loop0.body
      root_to_slot slot root mi1)
    mi

/-- [ethlambda_verification::state_transition::process_attestations]: loop body 3:
    Source: 'crates/verification/src/state_transition.rs', lines 179:4-200:5 -/
@[rust_loop_body]
def state_transition.process_attestations_loop0_loop1.body
  (v : alloc.vec.Vec types.H256)
  (root_to_slot : alloc.vec.Vec (types.H256 × Std.U64)) (slot : Std.U64) :
  Result (ControlFlow ((alloc.vec.Vec (types.H256 × Std.U64)) × Std.U64)
    (alloc.vec.Vec (types.H256 × Std.U64)))
  := do
  let i := alloc.vec.Vec.len v
  let i1 ← lift (UScalar.cast .U64 i)
  if slot < i1
  then
    let s ← lift (UScalar.cast .Usize slot)
    let i2 := alloc.vec.Vec.len v
    if s < i2
    then
      let root ←
        alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice types.H256)
          v s
      let (root_to_slot1, found) ←
        state_transition.process_attestations_loop0_loop1_loop0 root_to_slot
          slot root 0#usize
      let root_to_slot2 ←
        if found
        then ok root_to_slot1
        else alloc.vec.Vec.push root_to_slot1 (root, slot)
      let slot1 ← slot + 1#u64
      ok (cont (root_to_slot2, slot1))
    else let slot1 ← slot + 1#u64
         ok (cont (root_to_slot, slot1))
  else ok (done root_to_slot)

/-- [ethlambda_verification::state_transition::process_attestations]: loop 3:
    Source: 'crates/verification/src/state_transition.rs', lines 179:4-200:5 -/
@[rust_loop]
def state_transition.process_attestations_loop0_loop1
  (v : alloc.vec.Vec types.H256)
  (root_to_slot : alloc.vec.Vec (types.H256 × Std.U64)) (slot : Std.U64) :
  Result (alloc.vec.Vec (types.H256 × Std.U64))
  := do
  loop
    (fun (root_to_slot1, slot1) =>
      state_transition.process_attestations_loop0_loop1.body v root_to_slot1
      slot1)
    (root_to_slot, slot)

/-- [ethlambda_verification::state_transition::process_attestations]: loop body 5:
    Source: 'crates/verification/src/state_transition.rs', lines 204:4-213:5 -/
@[rust_loop_body]
def state_transition.process_attestations_loop0_loop2.body
  (attestations : alloc.vec.Vec types.AggregatedAttestation)
  (validator_count : Std.Usize)
  (root_to_slot : alloc.vec.Vec (types.H256 × Std.U64)) (state : types.State)
  (justifications : alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  (ai : Std.Usize) :
  Result (ControlFlow (types.State × (alloc.vec.Vec (types.H256 ×
    (alloc.vec.Vec Bool))) × Std.Usize) (types.State × (alloc.vec.Vec
    (types.H256 × (alloc.vec.Vec Bool)))))
  := do
  let i := alloc.vec.Vec.len attestations
  if ai < i
  then
    let aa ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice
        types.AggregatedAttestation) attestations ai
    let (state1, justifications1) ←
      state_transition.process_single_attestation state aa validator_count
        justifications root_to_slot
    let ai1 ← ai + 1#usize
    ok (cont (state1, justifications1, ai1))
  else ok (done (state, justifications))

/-- [ethlambda_verification::state_transition::process_attestations]: loop 5:
    Source: 'crates/verification/src/state_transition.rs', lines 204:4-213:5 -/
@[rust_loop]
def state_transition.process_attestations_loop0_loop2
  (state : types.State)
  (attestations : alloc.vec.Vec types.AggregatedAttestation)
  (validator_count : Std.Usize)
  (justifications : alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool)))
  (root_to_slot : alloc.vec.Vec (types.H256 × Std.U64)) (ai : Std.Usize) :
  Result (types.State × (alloc.vec.Vec (types.H256 × (alloc.vec.Vec Bool))))
  := do
  loop
    (fun (state1, justifications1, ai1) =>
      state_transition.process_attestations_loop0_loop2.body attestations
      validator_count root_to_slot state1 justifications1 ai1)
    (state, justifications, ai)

/-- [ethlambda_verification::state_transition::process_attestations]: loop body 0:
    Source: 'crates/verification/src/state_transition.rs', lines 146:4-217:1 -/
@[rust_loop_body]
def state_transition.process_attestations_loop0.body
  (state : types.State)
  (attestations : alloc.vec.Vec types.AggregatedAttestation) (zi : Std.Usize) :
  Result (ControlFlow Std.Usize ((core.result.Result Unit
    state_transition.Error) × types.State))
  := do
  let i := alloc.vec.Vec.len state.justifications_roots
  if zi < i
  then
    let h ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice types.H256)
        state.justifications_roots zi
    let b ← types.H256.is_zero h
    if b
    then
      ok (done (core.result.Result.Err
        state_transition.Error.ZeroHashInJustificationRoots, state))
    else let zi1 ← zi + 1#usize
         ok (cont zi1)
  else
    let validator_count := alloc.vec.Vec.len state.validators
    let justifications ←
      state_transition.process_attestations_loop0_loop0
        state.justifications_roots state.justifications_validators
        validator_count (alloc.vec.Vec.new (types.H256 × (alloc.vec.Vec
        Bool))) 0#usize
    let slot ← state.latest_finalized.slot + 1#u64
    let root_to_slot ←
      state_transition.process_attestations_loop0_loop1
        state.historical_block_hashes (alloc.vec.Vec.new (types.H256 ×
        Std.U64)) slot
    let (state1, justifications1) ←
      state_transition.process_attestations_loop0_loop2 state attestations
        validator_count justifications root_to_slot 0#usize
    let state2 ←
      state_transition.serialize_justifications state1 justifications1
        validator_count
    ok (done (core.result.Result.Ok (), state2))

/-- [ethlambda_verification::state_transition::process_attestations]: loop 0:
    Source: 'crates/verification/src/state_transition.rs', lines 146:4-217:1 -/
@[rust_loop]
def state_transition.process_attestations_loop0
  (state : types.State)
  (attestations : alloc.vec.Vec types.AggregatedAttestation) (zi : Std.Usize) :
  Result ((core.result.Result Unit state_transition.Error) × types.State)
  := do
  loop
    (fun zi1 => state_transition.process_attestations_loop0.body state
      attestations zi1)
    zi

/-- [ethlambda_verification::state_transition::process_attestations]:
    Source: 'crates/verification/src/state_transition.rs', lines 140:0-217:1 -/
@[reducible]
def state_transition.process_attestations
  (state : types.State)
  (attestations : alloc.vec.Vec types.AggregatedAttestation) :
  Result ((core.result.Result Unit state_transition.Error) × types.State)
  := do
  state_transition.process_attestations_loop0 state attestations 0#usize

/-- [ethlambda_verification::state_transition::current_proposer]:
    Source: 'crates/verification/src/state_transition.rs', lines 122:0-128:1 -/
def state_transition.current_proposer
  (slot : Std.U64) (num_validators : Std.U64) : Result (Option Std.U64) := do
  if num_validators > 0#u64
  then let i ← slot % num_validators
       ok (some i)
  else ok none

/-- [ethlambda_verification::state_transition::process_block_header]: loop body 0:
    Source: 'crates/verification/src/state_transition.rs', lines 97:4-100:5 -/
@[rust_loop_body]
def state_transition.process_block_header_loop.body
  (num_empty_slots : Std.Usize) (v : alloc.vec.Vec types.H256) (i : Std.Usize)
  :
  Result (ControlFlow ((alloc.vec.Vec types.H256) × Std.Usize) (alloc.vec.Vec
    types.H256))
  := do
  if i < num_empty_slots
  then
    let v1 ← alloc.vec.Vec.push v types.H256.ZERO
    let i1 ← i + 1#usize
    ok (cont (v1, i1))
  else ok (done v)

/-- [ethlambda_verification::state_transition::process_block_header]: loop 0:
    Source: 'crates/verification/src/state_transition.rs', lines 97:4-100:5 -/
@[rust_loop]
def state_transition.process_block_header_loop
  (v : alloc.vec.Vec types.H256) (num_empty_slots : Std.Usize) (i : Std.Usize)
  :
  Result (alloc.vec.Vec types.H256)
  := do
  loop
    (fun (v1, i1) => state_transition.process_block_header_loop.body
      num_empty_slots v1 i1)
    (v, i)

/-- [ethlambda_verification::state_transition::process_block_header]:
    Source: 'crates/verification/src/state_transition.rs', lines 52:0-119:1 -/
def state_transition.process_block_header
  (state : types.State) (block : types.Block) :
  Result ((core.result.Result Unit state_transition.Error) × types.State)
  := do
  if block.slot != state.slot
  then ok (core.result.Result.Err state_transition.Error.SlotMismatch, state)
  else
    if block.slot <= state.latest_block_header.slot
    then
      ok (core.result.Result.Err state_transition.Error.ParentSlotIsNewer,
        state)
    else
      let i := alloc.vec.Vec.len state.validators
      let num_validators ← lift (UScalar.cast .U64 i)
      let o ← state_transition.current_proposer block.slot num_validators
      match o with
      | none =>
        ok (core.result.Result.Err state_transition.Error.NoValidators, state)
      | some expected_proposer =>
        if block.proposer_index != expected_proposer
        then
          ok (core.result.Result.Err state_transition.Error.InvalidProposer,
            state)
        else
          let parent_root ←
            types.hash_tree_root_block_header state.latest_block_header
          let b ←
            types.H256.Insts.CoreCmpPartialEqH256.eq block.parent_root
              parent_root
          if b
          then
            let (c, c1) ←
              if state.latest_block_header.slot = 0#u64
              then
                ok ({ state.latest_justified with root := parent_root },
                  { state.latest_finalized with root := parent_root })
              else ok (state.latest_justified, state.latest_finalized)
            let i1 ← block.slot - state.latest_block_header.slot
            let i2 ← i1 - 1#u64
            let num_empty_slots ← lift (UScalar.cast .Usize i2)
            let current_len := alloc.vec.Vec.len state.historical_block_hashes
            let i3 ← current_len + 1#usize
            let new_total ← i3 + num_empty_slots
            if new_total > types.HISTORICAL_ROOTS_LIMIT
            then
              ok (core.result.Result.Err
                state_transition.Error.SlotGapTooLarge,
                { state with latest_justified := c, latest_finalized := c1 })
            else
              let v ←
                alloc.vec.Vec.push state.historical_block_hashes parent_root
              let v1 ←
                state_transition.process_block_header_loop v num_empty_slots
                  0#usize
              let last_materialized_slot ← block.slot - 1#u64
              let v2 ←
                justified_slots.extend_to_slot state.justified_slots 
                  c1.slot last_materialized_slot
              let h ← types.hash_tree_root_block_body block.body
              ok (core.result.Result.Ok (),
                {
                  state
                    with
                    latest_block_header :=
                      {
                        slot := block.slot,
                        proposer_index := block.proposer_index,
                        parent_root := block.parent_root,
                        state_root := types.H256.ZERO,
                        body_root := h
                      },
                    latest_justified := c,
                    latest_finalized := c1,
                    historical_block_hashes := v1,
                    justified_slots := v2
                })
          else
            ok (core.result.Result.Err state_transition.Error.InvalidParent,
              state)

/-- [ethlambda_verification::state_transition::process_block]:
    Source: 'crates/verification/src/state_transition.rs', lines 45:0-49:1
    Visibility: public -/
def state_transition.process_block
  (state : types.State) (block : types.Block) :
  Result ((core.result.Result Unit state_transition.Error) × types.State)
  := do
  let (r, state1) ← state_transition.process_block_header state block
  let cf ←
    core.result.Result.Insts.CoreOpsTry_traitTryTResultInfallibleE.branch r
  match cf with
  | core.ops.control_flow.ControlFlow.Continue _ =>
    let (r1, state2) ←
      state_transition.process_attestations state1 block.body.attestations
    let cf1 ←
      core.result.Result.Insts.CoreOpsTry_traitTryTResultInfallibleE.branch r1
    match cf1 with
    | core.ops.control_flow.ControlFlow.Continue _ =>
      ok (core.result.Result.Ok (), state2)
    | core.ops.control_flow.ControlFlow.Break residual =>
      let r2 ←
        core.result.Result.Insts.CoreOpsTry_traitFromResidualResultInfallibleE.from_residual
          Unit (core.convert.FromSame state_transition.Error) residual
      ok (r2, state2)
  | core.ops.control_flow.ControlFlow.Break residual =>
    let r1 ←
      core.result.Result.Insts.CoreOpsTry_traitFromResidualResultInfallibleE.from_residual
        Unit (core.convert.FromSame state_transition.Error) residual
    ok (r1, state1)

/-- [ethlambda_verification::state_transition::process_slots]:
    Source: 'crates/verification/src/state_transition.rs', lines 33:0-42:1
    Visibility: public -/
def state_transition.process_slots
  (state : types.State) (target_slot : Std.U64) :
  Result ((core.result.Result Unit state_transition.Error) × types.State)
  := do
  if state.slot >= target_slot
  then
    ok (core.result.Result.Err state_transition.Error.StateSlotIsNewer, state)
  else
    let b ←
      types.H256.Insts.CoreCmpPartialEqH256.eq
        state.latest_block_header.state_root types.H256.ZERO
    if b
    then
      let h ← types.hash_tree_root_state state
      ok (core.result.Result.Ok (),
        {
          state
            with
            slot := target_slot,
            latest_block_header :=
              { state.latest_block_header with state_root := h }
        })
    else ok (core.result.Result.Ok (), { state with slot := target_slot })

/-- [ethlambda_verification::state_transition::state_transition]:
    Source: 'crates/verification/src/state_transition.rs', lines 21:0-30:1
    Visibility: public -/
def state_transition.state_transition
  (state : types.State) (block : types.Block) :
  Result ((core.result.Result Unit state_transition.Error) × types.State)
  := do
  let (r, state1) ← state_transition.process_slots state block.slot
  let cf ←
    core.result.Result.Insts.CoreOpsTry_traitTryTResultInfallibleE.branch r
  match cf with
  | core.ops.control_flow.ControlFlow.Continue _ =>
    let (r1, state2) ← state_transition.process_block state1 block
    let cf1 ←
      core.result.Result.Insts.CoreOpsTry_traitTryTResultInfallibleE.branch r1
    match cf1 with
    | core.ops.control_flow.ControlFlow.Continue _ =>
      let computed_state_root ← types.hash_tree_root_state state2
      let b ←
        types.H256.Insts.CoreCmpPartialEqH256.eq block.state_root
          computed_state_root
      if b
      then ok (core.result.Result.Ok (), state2)
      else
        ok (core.result.Result.Err state_transition.Error.StateRootMismatch,
          state2)
    | core.ops.control_flow.ControlFlow.Break residual =>
      let r2 ←
        core.result.Result.Insts.CoreOpsTry_traitFromResidualResultInfallibleE.from_residual
          Unit (core.convert.FromSame state_transition.Error) residual
      ok (r2, state2)
  | core.ops.control_flow.ControlFlow.Break residual =>
    let r1 ←
      core.result.Result.Insts.CoreOpsTry_traitFromResidualResultInfallibleE.from_residual
        Unit (core.convert.FromSame state_transition.Error) residual
    ok (r1, state1)

/-- [ethlambda_verification::state_transition::is_proposer]:
    Source: 'crates/verification/src/state_transition.rs', lines 131:0-136:1
    Visibility: public -/
def state_transition.is_proposer
  (validator_index : Std.U64) (slot : Std.U64) (num_validators : Std.U64) :
  Result Bool
  := do
  let o ← state_transition.current_proposer slot num_validators
  match o with
  | none => ok false
  | some p => ok (p = validator_index)

end ethlambda_verification
