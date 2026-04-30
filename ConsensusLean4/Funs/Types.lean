-- Manually split from the Aeneas-generated `ConsensusLean4/Funs.lean`.
-- Contains the `types.*` namespace; see `ConsensusLean4/Funs.lean` for
-- the umbrella import.
import Aeneas
import ConsensusLean4.Types
import ConsensusLean4.FunsExternal
open Aeneas Aeneas.Std Result ControlFlow Error
set_option linter.dupNamespace false
set_option linter.hashCommand false
set_option linter.unusedVariables false

set_option maxHeartbeats 1000000

noncomputable section

namespace ethlambda_verification

/-- [ethlambda_verification::types::{core::cmp::PartialEq<ethlambda_verification::types::H256> for ethlambda_verification::types::H256}::eq]: loop body 0:
    Source: 'crates/verification/src/types.rs', lines 23:8-30:5
    Visibility: public -/
@[rust_loop_body]
def types.H256.Insts.CoreCmpPartialEqH256.eq_loop.body
  (self : types.H256) (other : types.H256) (i : Std.Usize) :
  Result (ControlFlow (types.H256 × types.H256 × Std.Usize) Bool)
  := do
  if i < 32#usize
  then
    let i1 ← Array.index_usize self i
    let i2 ← Array.index_usize other i
    if i1 != i2
    then ok (done false)
    else let i3 ← i + 1#usize
         ok (cont (self, other, i3))
  else ok (done true)

/-- [ethlambda_verification::types::{core::cmp::PartialEq<ethlambda_verification::types::H256> for ethlambda_verification::types::H256}::eq]: loop 0:
    Source: 'crates/verification/src/types.rs', lines 23:8-30:5
    Visibility: public -/
@[rust_loop]
def types.H256.Insts.CoreCmpPartialEqH256.eq_loop
  (self : types.H256) (other : types.H256) (i : Std.Usize) : Result Bool := do
  loop
    (fun (self1, other1, i1) =>
      types.H256.Insts.CoreCmpPartialEqH256.eq_loop.body self1 other1 i1)
    (self, other, i)

/-- [ethlambda_verification::types::{core::cmp::PartialEq<ethlambda_verification::types::H256> for ethlambda_verification::types::H256}::eq]:
    Source: 'crates/verification/src/types.rs', lines 21:4-30:5
    Visibility: public -/
@[reducible]
def types.H256.Insts.CoreCmpPartialEqH256.eq
  (self : types.H256) (other : types.H256) : Result Bool := do
  types.H256.Insts.CoreCmpPartialEqH256.eq_loop self other 0#usize

/-- [ethlambda_verification::types::{core::cmp::Ord for ethlambda_verification::types::H256}::cmp]: loop body 0:
    Source: 'crates/verification/src/types.rs', lines 44:8-54:5
    Visibility: public -/
@[rust_loop_body]
def types.H256.Insts.CoreCmpOrd.cmp_loop.body
  (self : types.H256) (other : types.H256) (i : Std.Usize) :
  Result (ControlFlow (types.H256 × types.H256 × Std.Usize) Ordering)
  := do
  if i < 32#usize
  then
    let i1 ← Array.index_usize self i
    let i2 ← Array.index_usize other i
    if i1 < i2
    then ok (done Ordering.lt)
    else
      if i1 > i2
      then ok (done Ordering.gt)
      else let i3 ← i + 1#usize
           ok (cont (self, other, i3))
  else ok (done Ordering.eq)

/-- [ethlambda_verification::types::{core::cmp::Ord for ethlambda_verification::types::H256}::cmp]: loop 0:
    Source: 'crates/verification/src/types.rs', lines 44:8-54:5
    Visibility: public -/
@[rust_loop]
def types.H256.Insts.CoreCmpOrd.cmp_loop
  (self : types.H256) (other : types.H256) (i : Std.Usize) :
  Result Ordering
  := do
  loop
    (fun (self1, other1, i1) => types.H256.Insts.CoreCmpOrd.cmp_loop.body self1
      other1 i1)
    (self, other, i)

/-- [ethlambda_verification::types::{core::cmp::Ord for ethlambda_verification::types::H256}::cmp]:
    Source: 'crates/verification/src/types.rs', lines 42:4-54:5
    Visibility: public -/
@[reducible]
def types.H256.Insts.CoreCmpOrd.cmp
  (self : types.H256) (other : types.H256) : Result Ordering := do
  types.H256.Insts.CoreCmpOrd.cmp_loop self other 0#usize

/-- [ethlambda_verification::types::{ethlambda_verification::types::H256}::is_zero]: loop body 0:
    Source: 'crates/verification/src/types.rs', lines 10:8-17:5
    Visibility: public -/
@[rust_loop_body]
def types.H256.is_zero_loop.body
  (self : types.H256) (i : Std.Usize) :
  Result (ControlFlow (types.H256 × Std.Usize) Bool)
  := do
  if i < 32#usize
  then
    let i1 ← Array.index_usize self i
    if i1 != 0#u8
    then ok (done false)
    else let i2 ← i + 1#usize
         ok (cont (self, i2))
  else ok (done true)

/-- [ethlambda_verification::types::{ethlambda_verification::types::H256}::is_zero]: loop 0:
    Source: 'crates/verification/src/types.rs', lines 10:8-17:5
    Visibility: public -/
@[rust_loop]
def types.H256.is_zero_loop
  (self : types.H256) (i : Std.Usize) : Result Bool := do
  loop
    (fun (self1, i1) => types.H256.is_zero_loop.body self1 i1)
    (self, i)

/-- [ethlambda_verification::types::{ethlambda_verification::types::H256}::is_zero]:
    Source: 'crates/verification/src/types.rs', lines 8:4-17:5
    Visibility: public -/
@[reducible]
def types.H256.is_zero (self : types.H256) : Result Bool := do
  types.H256.is_zero_loop self 0#usize

/-- [ethlambda_verification::types::{ethlambda_verification::types::H256}::ZERO]
    Source: 'crates/verification/src/types.rs', lines 6:4-6:43
    Visibility: public -/
@[global_simps, irreducible]
def types.H256.ZERO : types.H256 := let a := Array.repeat 32#usize 0#u8
                                    a

/-- [ethlambda_verification::types::hash_tree_root_state]:
    Source: 'crates/verification/src/types.rs', lines 153:0-155:1
    Visibility: public -/
def types.hash_tree_root_state (_state : types.State) : Result types.H256 := do
  ok types.H256.ZERO

/-- [ethlambda_verification::types::hash_tree_root_block_body]:
    Source: 'crates/verification/src/types.rs', lines 161:0-163:1
    Visibility: public -/
def types.hash_tree_root_block_body
  (_body : types.BlockBody) : Result types.H256 := do
  ok types.H256.ZERO

/-- [ethlambda_verification::types::hash_tree_root_block_header]:
    Source: 'crates/verification/src/types.rs', lines 157:0-159:1
    Visibility: public -/
def types.hash_tree_root_block_header
  (_header : types.BlockHeader) : Result types.H256 := do
  ok types.H256.ZERO

/-- [ethlambda_verification::types::HISTORICAL_ROOTS_LIMIT]
    Source: 'crates/verification/src/types.rs', lines 129:0-129:50
    Visibility: public -/
@[global_simps, irreducible]
def types.HISTORICAL_ROOTS_LIMIT : Std.Usize := 262144#usize

/-- [ethlambda_verification::types::{core::clone::Clone for ethlambda_verification::types::H256}::clone]:
    Source: 'crates/verification/src/types.rs', lines 2:9-2:14
    Visibility: public -/
def types.H256.Insts.CoreCloneClone.clone
  (self : types.H256) : Result types.H256 := do
  ok self

/-- Trait implementation: [ethlambda_verification::types::{core::clone::Clone for ethlambda_verification::types::H256}]
    Source: 'crates/verification/src/types.rs', lines 2:9-2:14 -/
@[reducible]
def types.H256.Insts.CoreCloneClone : core.clone.Clone types.H256 := {
  clone := types.H256.Insts.CoreCloneClone.clone
}

/-- Trait implementation: [ethlambda_verification::types::{core::marker::Copy for ethlambda_verification::types::H256}]
    Source: 'crates/verification/src/types.rs', lines 2:16-2:20 -/
@[reducible]
def types.H256.Insts.CoreMarkerCopy : core.marker.Copy types.H256 := {
  cloneInst := types.H256.Insts.CoreCloneClone
}

/-- Trait implementation: [ethlambda_verification::types::{core::cmp::PartialEq<ethlambda_verification::types::H256> for ethlambda_verification::types::H256}]
    Source: 'crates/verification/src/types.rs', lines 20:0-31:1 -/
@[reducible]
def types.H256.Insts.CoreCmpPartialEqH256 : core.cmp.PartialEq types.H256
  types.H256 := {
  eq := types.H256.Insts.CoreCmpPartialEqH256.eq
}

/-- Trait implementation: [ethlambda_verification::types::{core::cmp::Eq for ethlambda_verification::types::H256}]
    Source: 'crates/verification/src/types.rs', lines 33:0-33:19 -/
@[reducible]
def types.H256.Insts.CoreCmpEq : core.cmp.Eq types.H256 := {
  partialEqInst := types.H256.Insts.CoreCmpPartialEqH256
}

/-- [ethlambda_verification::types::{core::cmp::PartialOrd<ethlambda_verification::types::H256> for ethlambda_verification::types::H256}::partial_cmp]:
    Source: 'crates/verification/src/types.rs', lines 36:4-38:5
    Visibility: public -/
def types.H256.Insts.CoreCmpPartialOrdH256.partial_cmp
  (self : types.H256) (other : types.H256) : Result (Option Ordering) := do
  let o ← types.H256.Insts.CoreCmpOrd.cmp self other
  ok (some o)

/-- Trait implementation: [ethlambda_verification::types::{core::cmp::PartialOrd<ethlambda_verification::types::H256> for ethlambda_verification::types::H256}]
    Source: 'crates/verification/src/types.rs', lines 35:0-39:1 -/
@[reducible]
def types.H256.Insts.CoreCmpPartialOrdH256 : core.cmp.PartialOrd types.H256
  types.H256 := {
  partialEqInst := types.H256.Insts.CoreCmpPartialEqH256
  partial_cmp := types.H256.Insts.CoreCmpPartialOrdH256.partial_cmp
  lt := core.cmp.PartialOrd.lt.default types.H256.Insts.CoreCmpPartialOrdH256.partial_cmp
  le := core.cmp.PartialOrd.le.default types.H256.Insts.CoreCmpPartialOrdH256.partial_cmp
  gt := core.cmp.PartialOrd.gt.default types.H256.Insts.CoreCmpPartialOrdH256.partial_cmp
  ge := core.cmp.PartialOrd.ge.default types.H256.Insts.CoreCmpPartialOrdH256.partial_cmp
}

/-- Trait implementation: [ethlambda_verification::types::{core::cmp::Ord for ethlambda_verification::types::H256}]
    Source: 'crates/verification/src/types.rs', lines 41:0-55:1 -/
@[reducible]
def types.H256.Insts.CoreCmpOrd : core.cmp.Ord types.H256 := {
  eqInst := types.H256.Insts.CoreCmpEq
  partialOrdInst := types.H256.Insts.CoreCmpPartialOrdH256
  cmp := types.H256.Insts.CoreCmpOrd.cmp
  max := core.cmp.Ord.max.default types.H256.Insts.CoreCmpPartialOrdH256.lt
  min := core.cmp.Ord.min.default types.H256.Insts.CoreCmpPartialOrdH256.lt
  clamp := core.cmp.Ord.clamp.default types.H256.Insts.CoreCmpPartialOrdH256.le types.H256.Insts.CoreCmpPartialOrdH256.lt types.H256.Insts.CoreCmpPartialOrdH256.gt
}

/-- [ethlambda_verification::types::{core::clone::Clone for ethlambda_verification::types::Checkpoint}::clone]:
    Source: 'crates/verification/src/types.rs', lines 58:9-58:14
    Visibility: public -/
def types.Checkpoint.Insts.CoreCloneClone.clone
  (self : types.Checkpoint) : Result types.Checkpoint := do
  ok self

/-- Trait implementation: [ethlambda_verification::types::{core::clone::Clone for ethlambda_verification::types::Checkpoint}]
    Source: 'crates/verification/src/types.rs', lines 58:9-58:14 -/
@[reducible]
def types.Checkpoint.Insts.CoreCloneClone : core.clone.Clone types.Checkpoint
  := {
  clone := types.Checkpoint.Insts.CoreCloneClone.clone
}

/-- Trait implementation: [ethlambda_verification::types::{core::marker::Copy for ethlambda_verification::types::Checkpoint}]
    Source: 'crates/verification/src/types.rs', lines 58:16-58:20 -/
@[reducible]
def types.Checkpoint.Insts.CoreMarkerCopy : core.marker.Copy types.Checkpoint
  := {
  cloneInst := types.Checkpoint.Insts.CoreCloneClone
}

/-- [ethlambda_verification::types::{ethlambda_verification::types::Checkpoint}::default]:
    Source: 'crates/verification/src/types.rs', lines 65:4-70:5
    Visibility: public -/
def types.Checkpoint.default : Result types.Checkpoint := do
  ok { root := types.H256.ZERO, slot := 0#u64 }

/-- [ethlambda_verification::types::{core::clone::Clone for ethlambda_verification::types::AttestationData}::clone]:
    Source: 'crates/verification/src/types.rs', lines 74:9-74:14
    Visibility: public -/
def types.AttestationData.Insts.CoreCloneClone.clone
  (self : types.AttestationData) : Result types.AttestationData := do
  ok self

/-- Trait implementation: [ethlambda_verification::types::{core::clone::Clone for ethlambda_verification::types::AttestationData}]
    Source: 'crates/verification/src/types.rs', lines 74:9-74:14 -/
@[reducible]
def types.AttestationData.Insts.CoreCloneClone : core.clone.Clone
  types.AttestationData := {
  clone := types.AttestationData.Insts.CoreCloneClone.clone
}

/-- Trait implementation: [ethlambda_verification::types::{core::marker::Copy for ethlambda_verification::types::AttestationData}]
    Source: 'crates/verification/src/types.rs', lines 74:16-74:20 -/
@[reducible]
def types.AttestationData.Insts.CoreMarkerCopy : core.marker.Copy
  types.AttestationData := {
  cloneInst := types.AttestationData.Insts.CoreCloneClone
}

/-- [ethlambda_verification::types::{core::clone::Clone for ethlambda_verification::types::AggregatedAttestation}::clone]:
    Source: 'crates/verification/src/types.rs', lines 83:9-83:14
    Visibility: public -/
def types.AggregatedAttestation.Insts.CoreCloneClone.clone
  (self : types.AggregatedAttestation) :
  Result types.AggregatedAttestation
  := do
  let v ← alloc.vec.CloneVec.clone core.clone.CloneBool self.aggregation_bits
  let ad ← types.AttestationData.Insts.CoreCloneClone.clone self.data
  ok { aggregation_bits := v, data := ad }

/-- Trait implementation: [ethlambda_verification::types::{core::clone::Clone for ethlambda_verification::types::AggregatedAttestation}]
    Source: 'crates/verification/src/types.rs', lines 83:9-83:14 -/
@[reducible]
def types.AggregatedAttestation.Insts.CoreCloneClone : core.clone.Clone
  types.AggregatedAttestation := {
  clone := types.AggregatedAttestation.Insts.CoreCloneClone.clone
}

/-- [ethlambda_verification::types::{core::clone::Clone for ethlambda_verification::types::BlockHeader}::clone]:
    Source: 'crates/verification/src/types.rs', lines 90:9-90:14
    Visibility: public -/
def types.BlockHeader.Insts.CoreCloneClone.clone
  (self : types.BlockHeader) : Result types.BlockHeader := do
  let i ← lift (core.clone.impls.CloneU64.clone self.slot)
  let i1 ← lift (core.clone.impls.CloneU64.clone self.proposer_index)
  let h ← types.H256.Insts.CoreCloneClone.clone self.parent_root
  let h1 ← types.H256.Insts.CoreCloneClone.clone self.state_root
  let h2 ← types.H256.Insts.CoreCloneClone.clone self.body_root
  ok
    {
      slot := i,
      proposer_index := i1,
      parent_root := h,
      state_root := h1,
      body_root := h2
    }

/-- Trait implementation: [ethlambda_verification::types::{core::clone::Clone for ethlambda_verification::types::BlockHeader}]
    Source: 'crates/verification/src/types.rs', lines 90:9-90:14 -/
@[reducible]
def types.BlockHeader.Insts.CoreCloneClone : core.clone.Clone types.BlockHeader
  := {
  clone := types.BlockHeader.Insts.CoreCloneClone.clone
}

/-- [ethlambda_verification::types::{core::clone::Clone for ethlambda_verification::types::BlockBody}::clone]:
    Source: 'crates/verification/src/types.rs', lines 100:9-100:14
    Visibility: public -/
def types.BlockBody.Insts.CoreCloneClone.clone
  (self : types.BlockBody) : Result types.BlockBody := do
  let v ←
    alloc.vec.CloneVec.clone types.AggregatedAttestation.Insts.CoreCloneClone
      self.attestations
  ok { attestations := v }

/-- Trait implementation: [ethlambda_verification::types::{core::clone::Clone for ethlambda_verification::types::BlockBody}]
    Source: 'crates/verification/src/types.rs', lines 100:9-100:14 -/
@[reducible]
def types.BlockBody.Insts.CoreCloneClone : core.clone.Clone types.BlockBody
  := {
  clone := types.BlockBody.Insts.CoreCloneClone.clone
}

/-- [ethlambda_verification::types::{core::clone::Clone for ethlambda_verification::types::Block}::clone]:
    Source: 'crates/verification/src/types.rs', lines 106:9-106:14
    Visibility: public -/
def types.Block.Insts.CoreCloneClone.clone
  (self : types.Block) : Result types.Block := do
  let i ← lift (core.clone.impls.CloneU64.clone self.slot)
  let i1 ← lift (core.clone.impls.CloneU64.clone self.proposer_index)
  let h ← types.H256.Insts.CoreCloneClone.clone self.parent_root
  let h1 ← types.H256.Insts.CoreCloneClone.clone self.state_root
  let bb ← types.BlockBody.Insts.CoreCloneClone.clone self.body
  ok
    {
      slot := i,
      proposer_index := i1,
      parent_root := h,
      state_root := h1,
      body := bb
    }

/-- Trait implementation: [ethlambda_verification::types::{core::clone::Clone for ethlambda_verification::types::Block}]
    Source: 'crates/verification/src/types.rs', lines 106:9-106:14 -/
@[reducible]
def types.Block.Insts.CoreCloneClone : core.clone.Clone types.Block := {
  clone := types.Block.Insts.CoreCloneClone.clone
}

/-- [ethlambda_verification::types::{core::clone::Clone for ethlambda_verification::types::ChainConfig}::clone]:
    Source: 'crates/verification/src/types.rs', lines 116:9-116:14
    Visibility: public -/
def types.ChainConfig.Insts.CoreCloneClone.clone
  (self : types.ChainConfig) : Result types.ChainConfig := do
  let i ← lift (core.clone.impls.CloneU64.clone self.genesis_time)
  ok { genesis_time := i }

/-- Trait implementation: [ethlambda_verification::types::{core::clone::Clone for ethlambda_verification::types::ChainConfig}]
    Source: 'crates/verification/src/types.rs', lines 116:9-116:14 -/
@[reducible]
def types.ChainConfig.Insts.CoreCloneClone : core.clone.Clone types.ChainConfig
  := {
  clone := types.ChainConfig.Insts.CoreCloneClone.clone
}

/-- [ethlambda_verification::types::{core::clone::Clone for ethlambda_verification::types::Validator}::clone]:
    Source: 'crates/verification/src/types.rs', lines 122:9-122:14
    Visibility: public -/
def types.Validator.Insts.CoreCloneClone.clone
  (self : types.Validator) : Result types.Validator := do
  let a ← core.array.CloneArray.clone core.clone.CloneU8 self.pubkey
  let i ← lift (core.clone.impls.CloneU64.clone self.index)
  ok { pubkey := a, index := i }

/-- Trait implementation: [ethlambda_verification::types::{core::clone::Clone for ethlambda_verification::types::Validator}]
    Source: 'crates/verification/src/types.rs', lines 122:9-122:14 -/
@[reducible]
def types.Validator.Insts.CoreCloneClone : core.clone.Clone types.Validator
  := {
  clone := types.Validator.Insts.CoreCloneClone.clone
}

/-- [ethlambda_verification::types::VALIDATOR_REGISTRY_LIMIT]
    Source: 'crates/verification/src/types.rs', lines 132:0-132:49
    Visibility: public -/
@[global_simps, irreducible]
def types.VALIDATOR_REGISTRY_LIMIT : Std.Usize := 4096#usize

end ethlambda_verification
