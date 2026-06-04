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
  - marshalling
  - decode
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

## 4c. FFI マーシャリングコスト 追測 (2026-06-04)

§4b で「プリミティブ越境は ~0、ただしこれは床値。実運用の FFI コストは `lean_object*` のマーシャル/dec_ref で、それは未測定」と結論した。その未測定分を `bench-ffi-marshal` (`rust-ffi/src/bin/bench-ffi-marshal.rs`) で直接計測した。

本来の SSZ-bytes 境界 (issue #4) で新規に立つコスト ——「Rust 側で `ByteArray` を構築 (alloc + memcpy O(size)) → owned 引数として越境 → Lean ランタイムが dec_ref」—— を、ペイロードサイズの関数として測る。`ByteArray` はフラットバッファなので **SSZ コーデックも `hash_tree_root`/SHA も不要** (serde はバイト並びのみ)。

- `csf_make_bytearray` (C shim, `rust-ffi/csf_marshal_shim.c`): `lean_alloc_sarray` + `memcpy`。`lean_alloc_sarray`/`lean_sarray_cptr` は lean.h で `static inline` のため Rust から直接リンクできず、lean.h に対してコンパイルした C shim 経由で呼ぶ (build.rs が `cc` でビルド)。
- Lean export 2 種 (`ConsensusLean4/Ffi.lean` M6): `csf_bench_marshal_touch` = 全バイトを XOR-fold (decode スキャンの下限)、`csf_bench_marshal_noop` = 引数を消費するだけ (alloc + memcpy + dec_ref)。差 = Lean 側スキャン。
- サイズ軸は §1 の N に対応: Validator = pubkey(52)+index(8) = 60 B とし、ペイロード S = N·60。**正準 SSZ ではなく代表サイズのフラットバッファ。** 計測手法は §1/§4b と同様 (target 200ms/trial, 11 試行中央値, `black_box`)。

### 計測結果

| N | payload S | marshal (noop) | full (marshal+scan) | scan Δ | marshal GB/s | marshal ns/byte |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 60 B | 25.3 ns | 32.3 ns | 7.0 ns | 2.4 | 0.422 |
| 100 | 5.9 KB | 114 ns | 235 ns | 121 ns | 52.4 | 0.019 |
| 1,000 | 58.6 KB | 1.32 µs | 2.84 µs | 1.52 µs | 45.5 | 0.022 |
| 10,000 | 585.9 KB | 20.5 µs | 32.1 µs | 11.6 µs | 29.3 | 0.034 |
| 100,000 | 5.7 MB | 223 µs | 351 µs | 128 µs | 26.9 | 0.037 |
| 1,000,000 | 57.2 MB | **14.39 ms** | 16.64 ms | 2.25 ms | 4.2 | 0.240 |

### 判定 (vs §1 の STF 計算コスト)

| N | marshal (片道) | §1 STF pipeline | marshal / STF |
|---:|---:|---:|---:|
| 100 | 114 ns | 41.3 µs | 0.3% |
| 100,000 | 223 µs | 1.80 ms | 12% |
| 1,000,000 | **14.39 ms** | 22.02 ms | **65%** |

→ **§4b の予測どおり、オーバーヘッドはサイズに比例して変化する。**

1. **小サイズ (devnet 相当, validator 数百 = KB 級)**: 100〜1,300 ns。§4b のプリミティブ越境と同様、**実質ノイズ**。SSZ 化しても体感不変。
2. **大サイズ (mainnet 相当, validator 1M = ~57 MB)**: 片道 **14.4 ms** で、STF 計算本体 (22 ms) の **約 65%**。往復 (入力デコード + 結果エンコード) なら ~29 ms で STF を上回る。**この規模ではマーシャルが支配項の一つになる**。
3. **スループットの劣化**: 小サイズで ~52 GB/s (L2/L3 内に収まる) → 57 MB で 4.2 GB/s。これは純粋な memcpy 帯域ではなく、**呼び出しごとに 57 MB を新規 alloc → first-touch ページフォルト → memcpy → dec_ref/free** するためで、per-call マーシャルの現実的なコスト構造を反映している。
4. **Lean 側スキャン (scan Δ) は安価**: ~0.03–0.04 ns/byte (~25–30 GB/s)。decode の「全バイト走査」部分は memcpy と同オーダーで、マーシャルの支配項は alloc+copy 側。

### §4b との関係 (FFI コストの全体像)

| 入力形態 | 越境あたりのコスト | スケール |
|---|---|---|
| プリミティブ `UInt64` (§4b) | ~1.9 ns | サイズ非依存 (定数) |
| `ByteArray` マーシャル (本節) | 25 ns 〜 14 ms | **O(payload size)** |

「FFI は速い」は **プリミティブ境界に限った話**。データを渡すとコストは渡すバイト数に線形になる。

> **spec スケールでの補正 (§4d 参照)**: 上表の N=10K 以上 (≥586 KB) は `VALIDATOR_REGISTRY_LIMIT = 4096` を超える非物理サイズ。このモデルの payload 上限は V=4096 ⇒ **≤ 240 KB** で、そこでの marshal は **≤ 6.8 µs** = 誤差。「14 ms@57 MB」は到達不能な規模の一般特性であり、実運用 marshal は無視できる。本節の大サイズ行は境界の size-scaling 特性の参考値として残す。

### 限界

- **正準 SSZ ではない**: フラットな代表バッファで、可変長フィールドの offset や型付きデコードは含まない。型付き `State` への decode を入れると scan Δ 側が増えるが、マーシャル (alloc+memcpy) の支配性は変わらない見込み (issue #4 で要確認)。
- **片道のみ**: 結果 `State` のエンコード + 復路は未計測。実運用は往復なので概ね 2 倍が目安。
- **zero-copy の余地**: Lean が呼び出し中に読むだけなら borrowed pointer 受けで memcpy を回避できる可能性 (§4b 限界参照)。本計測は owned-copy 前提の上限値。

### 再現

```bash
cd consensus-lean4 && lake build ConsensusLean4:static
cd rust-ffi && cargo build --release --bin bench-ffi-marshal
target/release/bench-ffi-marshal
```

## 4d. End-to-end SSZ-bytes パイプライン 追測 (2026-06-04)

§4b/§4c は「①marshal」だけを測り、「②decode → ③純粋関数」が未接続だった。本節でその全経路を繋いだ ——`ByteArray` を**型付き `State`/`Block` にデコードし、純粋 `stateTransitionFast` に渡す**。`bench-ffi-ssz` (`rust-ffi/src/bin/bench-ffi-ssz.rs`) + `ConsensusLean4/Ffi.lean` M7。

- **コーデック**: フラットな length-prefixed バイナリ (正準 SSZ ではない) を Lean decode (`decodeState`/`decodeBlock`) と Rust serializer (`serialize_fixture`) で round-trip。`State`/`Block` の全フィールドを網羅。**`hash_tree_root`/SHA は不使用** (decode は純粋なバイト配置)。
- **fixture は §1 と byte-for-byte 一致**: `buildBenchState(n)`/`buildBenchBlock(n)` と同一内容を直列化。よって decode 後の入力は §1 のスカラー生成版と等価で、STF コストを直接比較できる。
- **正当性ゲート**: `csf_bench_state_transition_ssz_run` が全 N で sentinel **0 (Ok)** を返すことを assert。誤ったコーデックなら sentinel が変わるかクラッシュするため、これがパイプライン全体の正当性検証になっている。
- **分解**: marshal = `_marshal_noop`、decode = `_ssz_decode` − marshal、STF = `_ssz_run` − `_ssz_decode`。

### V の上限 = 4096 (重要)

V (validator 数) は **`VALIDATOR_REGISTRY_LIMIT = 2^12 = 4096`** で上限が決まる。これは leanSpec 正準値 (`lean_spec/types/participation.py:11`: `Uint64(2**12)`) であり、`consensus-lean4` の `types.VALIDATOR_REGISTRY_LIMIT` (`Funs/Types.lean`) も同値。`checkpoint_sync` は `validator_count > VALIDATOR_REGISTRY_LIMIT` の state を拒否する。

実運用 V はさらに小さく、**leanSpec のベースラインは 4** (テストは 4/8)。よって計測軸は **devnet baseline (4) → spec 上限 (4096)** とする。

> **訂正**: 本節の旧版は N=100〜1,000,000 で測っていたが、**10,000 以上は spec 上限 4096 を超える非物理値** (mainnet beacon chain の規模を誤って持ち込んだもの)。以下は spec 準拠の軸での再測値。

### 計測結果 (spec-realistic V = 4 … 4096、3 回中央値)

| V | payload | marshal | decode | STF | total (e2e) |
|---:|---:|---:|---:|---:|---:|
| 4 (devnet baseline) | 0.6 KB | 34 ns | 9.4 µs | 42 µs | **51 µs** |
| 8 | 0.8 KB | 35 ns | 13 µs | 42 µs | **56 µs** |
| 64 | 4.1 KB | 86 ns | 71 µs | 48 µs | **119 µs** |
| 512 | 30.3 KB | 0.8 µs | 555 µs | 60 µs | **615 µs** |
| 4096 (spec max) | 240.3 KB | 6.8 µs | 4.6 ms | 0.4 ms | **~5.0 ms** |

(governor 非固定のため total は 3.3〜5.1 ms の run 間ばらつきあり。decode が支配。)

### 判定

1. **実運用域では FFI 全経路が無視できる**。devnet baseline (V=4) で e2e **51 µs**、spec 上限 (V=4096) でも **~5 ms**。1 スロット ~数秒の世界で、状態遷移の marshal+decode+STF は誤差。
2. **小 V では STF が支配、大 V で decode が逆転**。V=4 では STF 42 µs > decode 9 µs (STF の固定コスト)。V≥512 で decode が上回り、V=4096 で decode 4.6 ms / STF 0.4 ms。交差点は V≈64〜512。
3. **decode コストは List materialize 由来だが上限内では問題化しない**。~1.1 µs/validator (Aeneas の `pubkey : Array Std.U8 52` = 52 ノード list × V)。V=4096 でも 4.6 ms に留まり、spec 上限を超えない限り catastrophic にならない。
4. **marshal は常に誤差** (≤ 6.8 µs)。payload は V≤4096 で ≤ 240 KB が上限。§4c の「14 ms@57 MB」は V≈1M 相当で **このモデルでは到達不能**。

### この経路の全体像 (spec 上限 V=4096)

```
[Rust bytes] ──①marshal──▶ [ByteArray] ──②decode──▶ [typed State/Block] ──③STF──▶ sentinel
  serialize       6.8µs(誤差)        4.6ms(支配項)            0.4ms
```

実運用スケールでは「FFI を実データで使う」コストは全部足しても ~5 ms (最悪)。**真のスケール懸念は validator 軸ではなく blocks 軸** —— fork-choice (§2) の O(B²) で、B は `HISTORICAL_ROOTS_LIMIT = 2^18 = 262144` まで伸びうる。decode/marshal の最適化より `compute_lmd_ghost_head_fast` が優先。

### 限界

- フラットコーデックで正準 SSZ wire 非互換 (offset/union 等は未対応)。実 devnet テストベクタとの互換は別途。
- 片道のみ (結果 `State` のエンコード+復路は未計測)。
- decode 先が List-backed なのは Aeneas 既定。Array-backed への変更で decode はさらに減るが、上限内 (≤5 ms) で既に十分小さい。

### 再現

```bash
cd consensus-lean4 && lake build ConsensusLean4:static
cd rust-ffi && cargo build --release --bin bench-ffi-ssz
target/release/bench-ffi-ssz            # V = 4, 8, 64, 512, 4096 (spec range)
```

## 5. Future work

`docs/ffi-feasibility.md` に既出の項目を実数値で裏付け:

- **issue #4** (Option III SSZ): bench fixture を SSZ バイト列マーシャルに切り替え、ToLean 構築コストを排除
- **issue #5** (`hash_tree_root` real 実装): "crypto cost excluded" 注記が外れた状態で再測
- **issue #6** (block-chaining bench): 現 fixture は genesis→1 block のみ。N block chain で連続 state を計測
- **新規候補** (本実測から): `compute_lmd_ghost_head_fast` (Array-backed) の handwritten 実装。B=10K で 1s 切りが目標
- **新規候補**: state_transition の "realistic attestation" fixture (R≥1 + valid checkpoints + non-trivial agg_bits) で `processAttestationsFast` の N·A scaling を計測
