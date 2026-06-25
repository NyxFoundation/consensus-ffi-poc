# consensus-ffi-poc

Lean 4 formalization of the [Lean Consensus](https://github.com/leanEthereum/leanSpec) (3SF-mini) protocol, automatically generated from a Rust implementation using [Aeneas](https://github.com/AeneasVerif/aeneas).

## What's included

The generated Lean code covers the core consensus algorithms:

- **State transition** — `process_slots`, `process_block_header`, `process_attestations`, `try_finalize`
- **Fork choice** — `compute_lmd_ghost_head`, `compute_block_weights` (LMD GHOST)
- **Justified slots** — `is_slot_justified`, `set_justified`, `extend_to_slot`, `shift_window`
- **3SF-mini justifiability** — `slot_is_justifiable_after` (delta ≤ 5, perfect squares, pronic numbers)

## Layout

```
ConsensusLean4.lean                  -- root index, re-exports the three modules below
ConsensusLean4/
├── Types.lean                       -- `H256`, `Checkpoint`, `Block`, …
├── Funs.lean                        -- umbrella that imports the four submodules below
├── Funs/
│   ├── Types.lean                   -- `types.*` defs (H256 instances, hash-tree-root stubs, clone instances)
│   ├── JustifiedSlots.lean          -- `justified_slots.*` defs
│   ├── ForkChoice.lean              -- `fork_choice.*` defs (LMD GHOST)
│   └── StateTransition.lean         -- `state_transition.*` defs (block + attestation processing)
├── FunsExternal_Template.lean       -- auto-generated signatures for external functions
└── FunsExternal.lean                -- active implementation file (edit this)
```

`Funs.lean` was originally a single ~3000-line file emitted by Aeneas; it has
been manually split into the four submodules above so each namespace can be
reviewed independently. **Re-running Aeneas would overwrite `Funs.lean` with a
single monolithic module again** — if you need to regenerate, expect to redo
the split or drop it.

`Funs/*.lean` import `ConsensusLean4.FunsExternal`, so `FunsExternal.lean` is
the single swap point for anyone wanting to replace the `axiom` stubs with
real Lean implementations. `FunsExternal_Template.lean` is refreshed on every
Aeneas run and serves as the canonical signature reference — diff it against
`FunsExternal.lean` to catch upstream signature drift.

The extracted code is wrapped in `noncomputable section` because the five standard
library functions used by the Rust source (`Vec::clear`, `Vec::is_empty`,
`Ordering::eq`, `Result::branch`, `Result::from_residual`) are left as `axiom`s.
Dropping the `noncomputable section` marker (via Aeneas's `-all-computable` flag) is
only safe once `FunsExternal.lean` provides executable implementations for every
axiom.

## Build

Requires [Lean 4](https://leanprover.github.io/lean4/doc/setup.html) and [elan](https://github.com/leanprover/elan).

```bash
lake build
```

The Aeneas runtime library (and its Mathlib dependency) is fetched automatically via
`lakefile.lean`.

## Benchmarks (M5)

The handwritten fast path for `state_transition` and the Aeneas-generated `compute_lmd_ghost_head`
are exposed to a Rust harness via `@[export]` symbols in `ConsensusLean4/Ffi.lean`. The harness
measures pipeline cost via paired-delta against a `_buildonly` twin (Lean DCE is suppressed with
`@[noinline]` consume helpers so the build phase is genuinely captured).

```bash
# 1. Verify the toolchain.
elan which lean

# 2. Build Lean static + Rust bench bins (build.rs auto-invokes `lake build`).
lake build ConsensusLean4:static
cd rust-ffi && cargo build --release

# 3. Run the benches. The V axis is bounded by the leanSpec validator registry
#    limit (VALIDATOR_REGISTRY_LIMIT = 2^12 = 4096); `--include-1m` adds a
#    mainnet out-of-spec reference. Per-cell `ru_maxrss` isolation needs separate
#    invocations.
target/release/bench-state-transition                      # V ∈ {4, 8, 64, 512, 4096}, A=8 valid attestations
target/release/bench-state-transition --include-1m         # + V=1M (mainnet, out-of-spec; ~4 s, ~584 MB)
target/release/bench-ffi-marshal                           # V ∈ {1, 4, 8, 64, 512, 4096} ByteArray marshal cost
target/release/bench-fork-choice                           # B=100 × A ∈ {32, 128} (no V axis; B ≤ HISTORICAL_ROOTS_LIMIT=2^18)
target/release/bench-fork-choice --include-1k              # + B=1K (~6 min/cell)
target/release/bench-state-transition --single-n=4096      # one cell, ru_maxrss-clean
```

The `state_transition` bench loads each block with A = `MAX_ATTESTATIONS_DATA` = 8 valid
attestations so the `O(A·V)` fast path actually runs, and asserts a fixture self-check
(`att_cells == 9`) before timing. Reference budgets and judgment criteria live in
[`docs/timing-budget.md`](docs/timing-budget.md); the spec-constant axis rationale and
detailed result tables are in [`docs/rust-ffi-benchmarks.md`](docs/rust-ffi-benchmarks.md)
(§0 pins the leanSpec / mainnet constants). Crypto cost (`hash_tree_root_*`) is excluded —
those return `H256.ZERO` per the spec stubs in `ConsensusLean4/Funs/Types.lean`.

## Source

Generated from the [ethlambda](https://github.com/lambdaclass/ethlambda) Rust codebase
using the [Charon](https://github.com/AeneasVerif/charon) + [Aeneas](https://github.com/AeneasVerif/aeneas)
pipeline:

```
Rust (ethlambda consensus crates)
  → Charon (MIR → LLBC)
    → Aeneas (LLBC → Lean 4)
```

The Rust source was adapted into an Aeneas-compatible subset: `HashMap` replaced with
`Vec<(K,V)>`, iterator chains replaced with explicit loops, proc-macro derives removed,
and `hash_tree_root` stubbed as a placeholder.

### Regeneration command

```bash
aeneas \
  -backend lean \
  -split-files \
  -subdir ConsensusLean4 \
  -dest <repo-root> \
  ethlambda_verification.llbc
```

`-split-files` isolates external axioms into `FunsExternal_Template.lean`;
`-subdir ConsensusLean4` emits the import paths under the `ConsensusLean4.*`
namespace. Regenerating overwrites `Types.lean`, `Funs.lean`, and
`FunsExternal_Template.lean` but leaves `FunsExternal.lean` untouched. Add
`-all-computable` once `FunsExternal.lean` has real implementations for every
axiom.

## License

MIT
