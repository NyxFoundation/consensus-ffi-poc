---
title: Rust ↔ Lean 4 FFI ベンチマーク 実測結果
last_updated: 2026-06-04
tags:
  - benchmark
  - ffi
  - results
  - state-transition
  - fork-choice
  - boundary-cost
---

# Rust ↔ Lean 4 FFI ベンチマーク 実測結果

`docs/ffi-implementation-plan.md` M5 で計画したベンチマークの実測値。判定基準は [`docs/timing-budget.md`](./timing-budget.md) を参照。

## 計測環境

| 項目 | 値 |
|---|---|
| CPU | AMD Ryzen 9 PRO 8945HS (Zen 4 mobile, 8C/16T) |
| OS | Linux 6.18.12+kali-amd64 x86_64 |
| Lean | v4.28.0-rc1 (3b0f286, Release build) |
| Aeneas | rev 864eddb4 (per `lake-manifest.json`) |
| Rust | release profile + thin LTO + codegen-units=1 |
| 計測手法 | `std::time::Instant` + paired-delta (`csf_bench_*_run` − `csf_bench_*_buildonly` median) |
| 試行数 | 5 (default), 1 (reference cells) |
| iter/trial | 適応 (target 100ms/trial, calibration 3s budget) |
| メモリ | `getrusage(RUSAGE_SELF).ru_maxrss` 差分 |

> **注**: CPU governor / `taskset` ピン止めは未適用 (デフォルトのまま測定)。governor=performance + taskset 適用で IQR は更に縮む見込み。再測時のオプション。

## 重要な前提と限界

1. **暗号コストは除外** (A3): `hash_tree_root_*` は ZERO スタブ (`Funs/Types.lean:138-156`)。本物の SSZ ハッシュ計算は加算されない。
2. **Bench fixture は最小ワークロード** (M5 scope):
   - `state_transition`: V (= n) validators の State + 0 attestations の Block。`processAttestationsFast` の inner V loop は 0 回 (justifications_roots が空 → cells 空)。N の支配項は `buildBenchValidators` の `List.replicate` + `collapseJustifications` の `R*V = 1*V` flat array allocation。
   - `compute_lmd_ghost_head`: 線形チェーン B blocks + A attestations が最終 block にすべて投票。`alloc.vec.Vec` が `List`-backed のため、内部の block index は `List.indexOf` ベースで O(B)。
   - 実運用相当のワークロード (multiple targets, valid checkpoints with real justification windows) は richer fixture を要し本タスクでは対象外。
3. **paired-delta** はビルド構築コストを差し引く (`@[noinline] consumeState/consumeBlock` で Lean の DCE を抑止して buildonly twin が実際にビルド工程を踏むことを保証)。

## 1. `state_transition` (handwritten Array fast path)

軸: N (validators), A=64 fixed (block has 0 attestations as noted above).

| N | trials | iters/trial | run median | buildonly | **pipeline (Δ)** | IQR (run) | sentinel |
|---:|---:|---:|---:|---:|---:|---:|:---:|
| 100 | 5 | 2,714 | 42.2 µs | 884 ns | **41.3 µs** | 4.2 µs | 0 |
| 1,000 | 5 | 1,974 | 91.6 µs | 15.1 µs | **76.5 µs** | 11.3 µs | 0 |
| 10,000 | 5 | 179 | 421.1 µs | 140.4 µs | **280.7 µs** | 77.9 µs | 0 |
| 100,000 | 5 | 34 | 3.32 ms | 1.52 ms | **1.80 ms** | 664.6 µs | 0 |
| 1,000,000 | 1 | 1 | 35.20 ms | 13.18 ms | **22.02 ms** | n/a | 0 |

`ru_maxrss` delta:
- N=100→100K (1 process): **6 MB**
- N=1M 単独 process: **68 MB** (List.replicate で 1M Validator records の連結リスト)

### 判定 (vs `docs/timing-budget.md` §4 SLO target = <200ms, §3 outer = <800ms)

| N | pipeline | target | outer | 判定 |
|---:|---:|:---:|:---:|:---:|
| 100 | 41.3 µs | ✓ | ✓ | 🟢 green |
| 1,000 | 76.5 µs | ✓ | ✓ | 🟢 green |
| 10,000 | 280.7 µs | ✓ | ✓ | 🟢 green |
| 100,000 | 1.80 ms | ✓ | ✓ | 🟢 green |
| 1,000,000 | 22.02 ms | ✓ | ✓ | 🟢 green |

→ **N=1M まで全て green** (パイプライン 22ms < target 200ms)。M5 計画が外挿していた値 (N=10K で ~100ms、N=100K で ~1s、N=1M で ~10s) より**2 桁速い**。本 fixture が attestation 処理を踏まないため、計算の支配項が `processAttestationsFast` の inner V loop ではなく `collapseJustifications` の `R*V` flat allocation (R=1, V=N) になっている点に留意 (上記限界 §2)。

外挿元の PR #3 fast-path 単独ベンチは attestation あり前提だったので、本数値は handwritten fast path の**構成的下限**(全 V を流す処理時間の floor) を示すと解釈すべき。実運用相当の attestation-rich workload で再測しても N=1M で <200ms を維持する保証はない。

## 2. `compute_lmd_ghost_head` (Aeneas direct, no fast path)

軸: (B blocks, A attestations) ∈ `{100} × {32, 128}` × 5 試行 (default)。
`B=1K` は `--include-1k` で opt-in (cell あたり ~6 分以上)、`B=10K` は `--include-10k` で opt-in (cell あたり**時間単位**、推奨せず)。default が `B=100` のみなのは、Aeneas-generated 版が `List`-backed `Vec` を介するため B²(以上) で爆発するため。

| B | A | trials | iters/trial | run median | buildonly | **pipeline (Δ)** | IQR (run) | sentinel |
|---:|---:|---:|---:|---:|---:|---:|---:|:---:|
| 100 | 32 | 5 | 1 | 313.77 ms | 114.9 µs | **313.65 ms** | 6.49 ms | 0 |
| 100 | 128 | 5 | 1 | 1.22 s | 108.3 µs | **1.22 s** | 11.07 ms | 0 |
| 1,000 | 32 | (opt-in) | 1 | (~6+ min) | — | (>60s 推定) | n/a | — |
| 1,000 | 128 | (opt-in) | 1 | — | — | (>4 min 推定) | n/a | — |
| 10,000 | 32 | (opt-in) | 1 | — | — | (時間単位) | n/a | — |
| 10,000 | 128 | (opt-in) | 1 | — | — | (時間単位) | n/a | — |

> **B=1K は opt-in 必須 (`--include-1k`)** — 試行で kill された 6+ 分の per-call がベースライン。Lean の List-backed Vec で compute_block_weights が super-quadratic に振る舞うため。本 README に numerical estimate のみ記載し、実測値は次回 fast-path 着手時に取り直す方針。
> **B=10K は推奨しない** — 単発 cell が時間単位で、CPU 専有の影響が大きい。

### 判定 (vs `docs/timing-budget.md` §4 SLO target = <100ms, §3 outer = <800ms)

| B | A | pipeline | target | outer | 判定 |
|---:|---:|---:|:---:|:---:|:---:|
| 100 | 32 | 313.65 ms | ✗ (3.1×) | ✓ | 🟡 yellow |
| 100 | 128 | 1.22 s | ✗ (12.2×) | ✗ (1.5×) | 🔴 red |
| 1,000 | 32 | (>60 s 推定) | ✗ | ✗ | 🔴 red |
| 1,000 | 128 | (推定) | ✗ | ✗ | 🔴 red |
| 10,000 | 32 | (時間単位) | ✗ | ✗ | 🔴 red |
| 10,000 | 128 | (時間単位) | ✗ | ✗ | 🔴 red |

→ **B=100 ですら target を超過 (yellow)、A=128 では outer も超過 (red)**。Aeneas-generated `compute_lmd_ghost_head` は `List`-backed `alloc.vec.Vec` を介するため block 探索が O(B) per access。compute_block_weights の per-attestation walk と組み合わせて O(A·B²) になる結果が見えている (= `Ffi.lean#L61` "linear in attestations, quadratic in blocks" の定量化)。**A scaling は B=100 で 32→128 (4×) で実測 ~3.9× → linear in A は確認**、B² scaling は 100→1K で 100× を expect していたが実測は >190×、よって**実態は super-quadratic**。

A axis scaling check (B=100 fixed):
- A=32 → 313 ms
- A=128 → 1220 ms (= 3.9× → 線形 4× にほぼ一致)

## 3. 主な観察

1. **`stateTransitionFast` は M5 計画外挿より 2 桁速い**: N=1M で 22 ms (計画 ~10s)。理由は §限界 (2-i) — fixture が attestation 処理を踏まないため、計算支配項が `collapseJustifications` の R*V allocation のみ。**実運用相当 (R≥1 + valid attestations) で再測すれば桁が上がる可能性あり** (future work)。
2. **`compute_lmd_ghost_head` は B=100 ですら SLO target 超過**: 313ms (A=32) / 1220ms (A=128) vs target 100ms。`Ffi.lean#L61` の "quadratic in blocks" が Lean の List-backed Vec で表面化しており、A 軸は実測 4× linear に従う。mainnet 級 B=32K は外挿で**時間単位**になり、専用 fast path (`compute_lmd_ghost_head_fast`、別 issue 候補) なしには実運用不可。
3. **build cost (paired-delta の片側) は state_transition で支配的**: N=100K で 1.52 ms / 3.32 ms (run の 46%)、N=1M で 13.18 ms / 35.20 ms (37%)。`List.replicate n + Vec ⟨xs, ...⟩` の strict allocation。paired-delta による減算で正味 pipeline コストを抽出している。
4. **メモリスケーリング**: state_transition `ru_maxrss` delta は N=100K で 6 MB、N=1M で 68 MB (約 11×、ほぼ N に linear)。`alloc.vec.Vec α := { l : List α // ... }` の List node × N + Validator struct × N が支配。
5. **2 エントリポイントの実運用域は対極**: `state_transition` (handwritten fast path) は N=1M で余裕の green、`compute_lmd_ghost_head` (Aeneas 直) は B=100 で既に red 隣接の yellow。後者の fast path 実装が実運用への最大ボトルネック。

## 4. 再現手順 (3 ステップ)

```bash
# 1. Lean toolchain 確認
elan which lean    # → leanprover-lean4-v4.28.0-rc1

# 2. Lean + Rust ビルド (build.rs が lake build を自動 invoke)
cd consensus-lean4 && lake build ConsensusLean4:static
cd rust-ffi && cargo build --release

# 3. ベンチ実行 (per-cell isolation 推奨: cargo run はせず target/release を直接呼ぶ)
target/release/bench-state-transition                      # N=100,1K,10K,100K (~3 s)
target/release/bench-state-transition --include-1m         # + N=1M (1 trial、別 process 推奨で N=1M 単独 ~0.1 s + ~70 MB rss)
target/release/bench-fork-choice                           # B=100 × A=32,128 (~20 s)
target/release/bench-fork-choice --include-1k              # + B=1K × A=32,128 (cell ~6+ 分、計 30 分超)
target/release/bench-fork-choice --include-10k             # + B=10K × A=32,128 (cell 時間単位、推奨せず)

# Per-cell ru_maxrss isolation (推奨):
target/release/bench-state-transition --single-n=100000
target/release/bench-state-transition --single-n=1000000
target/release/bench-fork-choice --single-cell=100,32
target/release/bench-fork-choice --single-cell=100,128
```

## 4b. FFI 境界コスト 追測 (2026-06-04)

§1/§2 の `pipeline (Δ)` は paired-delta で **FFI 越境コストを相殺**しており、境界そのもののコストは測っていなかった。これを別ハーネス `bench-ffi-overhead` (`rust-ffi/src/bin/bench-ffi-overhead.rs`) で直接計測した。

計測対象は `csf_ping` (`@[export] def csfPing (n : UInt64) : UInt64 := n + 1`) — 最小の `@[export]`。Rust から tight loop で叩き、`black_box` で DCE を抑止して 1 コールあたりのコストを出す。比較基準は同形の Rust ローカル不透明関数 `rust_ping` (`#[inline(never)]`)。差分が「Rust→Lean 越境が、通常の非インライン関数呼び出しに上乗せするコスト」。

計測環境は §計測環境と同一 (Ryzen 9 PRO 8945HS, release + thin LTO)。iters/trial は target 200ms に適応キャリブレーション、15 試行の中央値。

| call path | median | min | IQR |
|---|---:|---:|---:|
| **FFI** `csf_ping` (Rust→Lean) | **~1.9 ns** | ~1.3 ns | ~0.4 ns |
| Rust-local `rust_ping` (越境なし) | ~1.9 ns | ~1.3 ns | ~0.4 ns |
| **境界オーバーヘッド (差分)** | **−0.06 〜 +0.12 ns** (4 回反復) | — | — |

### 判定

**プリミティブ引数の FFI 越境オーバーヘッドは測定ノイズ以下 (実質ゼロ)。** `csf_ping` の FFI 呼び出しは通常の非インライン関数呼び出し (~1.9 ns) と統計的に区別できない。Lean の `@[export]` は名前マングルなしの C シンボルを出し、`UInt32`/`UInt64` 等のアンボックス型は unbox のまま渡るため、生成されるのは単なる `call` 命令 1 個で、ランタイムのトランポリンも箱詰めも介在しない。

→ §1/§2 が paired-delta で越境コストを相殺した設計判断は妥当だった (相殺対象が元々ゼロ)。

### 限界 (重要)

**これは床値であって実運用の FFI コストではない。** 本ビルドには構造体マーシャル層 (`docs/ffi-feasibility.md` A23 / issue #4) が存在せず、境界を渡るのは `UInt64` のみ。実運用で支配的になる **`lean_object*` の箱詰め・`Array`/`Vec` のコピー・参照カウント (inc/dec) のコストは未測定**。`Ffi.lean` の `csf_*_noop` ツイン (構造体引数を受けて即 return; "subtract pure FFI/dec_ref cost" のための足場) は本追測では未使用 — Rust 側に lean_object* を組む ToLean 層が無く呼べないため。dec_ref/マーシャルの実測は issue #4 (Option III SSZ バイト列マーシャル) 実装後に行う。

### 再現

```bash
cd consensus-lean4 && lake build ConsensusLean4:static
cd rust-ffi && cargo build --release --bin bench-ffi-overhead
target/release/bench-ffi-overhead
```

## 5. Future work

`docs/ffi-feasibility.md` に既出の項目を実数値で裏付け:

- **issue #4** (Option III SSZ): bench fixture を SSZ バイト列マーシャルに切り替え、ToLean 構築コストを排除
- **issue #5** (`hash_tree_root` real 実装): "crypto cost excluded" 注記が外れた状態で再測
- **issue #6** (block-chaining bench): 現 fixture は genesis→1 block のみ。N block chain で連続 state を計測
- **新規候補** (本実測から): `compute_lmd_ghost_head_fast` (Array-backed) の handwritten 実装。B=10K で 1s 切りが目標
- **新規候補**: state_transition の "realistic attestation" fixture (R≥1 + valid checkpoints + non-trivial agg_bits) で `processAttestationsFast` の N·A scaling を計測
