-- Manually split from the Aeneas-generated `ConsensusLean4/Funs.lean`.
-- Contains the `justified_slots.*` namespace; see `ConsensusLean4/Funs.lean` for
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

/-- [ethlambda_verification::justified_slots::relative_index]:
    Source: 'crates/verification/src/justified_slots.rs', lines 3:0-12:1 -/
def justified_slots.relative_index
  (target_slot : Std.U64) (finalized_slot : Std.U64) :
  Result (Option Std.Usize)
  := do
  if target_slot <= finalized_slot
  then ok none
  else
    let diff ← target_slot - finalized_slot
    if diff = 0#u64
    then ok none
    else
      let i ← diff - 1#u64
      let i1 ← lift (UScalar.cast .Usize i)
      ok (some i1)

/-- [ethlambda_verification::justified_slots::is_slot_justified]:
    Source: 'crates/verification/src/justified_slots.rs', lines 15:0-26:1
    Visibility: public -/
def justified_slots.is_slot_justified
  (slots : alloc.vec.Vec Bool) (finalized_slot : Std.U64)
  (target_slot : Std.U64) :
  Result Bool
  := do
  let o ← justified_slots.relative_index target_slot finalized_slot
  match o with
  | none => ok true
  | some idx =>
    let i := alloc.vec.Vec.len slots
    if idx < i
    then
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice Bool) slots
        idx
    else ok false

/-- [ethlambda_verification::justified_slots::set_justified]:
    Source: 'crates/verification/src/justified_slots.rs', lines 29:0-38:1
    Visibility: public -/
def justified_slots.set_justified
  (slots : alloc.vec.Vec Bool) (finalized_slot : Std.U64)
  (target_slot : Std.U64) :
  Result (alloc.vec.Vec Bool)
  := do
  let o ← justified_slots.relative_index target_slot finalized_slot
  match o with
  | none => ok slots
  | some idx =>
    let i := alloc.vec.Vec.len slots
    if idx < i
    then
      let (_, index_mut_back) ←
        alloc.vec.Vec.index_mut (core.slice.index.SliceIndexUsizeSlice Bool)
          slots idx
      ok (index_mut_back true)
    else ok slots

/-- [ethlambda_verification::justified_slots::extend_to_slot]: loop body 0:
    Source: 'crates/verification/src/justified_slots.rs', lines 52:12-59:13
    Visibility: public -/
@[rust_loop_body]
def justified_slots.extend_to_slot_loop.body
  (slots : alloc.vec.Vec Bool) (required_capacity : Std.Usize)
  (extended : alloc.vec.Vec Bool) (i : Std.Usize) :
  Result (ControlFlow ((alloc.vec.Vec Bool) × Std.Usize) (alloc.vec.Vec Bool))
  := do
  if i < required_capacity
  then
    let i1 := alloc.vec.Vec.len slots
    let extended1 ←
      if i < i1
      then
        do
        let b ←
          alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice Bool)
            slots i
        alloc.vec.Vec.push extended b
      else alloc.vec.Vec.push extended false
    let i2 ← i + 1#usize
    ok (cont (extended1, i2))
  else ok (done extended)

/-- [ethlambda_verification::justified_slots::extend_to_slot]: loop 0:
    Source: 'crates/verification/src/justified_slots.rs', lines 52:12-59:13
    Visibility: public -/
@[rust_loop]
def justified_slots.extend_to_slot_loop
  (slots : alloc.vec.Vec Bool) (required_capacity : Std.Usize)
  (extended : alloc.vec.Vec Bool) (i : Std.Usize) :
  Result (alloc.vec.Vec Bool)
  := do
  loop
    (fun (extended1, i1) => justified_slots.extend_to_slot_loop.body slots
      required_capacity extended1 i1)
    (extended, i)

/-- [ethlambda_verification::justified_slots::extend_to_slot]:
    Source: 'crates/verification/src/justified_slots.rs', lines 42:0-63:1
    Visibility: public -/
def justified_slots.extend_to_slot
  (slots : alloc.vec.Vec Bool) (finalized_slot : Std.U64)
  (target_slot : Std.U64) :
  Result (alloc.vec.Vec Bool)
  := do
  let o ← justified_slots.relative_index target_slot finalized_slot
  match o with
  | none => ok slots
  | some required_idx =>
    let required_capacity ← required_idx + 1#usize
    let i := alloc.vec.Vec.len slots
    if i >= required_capacity
    then ok slots
    else
      justified_slots.extend_to_slot_loop slots required_capacity
        (alloc.vec.Vec.new Bool) 0#usize

/-- [ethlambda_verification::justified_slots::shift_window]: loop body 0:
    Source: 'crates/verification/src/justified_slots.rs', lines 77:4-80:5
    Visibility: public -/
@[rust_loop_body]
def justified_slots.shift_window_loop.body
  (slots : alloc.vec.Vec Bool) (delta : Std.Usize) (remaining : Std.Usize)
  (new_bits : alloc.vec.Vec Bool) (i : Std.Usize) :
  Result (ControlFlow ((alloc.vec.Vec Bool) × Std.Usize) (alloc.vec.Vec Bool))
  := do
  if i < remaining
  then
    let i1 ← i + delta
    let b ←
      alloc.vec.Vec.index (core.slice.index.SliceIndexUsizeSlice Bool) slots i1
    let new_bits1 ← alloc.vec.Vec.push new_bits b
    let i2 ← i + 1#usize
    ok (cont (new_bits1, i2))
  else ok (done new_bits)

/-- [ethlambda_verification::justified_slots::shift_window]: loop 0:
    Source: 'crates/verification/src/justified_slots.rs', lines 77:4-80:5
    Visibility: public -/
@[rust_loop]
def justified_slots.shift_window_loop
  (slots : alloc.vec.Vec Bool) (delta : Std.Usize) (remaining : Std.Usize)
  (new_bits : alloc.vec.Vec Bool) (i : Std.Usize) :
  Result (alloc.vec.Vec Bool)
  := do
  loop
    (fun (new_bits1, i1) => justified_slots.shift_window_loop.body slots delta
      remaining new_bits1 i1)
    (new_bits, i)

/-- [ethlambda_verification::justified_slots::shift_window]:
    Source: 'crates/verification/src/justified_slots.rs', lines 66:0-82:1
    Visibility: public -/
def justified_slots.shift_window
  (slots : alloc.vec.Vec Bool) (delta : Std.Usize) :
  Result (alloc.vec.Vec Bool)
  := do
  if delta = 0#usize
  then ok slots
  else
    let i := alloc.vec.Vec.len slots
    if delta >= i
    then alloc.vec.Vec.clear Global slots
    else
      let i1 := alloc.vec.Vec.len slots
      let remaining ← i1 - delta
      justified_slots.shift_window_loop slots delta remaining
        (alloc.vec.Vec.new Bool) 0#usize

end ethlambda_verification
