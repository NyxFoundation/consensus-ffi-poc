-- SSZ Merkleization (`hash_tree_root`) in pure Lean, faithful to leanSpec's
-- spec/crypto/merkleization.py, built on the Rust SHA-256 primitive (Sha.lean).
--
-- Mirrors leanSpec exactly for the structure that drives cost:
--   * merkleize: pad chunk count to next_pow2(limit or count); reduce with
--     sha256(left ++ right); missing right siblings use cached zero-subtree roots.
--   * mix_in_length(root, n) = sha256(root ++ n_as_uint256_LE) for variable lists.
--   * basic types pack into 32-byte chunks (uint64 = 8 LE + zero pad, etc.).
--   * containers merkleize their field roots in declaration order.
--
-- Scope note: this hashes *our* Aeneas-extracted State/Block type tree (which is
-- an SSZ-compatible subset, not byte-identical to leanSpec's State container), so
-- roots are internally consistent rather than cross-validated against a leanSpec
-- node. The dominant cost — the O(V) validators list and O(R·V) justification
-- bits — is captured with the correct chunk counts and tree shapes.
import ConsensusLean4.Sha
import ConsensusLean4.Types
open Aeneas Aeneas.Std ethlambda_verification

namespace ConsensusLean4.Merkle

set_option linter.unusedVariables false

/-- SSZ list limits (mirror `types.VALIDATOR_REGISTRY_LIMIT` / `HISTORICAL_ROOTS_LIMIT`
in `Funs/Types.lean`; kept as literals to avoid importing the Funs umbrella). -/
def regLimit : Nat := 4096      -- 2^12
def histLimit : Nat := 262144   -- 2^18

/-! ## Chunk primitives -/

/-- 32 zero bytes (the SSZ zero leaf). -/
def zeroChunk : ByteArray := ⟨Array.replicate 32 0⟩

/-- sha256(left ++ right) over two 32-byte chunks. -/
@[inline] def hashPair (a b : ByteArray) : ByteArray := csfSha256 (a ++ b)

/-- Smallest power of two ≥ x; 1 for x ≤ 1 (matches leanSpec `_next_pow2`). -/
def nextPow2 (x : Nat) : Nat :=
  if x ≤ 1 then 1
  else if Nat.land x (x - 1) == 0 then x
  else 2 ^ (Nat.log2 x + 1)

/-- bit_length(n): 0 for n=0, else ⌊log2 n⌋+1. -/
@[inline] def bitLen (n : Nat) : Nat := if n == 0 then 0 else Nat.log2 n + 1

/-- Zero-subtree roots indexed by depth: zh[0] = zeroChunk, zh[d] = sha256(zh[d-1]‖zh[d-1]).
Built once per top-level hash_tree_root and threaded through (≤ ~40 hashes). -/
def zeroHashes (maxDepth : Nat) : Array ByteArray := Id.run do
  let mut arr := #[zeroChunk]
  for _ in [0:maxDepth] do
    arr := arr.push (hashPair arr.back! arr.back!)
  arr

/-- Root of an all-zero perfect tree of `width` leaves (`width` a power of two). -/
@[inline] def zeroTreeRoot (zh : Array ByteArray) (width : Nat) : ByteArray :=
  if width ≤ 1 then zeroChunk else zh[bitLen (width - 1)]!

/-- SSZ Merkle root over 32-byte chunks, with optional leaf-count `limit`. -/
def merkleize (zh : Array ByteArray) (chunks : Array ByteArray) (limit : Option Nat) :
    ByteArray :=
  let n := chunks.size
  if n == 0 then
    match limit with
    | some L => zeroTreeRoot zh (nextPow2 L)
    | none   => zeroChunk
  else
    let width := match limit with | some L => nextPow2 L | none => nextPow2 n
    if width == 1 then chunks[0]!
    else Id.run do
      let mut level := chunks
      let mut subtree := 1
      while subtree < width do
        let mut next : Array ByteArray := Array.mkEmpty ((level.size + 1) / 2)
        let mut i := 0
        while i < level.size do
          let left := level[i]!
          let right := if i + 1 < level.size then level[i + 1]! else zeroTreeRoot zh subtree
          next := next.push (hashPair left right)
          i := i + 2
        level := next
        subtree := subtree * 2
      level[0]!

/-- mix_in_length: sha256(root ‖ length-as-uint256-LE). -/
def mixInLength (root : ByteArray) (len : Nat) : ByteArray :=
  let lenLE : ByteArray := Id.run do
    let mut b := ByteArray.empty
    let mut i := 0
    while i < 32 do
      b := b.push (UInt8.ofNat (Nat.land (len >>> (8 * i)) 0xff))
      i := i + 1
    b
  csfSha256 (root ++ lenLE)

/-! ## Packing basic values into chunks -/

/-- Split `b` into 32-byte chunks, zero-padding the final chunk. -/
def packBytes (b : ByteArray) : Array ByteArray := Id.run do
  let n := b.size
  let mut chunks : Array ByteArray := #[]
  let mut i := 0
  while i < n do
    let mut c := ByteArray.empty
    let mut j := 0
    while j < 32 do
      c := c.push (if i + j < n then b.get! (i + j) else 0)
      j := j + 1
    chunks := chunks.push c
    i := i + 32
  chunks

/-- Pack bits little-endian into bytes, then into 32-byte chunks. -/
def packBits (bits : List Bool) : Array ByteArray := Id.run do
  let arr := bits.toArray
  let nbytes := (arr.size + 7) / 8
  let mut bytes := ByteArray.empty
  let mut k := 0
  while k < nbytes do
    let mut byte : UInt8 := 0
    let mut j := 0
    while j < 8 do
      if (arr[k * 8 + j]?).getD false then
        byte := byte ||| (1 <<< j.toUInt8)
      j := j + 1
    bytes := bytes.push byte
    k := k + 1
  packBytes bytes

/-! ## Per-type hash_tree_root (returns a 32-byte chunk) -/

@[inline] def u8ToByte (x : Std.U8) : UInt8 := UInt8.ofNat x.val

/-- htr(H256) = the 32 raw bytes (single chunk). -/
def htrH256 (h : types.H256) : ByteArray := ⟨(h.val.map u8ToByte).toArray⟩

/-- htr(U64) = 8 LE bytes + 24 zero (single chunk). -/
def htrU64 (x : Std.U64) : ByteArray := Id.run do
  let v := x.val
  let mut b := ByteArray.empty
  let mut i := 0
  while i < 32 do
    b := b.push (if i < 8 then UInt8.ofNat (Nat.land (v >>> (8 * i)) 0xff) else 0)
    i := i + 1
  b

/-- htr(Bytes52 pubkey) = merkleize of its 2 packed chunks. -/
def htrPubkey (zh : Array ByteArray) (pk : Array Std.U8 52#usize) : ByteArray :=
  merkleize zh (packBytes ⟨(pk.val.map u8ToByte).toArray⟩) none

def htrCheckpoint (zh : Array ByteArray) (c : types.Checkpoint) : ByteArray :=
  merkleize zh #[htrH256 c.root, htrU64 c.slot] none

def htrChainConfig (zh : Array ByteArray) (c : types.ChainConfig) : ByteArray :=
  merkleize zh #[htrU64 c.genesis_time] none

def htrValidator (zh : Array ByteArray) (v : types.Validator) : ByteArray :=
  merkleize zh #[htrPubkey zh v.pubkey, htrU64 v.index] none

def htrBlockHeader (zh : Array ByteArray) (h : types.BlockHeader) : ByteArray :=
  merkleize zh
    #[htrU64 h.slot, htrU64 h.proposer_index, htrH256 h.parent_root,
      htrH256 h.state_root, htrH256 h.body_root] none

def htrAttData (zh : Array ByteArray) (d : types.AttestationData) : ByteArray :=
  merkleize zh
    #[htrU64 d.slot, htrCheckpoint zh d.head, htrCheckpoint zh d.target,
      htrCheckpoint zh d.source] none

/-- htr(bitlist) = mix_in_length(merkleize(packed bits, limit chunks), bit count). -/
def htrBitlist (zh : Array ByteArray) (bits : List Bool) (limitBits : Nat) : ByteArray :=
  let limitChunks := (limitBits + 255) / 256
  mixInLength (merkleize zh (packBits bits) (some limitChunks)) bits.length

def htrAggAtt (zh : Array ByteArray) (a : types.AggregatedAttestation) : ByteArray :=
  merkleize zh
    #[htrBitlist zh a.aggregation_bits.val regLimit,
      htrAttData zh a.data] none

/-- htr(list of composite) = mix_in_length(merkleize(element roots, limit), len). -/
@[inline] def htrListComposite (zh : Array ByteArray)
    (roots : Array ByteArray) (limit : Nat) : ByteArray :=
  mixInLength (merkleize zh roots (some limit)) roots.size

def htrVecH256 (zh : Array ByteArray) (v : alloc.vec.Vec types.H256) (limit : Nat) : ByteArray :=
  htrListComposite zh ((v.val.map htrH256).toArray) limit

def htrVecValidator (zh : Array ByteArray) (v : alloc.vec.Vec types.Validator) : ByteArray :=
  htrListComposite zh ((v.val.map (htrValidator zh)).toArray) regLimit

def htrVecAggAtt (zh : Array ByteArray)
    (v : alloc.vec.Vec types.AggregatedAttestation) : ByteArray :=
  htrListComposite zh ((v.val.map (htrAggAtt zh)).toArray) regLimit

def htrBlockBody (zh : Array ByteArray) (b : types.BlockBody) : ByteArray :=
  merkleize zh #[htrVecAggAtt zh b.attestations] none

def htrBlock (zh : Array ByteArray) (b : types.Block) : ByteArray :=
  merkleize zh
    #[htrU64 b.slot, htrU64 b.proposer_index, htrH256 b.parent_root,
      htrH256 b.state_root, htrBlockBody zh b.body] none

/-- State container. Field order follows `types.State` (Funs/Types.lean). The two
bool vectors are treated as bitlists; list limits use the spec constants where
known. -/
def htrState (zh : Array ByteArray) (s : types.State) : ByteArray :=
  let hist := histLimit
  let reg := regLimit
  merkleize zh
    #[htrChainConfig zh s.config,
      htrU64 s.slot,
      htrBlockHeader zh s.latest_block_header,
      htrCheckpoint zh s.latest_justified,
      htrCheckpoint zh s.latest_finalized,
      htrVecH256 zh s.historical_block_hashes hist,
      htrBitlist zh s.justified_slots.val hist,
      htrVecValidator zh s.validators,
      htrVecH256 zh s.justifications_roots reg,
      htrBitlist zh s.justifications_validators.val (hist * reg)] none

/-! ## Public entry points (build zero-hash cache once, return H256). -/

private def maxTreeDepth : Nat := 48

@[inline] def byteToU8 (b : UInt8) : Std.U8 :=
  Std.U8.ofNat b.toNat (by
    have hlt : b.toNat < UInt8.size := b.toNat_lt
    have hsize : UInt8.size = 256 := by decide
    rw [Std.UScalar.cMax_eq_pow_cNumBits]
    show b.toNat ≤ 2 ^ Std.UScalarTy.U8.cNumBits - 1
    have hbits : Std.UScalarTy.U8.cNumBits = 8 := rfl
    rw [hbits]; omega)

/-- Convert a 32-byte chunk back into the Aeneas `H256` array type. -/
def chunkToH256 (b : ByteArray) : types.H256 :=
  Array.make 32#usize ((List.range 32).map (fun i => byteToU8 (b.get! i)))

def hashTreeRootState (s : types.State) : types.H256 :=
  chunkToH256 (htrState (zeroHashes maxTreeDepth) s)

def hashTreeRootBlockHeader (h : types.BlockHeader) : types.H256 :=
  chunkToH256 (htrBlockHeader (zeroHashes maxTreeDepth) h)

def hashTreeRootBlockBody (b : types.BlockBody) : types.H256 :=
  chunkToH256 (htrBlockBody (zeroHashes maxTreeDepth) b)

/-- Self-test against known SSZ values; returns 0 iff all pass. Validates uint64
LE packing, the 2-leaf merkleize, the SHA-256 wiring, and the zero-hash cache:
`htr(uint64 0)` = 32 zeros; `htr(uint64 1)` = 01‖00·31; `merkleize([0,0])` =
sha256(64 zeros) = f5a5fd42…fb4b (the canonical SSZ zerohashes[1]). -/
@[export csf_selftest_htr]
def csfSelftestHtr (_seed : UInt64) : UInt8 :=
  let zh := zeroHashes maxTreeDepth
  let c0 := htrU64 0#u64
  let ok1 := c0.size == 32 && (List.range 32).all (fun i => c0.get! i == 0)
  let c1 := htrU64 1#u64
  let ok2 := c1.get! 0 == 1 && (List.range 31).all (fun i => c1.get! (i + 1) == 0)
  let cp : types.Checkpoint := { root := chunkToH256 zeroChunk, slot := 0#u64 }
  let got := htrCheckpoint zh cp
  let want : ByteArray := ⟨#[
    0xf5, 0xa5, 0xfd, 0x42, 0xd1, 0x6a, 0x20, 0x30,
    0x27, 0x98, 0xef, 0x6e, 0xd3, 0x09, 0x97, 0x9b,
    0x43, 0x00, 0x3d, 0x23, 0x20, 0xd9, 0xf0, 0xe8,
    0xea, 0x98, 0x31, 0xa9, 0x27, 0x59, 0xfb, 0x4b]⟩
  let ok3 := got.size == 32 && (List.range 32).all (fun i => got.get! i == want.get! i)
  let ok4 := (List.range 32).all (fun i => (zh[1]!).get! i == want.get! i)
  if ok1 && ok2 && ok3 && ok4 then 0 else 1

end ConsensusLean4.Merkle
