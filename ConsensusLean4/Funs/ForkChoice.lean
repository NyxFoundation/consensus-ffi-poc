-- Manually split from the Aeneas-generated `ConsensusLean4/Funs.lean`.
-- Contains the `fork_choice.*` namespace; see `ConsensusLean4/Funs.lean` for
-- the umbrella import.
import Aeneas
import ConsensusLean4.Types
import ConsensusLean4.FunsExternal
import ConsensusLean4.Funs.Types
open Aeneas Aeneas.Std Result ControlFlow Error
set_option linter.dupNamespace false
set_option linter.hashCommand false
set_option linter.unusedVariables false

set_option maxHeartbeats 1000000

noncomputable section

namespace ethlambda_verification

/-- [ethlambda_verification::fork_choice::compute_block_weights]: loop body 3:
    Source: 'crates/verification/src/fork_choice.rs', lines 30:24-37:25
    Visibility: public -/
@[rust_loop_body]
def fork_choice.compute_block_weights_loop0_loop0_loop0_loop0.body
  (weights : alloc.vec.Vec (types.H256 × Std.U64)) (current_root : types.H256)
  (wi : Std.Usize) :
  Result (ControlFlow Std.Usize ((alloc.vec.Vec (types.H256 × Std.U64)) ×
    Bool))
  := do
  let i := alloc.vec.Vec.len weights
  if wi < i
  then
    let p ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice (types.H256 ×
        Std.U64)) weights wi
    let (h, _) := p
    let b ← types.H256.Insts.CoreCmpPartialEqH256.eq h current_root
    if b
    then
      let (p1, index_mut_back) ←
        alloc.vec.Vec.index_mut (core.slice.index.SliceIndexUsizeSlice
          (types.H256 × Std.U64)) weights wi
      let (h1, i1) := p1
      let i2 ← i1 + 1#u64
      let weights1 := index_mut_back (h1, i2)
      ok (done (weights1, true))
    else let wi1 ← wi + 1#usize
         ok (cont wi1)
  else ok (done (weights, false))

/-- [ethlambda_verification::fork_choice::compute_block_weights]: loop 3:
    Source: 'crates/verification/src/fork_choice.rs', lines 30:24-37:25
    Visibility: public -/
@[rust_loop]
def fork_choice.compute_block_weights_loop0_loop0_loop0_loop0
  (weights : alloc.vec.Vec (types.H256 × Std.U64)) (current_root : types.H256)
  (wi : Std.Usize) :
  Result ((alloc.vec.Vec (types.H256 × Std.U64)) × Bool)
  := do
  loop
    (fun wi1 => fork_choice.compute_block_weights_loop0_loop0_loop0_loop0.body
      weights current_root wi1)
    wi

/-- [ethlambda_verification::fork_choice::compute_block_weights]: loop body 2:
    Source: 'crates/verification/src/fork_choice.rs', lines 22:12-47:13
    Visibility: public -/
@[rust_loop_body]
def fork_choice.compute_block_weights_loop0_loop0_loop0.body
  (start_slot : Std.U64)
  (blocks : alloc.vec.Vec (types.H256 × (Std.U64 × types.H256)))
  (weights : alloc.vec.Vec (types.H256 × Std.U64)) (current_root : types.H256)
  (bi : Std.Usize) :
  Result (ControlFlow Std.Usize ((alloc.vec.Vec (types.H256 × Std.U64)) ×
    types.H256 × Bool))
  := do
  let i := alloc.vec.Vec.len blocks
  if bi < i
  then
    let p ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice (types.H256 ×
        (Std.U64 × types.H256))) blocks bi
    let (h, _) := p
    let b ← types.H256.Insts.CoreCmpPartialEqH256.eq h current_root
    if b
    then
      let (_, p1) := p
      let (slot, _) := p1
      let (_, p2) := p
      let (_, parent_root) := p2
      if slot > start_slot
      then
        let (weights1, weight_found) ←
          fork_choice.compute_block_weights_loop0_loop0_loop0_loop0 weights
            current_root 0#usize
        if weight_found
        then ok (done (weights1, parent_root, true))
        else
          let weights2 ← alloc.vec.Vec.push weights1 (current_root, 1#u64)
          ok (done (weights2, parent_root, true))
      else ok (done (weights, current_root, false))
    else let bi1 ← bi + 1#usize
         ok (cont bi1)
  else ok (done (weights, current_root, false))

/-- [ethlambda_verification::fork_choice::compute_block_weights]: loop 2:
    Source: 'crates/verification/src/fork_choice.rs', lines 22:12-47:13
    Visibility: public -/
@[rust_loop]
def fork_choice.compute_block_weights_loop0_loop0_loop0
  (start_slot : Std.U64)
  (blocks : alloc.vec.Vec (types.H256 × (Std.U64 × types.H256)))
  (weights : alloc.vec.Vec (types.H256 × Std.U64)) (current_root : types.H256)
  (bi : Std.Usize) :
  Result ((alloc.vec.Vec (types.H256 × Std.U64)) × types.H256 × Bool)
  := do
  loop
    (fun bi1 => fork_choice.compute_block_weights_loop0_loop0_loop0.body
      start_slot blocks weights current_root bi1)
    bi

/-- [ethlambda_verification::fork_choice::compute_block_weights]: loop body 1:
    Source: 'crates/verification/src/fork_choice.rs', lines 19:8-48:9
    Visibility: public -/
@[rust_loop_body]
def fork_choice.compute_block_weights_loop0_loop0.body
  (start_slot : Std.U64)
  (blocks : alloc.vec.Vec (types.H256 × (Std.U64 × types.H256)))
  (weights : alloc.vec.Vec (types.H256 × Std.U64)) (current_root : types.H256)
  (found : Bool) :
  Result (ControlFlow ((alloc.vec.Vec (types.H256 × Std.U64)) × types.H256 ×
    Bool) (alloc.vec.Vec (types.H256 × Std.U64)))
  := do
  if found
  then
    let (weights1, current_root1, found1) ←
      fork_choice.compute_block_weights_loop0_loop0_loop0 start_slot blocks
        weights current_root 0#usize
    ok (cont (weights1, current_root1, found1))
  else ok (done weights)

/-- [ethlambda_verification::fork_choice::compute_block_weights]: loop 1:
    Source: 'crates/verification/src/fork_choice.rs', lines 19:8-48:9
    Visibility: public -/
@[rust_loop]
def fork_choice.compute_block_weights_loop0_loop0
  (start_slot : Std.U64)
  (blocks : alloc.vec.Vec (types.H256 × (Std.U64 × types.H256)))
  (weights : alloc.vec.Vec (types.H256 × Std.U64)) (current_root : types.H256)
  (found : Bool) :
  Result (alloc.vec.Vec (types.H256 × Std.U64))
  := do
  loop
    (fun (weights1, current_root1, found1) =>
      fork_choice.compute_block_weights_loop0_loop0.body start_slot blocks
      weights1 current_root1 found1)
    (weights, current_root, found)

/-- [ethlambda_verification::fork_choice::compute_block_weights]: loop body 0:
    Source: 'crates/verification/src/fork_choice.rs', lines 15:4-50:5
    Visibility: public -/
@[rust_loop_body]
def fork_choice.compute_block_weights_loop0.body
  (start_slot : Std.U64)
  (blocks : alloc.vec.Vec (types.H256 × (Std.U64 × types.H256)))
  (attestations : alloc.vec.Vec (Std.U64 × types.AttestationData))
  (weights : alloc.vec.Vec (types.H256 × Std.U64)) (ai : Std.Usize) :
  Result (ControlFlow ((alloc.vec.Vec (types.H256 × Std.U64)) × Std.Usize)
    (alloc.vec.Vec (types.H256 × Std.U64)))
  := do
  let i := alloc.vec.Vec.len attestations
  if ai < i
  then
    let p ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice (Std.U64 ×
        types.AttestationData)) attestations ai
    let (_, attestation_data) := p
    let weights1 ←
      fork_choice.compute_block_weights_loop0_loop0 start_slot blocks weights
        attestation_data.head.root true
    let ai1 ← ai + 1#usize
    ok (cont (weights1, ai1))
  else ok (done weights)

/-- [ethlambda_verification::fork_choice::compute_block_weights]: loop 0:
    Source: 'crates/verification/src/fork_choice.rs', lines 15:4-50:5
    Visibility: public -/
@[rust_loop]
def fork_choice.compute_block_weights_loop0
  (start_slot : Std.U64)
  (blocks : alloc.vec.Vec (types.H256 × (Std.U64 × types.H256)))
  (attestations : alloc.vec.Vec (Std.U64 × types.AttestationData))
  (weights : alloc.vec.Vec (types.H256 × Std.U64)) (ai : Std.Usize) :
  Result (alloc.vec.Vec (types.H256 × Std.U64))
  := do
  loop
    (fun (weights1, ai1) => fork_choice.compute_block_weights_loop0.body
      start_slot blocks attestations weights1 ai1)
    (weights, ai)

/-- [ethlambda_verification::fork_choice::compute_block_weights]:
    Source: 'crates/verification/src/fork_choice.rs', lines 7:0-53:1
    Visibility: public -/
@[reducible]
def fork_choice.compute_block_weights
  (start_slot : Std.U64)
  (blocks : alloc.vec.Vec (types.H256 × (Std.U64 × types.H256)))
  (attestations : alloc.vec.Vec (Std.U64 × types.AttestationData)) :
  Result (alloc.vec.Vec (types.H256 × Std.U64))
  := do
  fork_choice.compute_block_weights_loop0 start_slot blocks attestations
    (alloc.vec.Vec.new (types.H256 × Std.U64)) 0#usize

/-- [ethlambda_verification::fork_choice::get_weight]: loop body 0:
    Source: 'crates/verification/src/fork_choice.rs', lines 58:4-65:1 -/
@[rust_loop_body]
def fork_choice.get_weight_loop.body
  (weights : alloc.vec.Vec (types.H256 × Std.U64)) (root : types.H256)
  (i : Std.Usize) :
  Result (ControlFlow Std.Usize Std.U64)
  := do
  let i1 := alloc.vec.Vec.len weights
  if i < i1
  then
    let p ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice (types.H256 ×
        Std.U64)) weights i
    let (h, _) := p
    let b ← types.H256.Insts.CoreCmpPartialEqH256.eq h root
    if b
    then let (_, i2) := p
         ok (done i2)
    else let i2 ← i + 1#usize
         ok (cont i2)
  else ok (done 0#u64)

/-- [ethlambda_verification::fork_choice::get_weight]: loop 0:
    Source: 'crates/verification/src/fork_choice.rs', lines 58:4-65:1 -/
@[rust_loop]
def fork_choice.get_weight_loop
  (weights : alloc.vec.Vec (types.H256 × Std.U64)) (root : types.H256)
  (i : Std.Usize) :
  Result Std.U64
  := do
  loop
    (fun i1 => fork_choice.get_weight_loop.body weights root i1)
    i

/-- [ethlambda_verification::fork_choice::get_weight]:
    Source: 'crates/verification/src/fork_choice.rs', lines 56:0-65:1 -/
@[reducible]
def fork_choice.get_weight
  (weights : alloc.vec.Vec (types.H256 × Std.U64)) (root : types.H256) :
  Result Std.U64
  := do
  fork_choice.get_weight_loop weights root 0#usize

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]: loop body 0:
    Source: 'crates/verification/src/fork_choice.rs', lines 84:8-90:9
    Visibility: public -/
@[rust_loop_body]
def fork_choice.compute_lmd_ghost_head_loop0.body
  (blocks : alloc.vec.Vec (types.H256 × (Std.U64 × types.H256)))
  (min_slot : Std.U64) (min_root : Option types.H256) (i : Std.Usize) :
  Result (ControlFlow (Std.U64 × (Option types.H256) × Std.Usize) (Option
    types.H256))
  := do
  let i1 := alloc.vec.Vec.len blocks
  if i < i1
  then
    let (h, p) ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice (types.H256 ×
        (Std.U64 × types.H256))) blocks i
    let (i2, _) := p
    let (min_slot1, min_root1) ←
      if i2 < min_slot
      then let (min_slot2, _) := p
           ok (min_slot2, some h)
      else ok (min_slot, min_root)
    let i3 ← i + 1#usize
    ok (cont (min_slot1, min_root1, i3))
  else ok (done min_root)

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]: loop 0:
    Source: 'crates/verification/src/fork_choice.rs', lines 84:8-90:9
    Visibility: public -/
@[rust_loop]
def fork_choice.compute_lmd_ghost_head_loop0
  (blocks : alloc.vec.Vec (types.H256 × (Std.U64 × types.H256)))
  (min_slot : Std.U64) (min_root : Option types.H256) (i : Std.Usize) :
  Result (Option types.H256)
  := do
  loop
    (fun (min_slot1, min_root1, i1) =>
      fork_choice.compute_lmd_ghost_head_loop0.body blocks min_slot1 min_root1
      i1)
    (min_slot, min_root, i)

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]: loop body 1:
    Source: 'crates/verification/src/fork_choice.rs', lines 101:4-108:5
    Visibility: public -/
@[rust_loop_body]
def fork_choice.compute_lmd_ghost_head_loop1.body
  (start_root : types.H256)
  (blocks : alloc.vec.Vec (types.H256 × (Std.U64 × types.H256)))
  (si : Std.Usize) :
  Result (ControlFlow Std.Usize (Std.U64 × Bool))
  := do
  let i := alloc.vec.Vec.len blocks
  if si < i
  then
    let p ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice (types.H256 ×
        (Std.U64 × types.H256))) blocks si
    let (h, _) := p
    let b ← types.H256.Insts.CoreCmpPartialEqH256.eq h start_root
    if b
    then
      let (_, p1) := p
      let (start_slot, _) := p1
      ok (done (start_slot, true))
    else let si1 ← si + 1#usize
         ok (cont si1)
  else ok (done (0#u64, false))

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]: loop 1:
    Source: 'crates/verification/src/fork_choice.rs', lines 101:4-108:5
    Visibility: public -/
@[rust_loop]
def fork_choice.compute_lmd_ghost_head_loop1
  (start_root : types.H256)
  (blocks : alloc.vec.Vec (types.H256 × (Std.U64 × types.H256)))
  (si : Std.Usize) :
  Result (Std.U64 × Bool)
  := do
  loop
    (fun si1 => fork_choice.compute_lmd_ghost_head_loop1.body start_root blocks
      si1)
    si

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]: loop body 3:
    Source: 'crates/verification/src/fork_choice.rs', lines 128:16-135:17
    Visibility: public -/
@[rust_loop_body]
def fork_choice.compute_lmd_ghost_head_loop2_loop0.body
  (children_map : alloc.vec.Vec (types.H256 × (alloc.vec.Vec types.H256)))
  (root : types.H256) (parent_root : types.H256) (ci : Std.Usize) :
  Result (ControlFlow Std.Usize ((alloc.vec.Vec (types.H256 × (alloc.vec.Vec
    types.H256))) × Bool))
  := do
  let i := alloc.vec.Vec.len children_map
  if ci < i
  then
    let p ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice (types.H256 ×
        (alloc.vec.Vec types.H256))) children_map ci
    let (h, _) := p
    let b ← types.H256.Insts.CoreCmpPartialEqH256.eq h parent_root
    if b
    then
      let (p1, index_mut_back) ←
        alloc.vec.Vec.index_mut (core.slice.index.SliceIndexUsizeSlice
          (types.H256 × (alloc.vec.Vec types.H256))) children_map ci
      let (h1, v) := p1
      let v1 ← alloc.vec.Vec.push v root
      let children_map1 := index_mut_back (h1, v1)
      ok (done (children_map1, true))
    else let ci1 ← ci + 1#usize
         ok (cont ci1)
  else ok (done (children_map, false))

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]: loop 3:
    Source: 'crates/verification/src/fork_choice.rs', lines 128:16-135:17
    Visibility: public -/
@[rust_loop]
def fork_choice.compute_lmd_ghost_head_loop2_loop0
  (children_map : alloc.vec.Vec (types.H256 × (alloc.vec.Vec types.H256)))
  (root : types.H256) (parent_root : types.H256) (ci : Std.Usize) :
  Result ((alloc.vec.Vec (types.H256 × (alloc.vec.Vec types.H256))) × Bool)
  := do
  loop
    (fun ci1 => fork_choice.compute_lmd_ghost_head_loop2_loop0.body
      children_map root parent_root ci1)
    ci

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]: loop body 4:
    Source: 'crates/verification/src/fork_choice.rs', lines 128:16-135:17
    Visibility: public -/
@[rust_loop_body]
def fork_choice.compute_lmd_ghost_head_loop2_loop1.body
  (children_map : alloc.vec.Vec (types.H256 × (alloc.vec.Vec types.H256)))
  (root : types.H256) (parent_root : types.H256) (ci : Std.Usize) :
  Result (ControlFlow Std.Usize ((alloc.vec.Vec (types.H256 × (alloc.vec.Vec
    types.H256))) × Bool))
  := do
  let i := alloc.vec.Vec.len children_map
  if ci < i
  then
    let p ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice (types.H256 ×
        (alloc.vec.Vec types.H256))) children_map ci
    let (h, _) := p
    let b ← types.H256.Insts.CoreCmpPartialEqH256.eq h parent_root
    if b
    then
      let (p1, index_mut_back) ←
        alloc.vec.Vec.index_mut (core.slice.index.SliceIndexUsizeSlice
          (types.H256 × (alloc.vec.Vec types.H256))) children_map ci
      let (h1, v) := p1
      let v1 ← alloc.vec.Vec.push v root
      let children_map1 := index_mut_back (h1, v1)
      ok (done (children_map1, true))
    else let ci1 ← ci + 1#usize
         ok (cont ci1)
  else ok (done (children_map, false))

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]: loop 4:
    Source: 'crates/verification/src/fork_choice.rs', lines 128:16-135:17
    Visibility: public -/
@[rust_loop]
def fork_choice.compute_lmd_ghost_head_loop2_loop1
  (children_map : alloc.vec.Vec (types.H256 × (alloc.vec.Vec types.H256)))
  (root : types.H256) (parent_root : types.H256) (ci : Std.Usize) :
  Result ((alloc.vec.Vec (types.H256 × (alloc.vec.Vec types.H256))) × Bool)
  := do
  loop
    (fun ci1 => fork_choice.compute_lmd_ghost_head_loop2_loop1.body
      children_map root parent_root ci1)
    ci

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]: loop body 2:
    Source: 'crates/verification/src/fork_choice.rs', lines 118:4-144:5
    Visibility: public -/
@[rust_loop_body]
def fork_choice.compute_lmd_ghost_head_loop2.body
  (blocks : alloc.vec.Vec (types.H256 × (Std.U64 × types.H256)))
  (min_score : Std.U64) (weights : alloc.vec.Vec (types.H256 × Std.U64))
  (children_map : alloc.vec.Vec (types.H256 × (alloc.vec.Vec types.H256)))
  (bi : Std.Usize) :
  Result (ControlFlow ((alloc.vec.Vec (types.H256 × (alloc.vec.Vec
    types.H256))) × Std.Usize) (alloc.vec.Vec (types.H256 × (alloc.vec.Vec
    types.H256))))
  := do
  let i := alloc.vec.Vec.len blocks
  if bi < i
  then
    let (root, p) ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice (types.H256 ×
        (Std.U64 × types.H256))) blocks bi
    let (_, parent_root) := p
    let b ← types.H256.is_zero parent_root
    if b
    then let bi1 ← bi + 1#usize
         ok (cont (children_map, bi1))
    else
      let w ← fork_choice.get_weight weights root
      if min_score = 0#u64
      then
        let (children_map1, found) ←
          fork_choice.compute_lmd_ghost_head_loop2_loop0 children_map root
            parent_root 0#usize
        let children_map2 ←
          if found
          then ok children_map1
          else
            do
            let children ←
              alloc.vec.Vec.push (alloc.vec.Vec.new types.H256) root
            alloc.vec.Vec.push children_map1 (parent_root, children)
        let bi1 ← bi + 1#usize
        ok (cont (children_map2, bi1))
      else
        if w >= min_score
        then
          let (children_map1, found) ←
            fork_choice.compute_lmd_ghost_head_loop2_loop1 children_map root
              parent_root 0#usize
          let children_map2 ←
            if found
            then ok children_map1
            else
              do
              let children ←
                alloc.vec.Vec.push (alloc.vec.Vec.new types.H256) root
              alloc.vec.Vec.push children_map1 (parent_root, children)
          let bi1 ← bi + 1#usize
          ok (cont (children_map2, bi1))
        else let bi1 ← bi + 1#usize
             ok (cont (children_map, bi1))
  else ok (done children_map)

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]: loop 2:
    Source: 'crates/verification/src/fork_choice.rs', lines 118:4-144:5
    Visibility: public -/
@[rust_loop]
def fork_choice.compute_lmd_ghost_head_loop2
  (blocks : alloc.vec.Vec (types.H256 × (Std.U64 × types.H256)))
  (min_score : Std.U64) (weights : alloc.vec.Vec (types.H256 × Std.U64))
  (children_map : alloc.vec.Vec (types.H256 × (alloc.vec.Vec types.H256)))
  (bi : Std.Usize) :
  Result (alloc.vec.Vec (types.H256 × (alloc.vec.Vec types.H256)))
  := do
  loop
    (fun (children_map1, bi1) => fork_choice.compute_lmd_ghost_head_loop2.body
      blocks min_score weights children_map1 bi1)
    (children_map, bi)

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]: loop body 7:
    Source: 'crates/verification/src/fork_choice.rs', lines 161:20-174:21
    Visibility: public -/
@[rust_loop_body]
def fork_choice.compute_lmd_ghost_head_loop3_loop0_loop0.body
  (weights : alloc.vec.Vec (types.H256 × Std.U64))
  (children : alloc.vec.Vec types.H256) (best : types.H256)
  (best_weight : Std.U64) (ki : Std.Usize) :
  Result (ControlFlow (types.H256 × Std.U64 × Std.Usize) types.H256)
  := do
  let i := alloc.vec.Vec.len children
  if ki < i
  then
    let h ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice types.H256)
        children ki
    let child_weight ← fork_choice.get_weight weights h
    let (best1, best_weight1) ←
      if child_weight > best_weight
      then ok (h, child_weight)
      else
        if child_weight = best_weight
        then
          do
          let o ← types.H256.Insts.CoreCmpOrd.cmp h best
          let b ←
            core.cmp.Ordering.Insts.CoreCmpPartialEqOrdering.eq o Ordering.gt
          if b
          then ok (h, child_weight)
          else ok (best, best_weight)
        else ok (best, best_weight)
    let ki1 ← ki + 1#usize
    ok (cont (best1, best_weight1, ki1))
  else ok (done best)

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]: loop 7:
    Source: 'crates/verification/src/fork_choice.rs', lines 161:20-174:21
    Visibility: public -/
@[rust_loop]
def fork_choice.compute_lmd_ghost_head_loop3_loop0_loop0
  (weights : alloc.vec.Vec (types.H256 × Std.U64))
  (children : alloc.vec.Vec types.H256) (best : types.H256)
  (best_weight : Std.U64) (ki : Std.Usize) :
  Result types.H256
  := do
  loop
    (fun (best1, best_weight1, ki1) =>
      fork_choice.compute_lmd_ghost_head_loop3_loop0_loop0.body weights
      children best1 best_weight1 ki1)
    (best, best_weight, ki)

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]: loop body 6:
    Source: 'crates/verification/src/fork_choice.rs', lines 153:8-181:9
    Visibility: public -/
@[rust_loop_body]
def fork_choice.compute_lmd_ghost_head_loop3_loop0.body
  (weights : alloc.vec.Vec (types.H256 × Std.U64))
  (children_map : alloc.vec.Vec (types.H256 × (alloc.vec.Vec types.H256)))
  (head : types.H256) (ci : Std.Usize) :
  Result (ControlFlow Std.Usize (types.H256 × Bool))
  := do
  let i := alloc.vec.Vec.len children_map
  if ci < i
  then
    let p ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice (types.H256 ×
        (alloc.vec.Vec types.H256))) children_map ci
    let (h, _) := p
    let b ← types.H256.Insts.CoreCmpPartialEqH256.eq h head
    if b
    then
      let (_, children) := p
      let b1 ← alloc.vec.Vec.is_empty Global children
      if b1
      then ok (done (head, false))
      else
        let best ←
          alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice
            types.H256) children 0#usize
        let best_weight ← fork_choice.get_weight weights best
        let best1 ←
          fork_choice.compute_lmd_ghost_head_loop3_loop0_loop0 weights children
            best best_weight 1#usize
        ok (done (best1, true))
    else let ci1 ← ci + 1#usize
         ok (cont ci1)
  else ok (done (head, false))

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]: loop 6:
    Source: 'crates/verification/src/fork_choice.rs', lines 153:8-181:9
    Visibility: public -/
@[rust_loop]
def fork_choice.compute_lmd_ghost_head_loop3_loop0
  (weights : alloc.vec.Vec (types.H256 × Std.U64))
  (children_map : alloc.vec.Vec (types.H256 × (alloc.vec.Vec types.H256)))
  (head : types.H256) (ci : Std.Usize) :
  Result (types.H256 × Bool)
  := do
  loop
    (fun ci1 => fork_choice.compute_lmd_ghost_head_loop3_loop0.body weights
      children_map head ci1)
    ci

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]: loop body 5:
    Source: 'crates/verification/src/fork_choice.rs', lines 149:4-182:5
    Visibility: public -/
@[rust_loop_body]
def fork_choice.compute_lmd_ghost_head_loop3.body
  (weights : alloc.vec.Vec (types.H256 × Std.U64))
  (children_map : alloc.vec.Vec (types.H256 × (alloc.vec.Vec types.H256)))
  (head : types.H256) (keep_going : Bool) :
  Result (ControlFlow (types.H256 × Bool) types.H256)
  := do
  if keep_going
  then
    let (head1, keep_going1) ←
      fork_choice.compute_lmd_ghost_head_loop3_loop0 weights children_map head
        0#usize
    ok (cont (head1, keep_going1))
  else ok (done head)

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]: loop 5:
    Source: 'crates/verification/src/fork_choice.rs', lines 149:4-182:5
    Visibility: public -/
@[rust_loop]
def fork_choice.compute_lmd_ghost_head_loop3
  (weights : alloc.vec.Vec (types.H256 × Std.U64))
  (children_map : alloc.vec.Vec (types.H256 × (alloc.vec.Vec types.H256)))
  (head : types.H256) (keep_going : Bool) :
  Result types.H256
  := do
  loop
    (fun (head1, keep_going1) => fork_choice.compute_lmd_ghost_head_loop3.body
      weights children_map head1 keep_going1)
    (head, keep_going)

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]: loop body 8:
    Source: 'crates/verification/src/fork_choice.rs', lines 101:4-108:5
    Visibility: public -/
@[rust_loop_body]
def fork_choice.compute_lmd_ghost_head_loop4.body
  (start_root : types.H256)
  (blocks : alloc.vec.Vec (types.H256 × (Std.U64 × types.H256)))
  (si : Std.Usize) :
  Result (ControlFlow Std.Usize (Std.U64 × Bool))
  := do
  let i := alloc.vec.Vec.len blocks
  if si < i
  then
    let p ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice (types.H256 ×
        (Std.U64 × types.H256))) blocks si
    let (h, _) := p
    let b ← types.H256.Insts.CoreCmpPartialEqH256.eq h start_root
    if b
    then
      let (_, p1) := p
      let (start_slot, _) := p1
      ok (done (start_slot, true))
    else let si1 ← si + 1#usize
         ok (cont si1)
  else ok (done (0#u64, false))

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]: loop 8:
    Source: 'crates/verification/src/fork_choice.rs', lines 101:4-108:5
    Visibility: public -/
@[rust_loop]
def fork_choice.compute_lmd_ghost_head_loop4
  (start_root : types.H256)
  (blocks : alloc.vec.Vec (types.H256 × (Std.U64 × types.H256)))
  (si : Std.Usize) :
  Result (Std.U64 × Bool)
  := do
  loop
    (fun si1 => fork_choice.compute_lmd_ghost_head_loop4.body start_root blocks
      si1)
    si

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]: loop body 10:
    Source: 'crates/verification/src/fork_choice.rs', lines 128:16-135:17
    Visibility: public -/
@[rust_loop_body]
def fork_choice.compute_lmd_ghost_head_loop5_loop0.body
  (children_map : alloc.vec.Vec (types.H256 × (alloc.vec.Vec types.H256)))
  (root : types.H256) (parent_root : types.H256) (ci : Std.Usize) :
  Result (ControlFlow Std.Usize ((alloc.vec.Vec (types.H256 × (alloc.vec.Vec
    types.H256))) × Bool))
  := do
  let i := alloc.vec.Vec.len children_map
  if ci < i
  then
    let p ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice (types.H256 ×
        (alloc.vec.Vec types.H256))) children_map ci
    let (h, _) := p
    let b ← types.H256.Insts.CoreCmpPartialEqH256.eq h parent_root
    if b
    then
      let (p1, index_mut_back) ←
        alloc.vec.Vec.index_mut (core.slice.index.SliceIndexUsizeSlice
          (types.H256 × (alloc.vec.Vec types.H256))) children_map ci
      let (h1, v) := p1
      let v1 ← alloc.vec.Vec.push v root
      let children_map1 := index_mut_back (h1, v1)
      ok (done (children_map1, true))
    else let ci1 ← ci + 1#usize
         ok (cont ci1)
  else ok (done (children_map, false))

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]: loop 10:
    Source: 'crates/verification/src/fork_choice.rs', lines 128:16-135:17
    Visibility: public -/
@[rust_loop]
def fork_choice.compute_lmd_ghost_head_loop5_loop0
  (children_map : alloc.vec.Vec (types.H256 × (alloc.vec.Vec types.H256)))
  (root : types.H256) (parent_root : types.H256) (ci : Std.Usize) :
  Result ((alloc.vec.Vec (types.H256 × (alloc.vec.Vec types.H256))) × Bool)
  := do
  loop
    (fun ci1 => fork_choice.compute_lmd_ghost_head_loop5_loop0.body
      children_map root parent_root ci1)
    ci

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]: loop body 11:
    Source: 'crates/verification/src/fork_choice.rs', lines 128:16-135:17
    Visibility: public -/
@[rust_loop_body]
def fork_choice.compute_lmd_ghost_head_loop5_loop1.body
  (children_map : alloc.vec.Vec (types.H256 × (alloc.vec.Vec types.H256)))
  (root : types.H256) (parent_root : types.H256) (ci : Std.Usize) :
  Result (ControlFlow Std.Usize ((alloc.vec.Vec (types.H256 × (alloc.vec.Vec
    types.H256))) × Bool))
  := do
  let i := alloc.vec.Vec.len children_map
  if ci < i
  then
    let p ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice (types.H256 ×
        (alloc.vec.Vec types.H256))) children_map ci
    let (h, _) := p
    let b ← types.H256.Insts.CoreCmpPartialEqH256.eq h parent_root
    if b
    then
      let (p1, index_mut_back) ←
        alloc.vec.Vec.index_mut (core.slice.index.SliceIndexUsizeSlice
          (types.H256 × (alloc.vec.Vec types.H256))) children_map ci
      let (h1, v) := p1
      let v1 ← alloc.vec.Vec.push v root
      let children_map1 := index_mut_back (h1, v1)
      ok (done (children_map1, true))
    else let ci1 ← ci + 1#usize
         ok (cont ci1)
  else ok (done (children_map, false))

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]: loop 11:
    Source: 'crates/verification/src/fork_choice.rs', lines 128:16-135:17
    Visibility: public -/
@[rust_loop]
def fork_choice.compute_lmd_ghost_head_loop5_loop1
  (children_map : alloc.vec.Vec (types.H256 × (alloc.vec.Vec types.H256)))
  (root : types.H256) (parent_root : types.H256) (ci : Std.Usize) :
  Result ((alloc.vec.Vec (types.H256 × (alloc.vec.Vec types.H256))) × Bool)
  := do
  loop
    (fun ci1 => fork_choice.compute_lmd_ghost_head_loop5_loop1.body
      children_map root parent_root ci1)
    ci

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]: loop body 9:
    Source: 'crates/verification/src/fork_choice.rs', lines 118:4-144:5
    Visibility: public -/
@[rust_loop_body]
def fork_choice.compute_lmd_ghost_head_loop5.body
  (blocks : alloc.vec.Vec (types.H256 × (Std.U64 × types.H256)))
  (min_score : Std.U64) (weights : alloc.vec.Vec (types.H256 × Std.U64))
  (children_map : alloc.vec.Vec (types.H256 × (alloc.vec.Vec types.H256)))
  (bi : Std.Usize) :
  Result (ControlFlow ((alloc.vec.Vec (types.H256 × (alloc.vec.Vec
    types.H256))) × Std.Usize) (alloc.vec.Vec (types.H256 × (alloc.vec.Vec
    types.H256))))
  := do
  let i := alloc.vec.Vec.len blocks
  if bi < i
  then
    let (root, p) ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice (types.H256 ×
        (Std.U64 × types.H256))) blocks bi
    let (_, parent_root) := p
    let b ← types.H256.is_zero parent_root
    if b
    then let bi1 ← bi + 1#usize
         ok (cont (children_map, bi1))
    else
      let w ← fork_choice.get_weight weights root
      if min_score = 0#u64
      then
        let (children_map1, found) ←
          fork_choice.compute_lmd_ghost_head_loop5_loop0 children_map root
            parent_root 0#usize
        let children_map2 ←
          if found
          then ok children_map1
          else
            do
            let children ←
              alloc.vec.Vec.push (alloc.vec.Vec.new types.H256) root
            alloc.vec.Vec.push children_map1 (parent_root, children)
        let bi1 ← bi + 1#usize
        ok (cont (children_map2, bi1))
      else
        if w >= min_score
        then
          let (children_map1, found) ←
            fork_choice.compute_lmd_ghost_head_loop5_loop1 children_map root
              parent_root 0#usize
          let children_map2 ←
            if found
            then ok children_map1
            else
              do
              let children ←
                alloc.vec.Vec.push (alloc.vec.Vec.new types.H256) root
              alloc.vec.Vec.push children_map1 (parent_root, children)
          let bi1 ← bi + 1#usize
          ok (cont (children_map2, bi1))
        else let bi1 ← bi + 1#usize
             ok (cont (children_map, bi1))
  else ok (done children_map)

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]: loop 9:
    Source: 'crates/verification/src/fork_choice.rs', lines 118:4-144:5
    Visibility: public -/
@[rust_loop]
def fork_choice.compute_lmd_ghost_head_loop5
  (blocks : alloc.vec.Vec (types.H256 × (Std.U64 × types.H256)))
  (min_score : Std.U64) (weights : alloc.vec.Vec (types.H256 × Std.U64))
  (children_map : alloc.vec.Vec (types.H256 × (alloc.vec.Vec types.H256)))
  (bi : Std.Usize) :
  Result (alloc.vec.Vec (types.H256 × (alloc.vec.Vec types.H256)))
  := do
  loop
    (fun (children_map1, bi1) => fork_choice.compute_lmd_ghost_head_loop5.body
      blocks min_score weights children_map1 bi1)
    (children_map, bi)

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]: loop body 14:
    Source: 'crates/verification/src/fork_choice.rs', lines 161:20-174:21
    Visibility: public -/
@[rust_loop_body]
def fork_choice.compute_lmd_ghost_head_loop6_loop0_loop0.body
  (weights : alloc.vec.Vec (types.H256 × Std.U64))
  (children : alloc.vec.Vec types.H256) (best : types.H256)
  (best_weight : Std.U64) (ki : Std.Usize) :
  Result (ControlFlow (types.H256 × Std.U64 × Std.Usize) types.H256)
  := do
  let i := alloc.vec.Vec.len children
  if ki < i
  then
    let h ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice types.H256)
        children ki
    let child_weight ← fork_choice.get_weight weights h
    let (best1, best_weight1) ←
      if child_weight > best_weight
      then ok (h, child_weight)
      else
        if child_weight = best_weight
        then
          do
          let o ← types.H256.Insts.CoreCmpOrd.cmp h best
          let b ←
            core.cmp.Ordering.Insts.CoreCmpPartialEqOrdering.eq o Ordering.gt
          if b
          then ok (h, child_weight)
          else ok (best, best_weight)
        else ok (best, best_weight)
    let ki1 ← ki + 1#usize
    ok (cont (best1, best_weight1, ki1))
  else ok (done best)

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]: loop 14:
    Source: 'crates/verification/src/fork_choice.rs', lines 161:20-174:21
    Visibility: public -/
@[rust_loop]
def fork_choice.compute_lmd_ghost_head_loop6_loop0_loop0
  (weights : alloc.vec.Vec (types.H256 × Std.U64))
  (children : alloc.vec.Vec types.H256) (best : types.H256)
  (best_weight : Std.U64) (ki : Std.Usize) :
  Result types.H256
  := do
  loop
    (fun (best1, best_weight1, ki1) =>
      fork_choice.compute_lmd_ghost_head_loop6_loop0_loop0.body weights
      children best1 best_weight1 ki1)
    (best, best_weight, ki)

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]: loop body 13:
    Source: 'crates/verification/src/fork_choice.rs', lines 153:8-181:9
    Visibility: public -/
@[rust_loop_body]
def fork_choice.compute_lmd_ghost_head_loop6_loop0.body
  (weights : alloc.vec.Vec (types.H256 × Std.U64))
  (children_map : alloc.vec.Vec (types.H256 × (alloc.vec.Vec types.H256)))
  (head : types.H256) (ci : Std.Usize) :
  Result (ControlFlow Std.Usize (types.H256 × Bool))
  := do
  let i := alloc.vec.Vec.len children_map
  if ci < i
  then
    let p ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice (types.H256 ×
        (alloc.vec.Vec types.H256))) children_map ci
    let (h, _) := p
    let b ← types.H256.Insts.CoreCmpPartialEqH256.eq h head
    if b
    then
      let (_, children) := p
      let b1 ← alloc.vec.Vec.is_empty Global children
      if b1
      then ok (done (head, false))
      else
        let best ←
          alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice
            types.H256) children 0#usize
        let best_weight ← fork_choice.get_weight weights best
        let best1 ←
          fork_choice.compute_lmd_ghost_head_loop6_loop0_loop0 weights children
            best best_weight 1#usize
        ok (done (best1, true))
    else let ci1 ← ci + 1#usize
         ok (cont ci1)
  else ok (done (head, false))

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]: loop 13:
    Source: 'crates/verification/src/fork_choice.rs', lines 153:8-181:9
    Visibility: public -/
@[rust_loop]
def fork_choice.compute_lmd_ghost_head_loop6_loop0
  (weights : alloc.vec.Vec (types.H256 × Std.U64))
  (children_map : alloc.vec.Vec (types.H256 × (alloc.vec.Vec types.H256)))
  (head : types.H256) (ci : Std.Usize) :
  Result (types.H256 × Bool)
  := do
  loop
    (fun ci1 => fork_choice.compute_lmd_ghost_head_loop6_loop0.body weights
      children_map head ci1)
    ci

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]: loop body 12:
    Source: 'crates/verification/src/fork_choice.rs', lines 149:4-182:5
    Visibility: public -/
@[rust_loop_body]
def fork_choice.compute_lmd_ghost_head_loop6.body
  (weights : alloc.vec.Vec (types.H256 × Std.U64))
  (children_map : alloc.vec.Vec (types.H256 × (alloc.vec.Vec types.H256)))
  (head : types.H256) (keep_going : Bool) :
  Result (ControlFlow (types.H256 × Bool) types.H256)
  := do
  if keep_going
  then
    let (head1, keep_going1) ←
      fork_choice.compute_lmd_ghost_head_loop6_loop0 weights children_map head
        0#usize
    ok (cont (head1, keep_going1))
  else ok (done head)

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]: loop 12:
    Source: 'crates/verification/src/fork_choice.rs', lines 149:4-182:5
    Visibility: public -/
@[rust_loop]
def fork_choice.compute_lmd_ghost_head_loop6
  (weights : alloc.vec.Vec (types.H256 × Std.U64))
  (children_map : alloc.vec.Vec (types.H256 × (alloc.vec.Vec types.H256)))
  (head : types.H256) (keep_going : Bool) :
  Result types.H256
  := do
  loop
    (fun (head1, keep_going1) => fork_choice.compute_lmd_ghost_head_loop6.body
      weights children_map head1 keep_going1)
    (head, keep_going)

/-- [ethlambda_verification::fork_choice::compute_lmd_ghost_head]:
    Source: 'crates/verification/src/fork_choice.rs', lines 70:0-185:1
    Visibility: public -/
def fork_choice.compute_lmd_ghost_head
  (start_root : types.H256)
  (blocks : alloc.vec.Vec (types.H256 × (Std.U64 × types.H256)))
  (attestations : alloc.vec.Vec (Std.U64 × types.AttestationData))
  (min_score : Std.U64) :
  Result (types.H256 × (alloc.vec.Vec (types.H256 × Std.U64)))
  := do
  let b ← alloc.vec.Vec.is_empty Global blocks
  if b
  then ok (start_root, alloc.vec.Vec.new (types.H256 × Std.U64))
  else
    let b1 ← types.H256.is_zero start_root
    if b1
    then
      let min_root ←
        fork_choice.compute_lmd_ghost_head_loop0 blocks core.num.U64.MAX none
          0#usize
      match min_root with
      | none => ok (start_root, alloc.vec.Vec.new (types.H256 × Std.U64))
      | some r =>
        let (start_slot, start_found) ←
          fork_choice.compute_lmd_ghost_head_loop1 r blocks 0#usize
        if start_found
        then
          let weights ←
            fork_choice.compute_block_weights start_slot blocks attestations
          let children_map ←
            fork_choice.compute_lmd_ghost_head_loop2 blocks min_score weights
              (alloc.vec.Vec.new (types.H256 × (alloc.vec.Vec types.H256)))
              0#usize
          let head ←
            fork_choice.compute_lmd_ghost_head_loop3 weights children_map r
              true
          ok (head, weights)
        else ok (r, alloc.vec.Vec.new (types.H256 × Std.U64))
    else
      let (start_slot, start_found) ←
        fork_choice.compute_lmd_ghost_head_loop4 start_root blocks 0#usize
      if start_found
      then
        let weights ←
          fork_choice.compute_block_weights start_slot blocks attestations
        let children_map ←
          fork_choice.compute_lmd_ghost_head_loop5 blocks min_score weights
            (alloc.vec.Vec.new (types.H256 × (alloc.vec.Vec types.H256)))
            0#usize
        let head ←
          fork_choice.compute_lmd_ghost_head_loop6 weights children_map
            start_root true
        ok (head, weights)
      else ok (start_root, alloc.vec.Vec.new (types.H256 × Std.U64))

end ethlambda_verification
