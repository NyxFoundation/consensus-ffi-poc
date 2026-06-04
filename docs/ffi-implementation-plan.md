---
title: Rust ↔ Lean 4 FFI ベンチマーク 実装計画
last_updated: 2026-05-05
tags:
  - ffi
  - implementation
  - plan
---

# Rust ↔ Lean 4 FFI ベンチマーク 実装計画

> **前提**: [調査メモ](./ffi-feasibility.md) が承認済。本書はその §4.1 骨子を具体的な実装ステップに落とし込んだもので、**実装開始前にユーザー承認を取る**。

## Context

調査メモで決まった方針の組み合わせを実装する:

- **Option A**: 独立 feature branch で再実装 (PR #2 / #3 は参考のみ)
- **Option X**: 2 エントリポイント (`state_transition`, `compute_lmd_ghost_head`) をそれぞれ 1 FFI コールで e2e 実行
- **Option II**: Rust 側で State/Block を構築し `ToLean` で marshal、`lean_object*` を渡す
- 計測は N 軸 (state_transition) と B/A 軸 (compute_lmd_ghost_head) を別プロセスで独立に

## 前提条件

- ベースブランチ: `main` (現 HEAD: `220e01a`、PR #17 で `Funs.lean` が namespace 別に 4 分割済)
- 現ファイル構成 (PR #17 後):
  ```
  ConsensusLean4.lean                  -- root index
  ConsensusLean4/
  ├── Types.lean                       -- H256 / Checkpoint / Block / State 等
  ├── Funs.lean                        -- umbrella (4 サブモジュールを import するだけ)
  ├── Funs/
  │   ├── Types.lean                   -- types.* defs (hash_tree_root stub 等)
  │   ├── JustifiedSlots.lean          -- justified_slots.* defs
  │   ├── ForkChoice.lean              -- fork_choice.* (compute_lmd_ghost_head は :991)
  │   └── StateTransition.lean         -- state_transition.* (state_transition は :1356)
  ├── FunsExternal_Template.lean       -- Aeneas が再生成
  └── FunsExternal.lean                -- 5 axiom 置換先 (active)
  ```
- ツールチェイン: `leanprover/lean4:v4.28.0-rc1` (変更しない。必要になれば単独承認)
- Lean 依存: Aeneas @ `864eddb4876d0104802e0fd29bd453f67f48c4be` (既存 `lake-manifest.json`)
- 並存する open PR: #2 (feat/rust-ffi-poc), #3 (perf/fast-process-attestations) — どちらも参照するが lift & shift しない

## ブランチ

- 名前: `feat/ffi-benchmarks` (本ドキュメント自体がここに住む)
- base: `main` @ `220e01a`
- 状態: docs 2 本のみ既コミット、コードは未着手
- `FunsExternal.lean` の axiom 置換は必要最小限 (A5 方針、PR #2 との diff 衝突を最小化)

## 新規追加するファイルの配置 (PR #17 後の構成基準)

| 追加先 | 役割 | M |
|---|---|---|
| `ConsensusLean4/Ffi.lean` | 新規、top-level (Funs.lean と同階層)。`@[export csf_*]` wrapper 5 本 | M1 / M4 |
| `ConsensusLean4/FastPath.lean` | 新規、top-level。Array ベースの `stateTransitionFast` | M3 |
| `ConsensusLean4/FunsExternal.lean` | 既存編集、5 axiom 全置換 | M2 |
| `ConsensusLean4.lean` | 既存編集、`import ConsensusLean4.Ffi` を追加 | M1 |
| `rust-ffi/Cargo.toml` | 新規 crate (workspace ルートではなく単独 crate) | M1 |
| `rust-ffi/build.rs` | `.c.o.export` 動的スキャン + libleanshared dylib link | M1 |
| `rust-ffi/src/main.rs` | csf_ping smoke (M1)、後で 2 bench bin に分割 | M1 → M4 |
| `rust-ffi/src/lean_types.rs` | Aeneas 型対応 Rust struct | M4a |
| `rust-ffi/src/to_lean.rs` | `ToLean` trait + 各型 impl | M4a |
| `rust-ffi/src/ffi.rs` | extern 宣言 + 初期化 4 段階 helper | M4a |
| `rust-ffi/src/bin/bench-state-transition.rs` | N 軸 bench | M4b → M5 |
| `rust-ffi/src/bin/bench-fork-choice.rs` | B/A 軸 bench | M4b → M5 |

`Funs/` 配下と `Funs.lean` umbrella、`Types.lean`、`FunsExternal_Template.lean` は**触らない** (Aeneas 再生成領域)。

---

## マイルストーン

### M0: 準備

**Goal**: 環境の sanity 確認

- 現ブランチ `feat/ffi-benchmarks` HEAD が main にリベース済 (`d562753` がトップ、main の `220e01a` 直上) であることを確認
- `lake build` が警告ゼロで通ることを確認 (Funs.lean の namespace 別 4 分割後の最新構成で初回ビルド)
  - 初回は Aeneas / Mathlib のキャッシュ取得で 30 分〜1 時間 (R1)
- `.gitignore` に `rust-ffi/target/` を追加 (現状 `.lake/` `lake-packages/` `build/` の 3 行のみ、`feat/ffi-benchmarks` 既コミットで `rust-ffi/target/` が追加済)

**検証**:
- `lake build` 警告ゼロ
- `ls .lake/build/lib/` に `ConsensusLean4.olean` 等が生成されている
- `cat .gitignore | grep rust-ffi` がヒット

---

### M1: Smoke Stage 1 — `csf_ping`

**Goal**: FFI 境界の最小確認。Lean と Rust が繋がるかを一番小さい関数で検証。

**Lean 側**:
- `ConsensusLean4/Ffi.lean` (新規、~10 行、top-level に配置 = `Funs.lean` と同階層):
  ```lean
  set_option maxHeartbeats 1000000
  @[export csf_ping] def csfPing (n : UInt64) : UInt64 := n + 1
  ```
- `ConsensusLean4.lean` root に `import ConsensusLean4.Ffi` を追加 (現状 3 import → 4 import)
- `lakefile.lean` は **9 行のままで OK**。`globs := #[.submodules \`ConsensusLean4]` は不要 (Lean モジュールは root の `import` で transitive に拾われる)。`precompileModules` は設定しない (default false、Issue #5509 回避)

**Rust 側**:
- `rust-ffi/Cargo.toml` (新規)
- `rust-ffi/build.rs` (新規):
  - `.c.o.export` 再帰スキャン、`Cache` / `LongestPole` / `Shake` 除外
  - `elan which lean` で toolchain `lib/lean/` 解決
  - `leanshared` / `Init_shared` / `stdc++` / `gmp` dylib link
  - RPATH 埋め込み
  - 冒頭で `Command::new("lake").arg("build").current_dir("..")` を invoke (A22)
  - `rerun-if-changed` 対象: `build.rs` / `../ConsensusLean4/` (dir 全体、新サブディレクトリ `Funs/` も自動カバー) / `../lakefile.lean` / `../lean-toolchain` / `../lake-manifest.json` (A21)
- `rust-ffi/src/main.rs` (新規、~40 行):
  - extern block: `csf_ping`, `lean_initialize_runtime_module`, `lean_initialize`, `initialize_consensus_x2dlean4_ConsensusLean4_Ffi`, `lean_io_mark_end_initialization`
  - 初期化 4 段階 (A26)
  - `assert_eq!(csf_ping(41), 42)`

**検証**:
- `lake build` 成功 (再ビルドは差分のみで秒オーダー)
- `nm .lake/build/ir/ConsensusLean4/Ffi.c.o.export | grep csf_ping` で symbol 可視
- `cd rust-ffi && cargo run --release` が exit 0

---

### M2: FunsExternal axiom 置換 (M3 の hard prereq)

**Goal**: 5 axiom 全置換 (A20)

**対象** (`ConsensusLean4/FunsExternal.lean` を編集):
| axiom 名 (実名) | 用途 |
|---|---|
| `core.cmp.Ordering.Insts.CoreCmpPartialEqOrdering.eq` | sort/比較 (compute_block_weights 内) |
| `core.result.Result.Insts.CoreOpsTry_traitTryTResultInfallibleE.branch` | Aeneas `?` 演算子の脱糖、state_transition 全体で頻用 |
| `core.result.Result.Insts.CoreOpsTry_traitFromResidualResultInfallibleE.from_residual` | 同上、エラー値の伝播パス |
| `alloc.vec.Vec.clear` | `shift_window` (justified_slots) で要 |
| `alloc.vec.Vec.is_empty` | `compute_lmd_ghost_head` の入口チェック |

**実装方針**:
- いずれも数行で書ける (例: `Vec.clear v := ok ⟨[], by simp⟩`、`Vec.is_empty v := ok v.val.isEmpty`)
- PR #2 の実装は参照のみ、コードはゼロから
- 動作確認: 各 axiom 置換後に `lake build` が引き続き通ることを確認

**検証**:
- `lake build` 警告ゼロ
- `#eval` で簡単な動作確認 (FunsExternal.lean に `#eval` 文を一時追加して通すだけ、確認後削除)

---

### M3: handwritten fast path

**Goal**: state_transition を Array ベースの e2e pipeline として手書き実装

**ファイル**: `ConsensusLean4/FastPath.lean` (新規、top-level、~250 行、`Funs.lean` と同階層)

**冒頭**:
```lean
import ConsensusLean4.Funs   -- umbrella 経由で 4 サブモジュールを取得
import ConsensusLean4.Types
set_option maxHeartbeats 1000000   -- A19
```

**実装内容**:
- `ofVec` / `toVec`: `alloc.vec.Vec α ↔ Array α` コンバータ
- `isValidVoteFast`: aggregation_bits を Array で線形スキャン
- `processSingleAttestationFast`: 1 attestation を Array ベースで処理
- `processAttestationsFast`: attestation ループを Array で回す (O(A·V))
- `processBlockFast`:
  - `state_transition.process_block_header` (Aeneas 版、現在 `Funs/StateTransition.lean` 内) を呼ぶ
  - `processAttestationsFast` を呼ぶ
- `stateTransitionFast`:
  - `state_transition.process_slots` (Aeneas 版、`Funs/StateTransition.lean` 内) を呼ぶ
  - `processBlockFast` を呼ぶ
  - `types.hash_tree_root_state` (`Funs/Types.lean` 内、ZERO stub のまま、C2) で照合

アルゴリズムは PR #3 を参照するが**コードはゼロから書き直し**。

**検証**:
- `lake build` 成功
- `#eval stateTransitionFast <minimal_state> <minimal_block>` が `.ok (.Ok (), _)` を返す
- (任意) `#eval` テスト用の補助モジュールを別ファイルにせず FastPath.lean 末尾に置いて確認後削除

---

### M4: Smoke Stage 2+3 — 2 エントリポイント e2e FFI

**Goal**: Rust から 1 FFI コールで両エントリポイントを呼ぶ

#### M4a: Rust 側 marshal 実装

- `rust-ffi/src/lean_types.rs` (新規): Aeneas 生成 Lean type に対応する Rust struct
  - `H256` (= ByteArray32 + 命題なので `[u8; 32]` で十分)
  - `Validator`, `Checkpoint`, `AttestationData`, `AggregatedAttestation`, `Block`, `State`
  - `Vec<T>` の Rust 表現は `std::vec::Vec<T>`、Lean 側へは `to_lean` で wrap
- `rust-ffi/src/to_lean.rs` (新規):
  - `trait ToLean { fn to_lean(&self) -> *mut lean_object; }`
  - `lean_alloc_ctor` / `lean_box_uint64` / `lean_mk_string` 等の FFI 呼び出し
  - **List 構築 helper** (A24): `lean_list_nil()` / `lean_list_cons(head, tail)` / `list_from_iter`
  - **Vec wrap helper** (A23): `wrap_list_as_vec(list)` — Vec の ctor (tag 0, 2 obj fields) を組んで `property` に `lean_box(0)` を入れる、element type 非依存の 1 関数
- `rust-ffi/src/ffi.rs` (新規):
  - extern 宣言: `csf_state_transition`, `csf_state_transition_noop`, `csf_compute_lmd_ghost_head`, `csf_compute_lmd_ghost_head_noop` (+ 既存 `csf_ping`)
  - 初期化 4 段階 helper (M1 の main.rs から関数化)

#### M4b: Lean 側 wrapper 実装

`ConsensusLean4/Ffi.lean` を拡張:

```lean
import ConsensusLean4.FastPath
import ConsensusLean4.Funs        -- compute_lmd_ghost_head のため
import ConsensusLean4.Types
open ethlambda_verification

set_option maxHeartbeats 1000000

-- M1 の csfPing は残す

@[inline] private def packPipeline {α : Type}
    (r : Aeneas.Std.Result (core.result.Result Unit α × types.State)) : UInt8 :=
  match r with
  | .ok (.Ok _, _)   => 0
  | .ok (.Err _, _)  => 1
  | .fail _          => 2
  | .div             => 3   -- A28 / P24 の 4 分岐パターン

@[export csf_state_transition]
def csfStateTransition (state : types.State) (block : types.Block) : UInt8 :=
  packPipeline (stateTransitionFast state block)

@[export csf_state_transition_noop]
def csfStateTransitionNoop (_state : types.State) (_block : types.Block) : UInt8 := 0

@[export csf_compute_lmd_ghost_head]
def csfComputeLmdGhostHead
    (start_root : types.H256)
    (blocks : Aeneas.Std.alloc.vec.Vec (types.H256 × (Aeneas.Std.U64 × types.H256)))
    (attestations : Aeneas.Std.alloc.vec.Vec (Aeneas.Std.U64 × types.AttestationData))
    (min_score : Aeneas.Std.U64) : UInt8 :=
  match fork_choice.compute_lmd_ghost_head start_root blocks attestations min_score with
  | .ok _   => 0
  | .fail _ => 2
  | .div    => 3

@[export csf_compute_lmd_ghost_head_noop]
def csfComputeLmdGhostHeadNoop
    (_start_root : types.H256)
    (_blocks : Aeneas.Std.alloc.vec.Vec (types.H256 × (Aeneas.Std.U64 × types.H256)))
    (_attestations : Aeneas.Std.alloc.vec.Vec (Aeneas.Std.U64 × types.AttestationData))
    (_min_score : Aeneas.Std.U64) : UInt8 := 0
```

- 初期化関数シンボル名 (`initialize_consensus_x2dlean4_ConsensusLean4_Ffi`) を `nm` で確認、Rust 側 extern 宣言と一致
- `compute_lmd_ghost_head` は `Funs/ForkChoice.lean:991` から transitive import 経由で取得
- `state_transition.*` は `Funs/StateTransition.lean` から、umbrella `Funs.lean` 経由

#### M4c: Smoke Stage 2 + 3

- `rust-ffi/src/bin/bench-state-transition.rs` (新規):
  - 最小入力 (V=2, A=1) を構築 → ToLean で marshal → `csf_state_transition` を呼ぶ → 戻り値 0 を assert
  - 不正入力 (block.slot を壊す) で 1 (domain err) が返ることを assert
  - `--smoke` モードで実行
- `rust-ffi/src/bin/bench-fork-choice.rs` (新規):
  - 最小入力 (B=3, A=2) を構築 → marshal → `csf_compute_lmd_ghost_head` → 戻り値 0
  - blocks=[] (空) で `start_root` 素通しケースも確認

**検証**:
- Smoke Stage 2: `cargo run --release --bin bench-state-transition -- --smoke` が exit 0
- Smoke Stage 3: `cargo run --release --bin bench-fork-choice -- --smoke` が exit 0
- 不正入力で Err sentinel が返り、runtime panic なし

---

### M5: ベンチ本走行 + ドキュメント

**実行環境**: ローカル (Linux 6.18+kali、CPU governor performance、`taskset -c <core>` でピン止め)

**Goal**: 計画したスケール階段で実測、結果を docs に集計

> 判定基準: [`docs/timing-budget.md`](./timing-budget.md) を参照。pass/fail は project SLO target (state_transition < 200ms / fork choice < 100ms) を主基準、outer limit (< 800ms) を補助列として使う。

- **state_transition**: N ∈ {100, 1K, 10K, 100K}, A=64, 5 試行ずつ (N=1M は 1 試行参考値)
- **compute_lmd_ghost_head**: (B, A) ∈ {100, 1K, 10K} × {32, 128}, 5 試行ずつ
- 各 cell 別プロセスで実行 (`ru_maxrss` 分離、A10 方針)
- 計測結果を `docs/rust-ffi-benchmarks.md` (新規) に集計
  - 時間: 中央値 + IQR
  - メモリ: `ru_maxrss` 差分
  - 外挿セル / 実測セルを明示 (A4 方針)
  - "crypto cost excluded" の注記 (A3、`hash_tree_root` stub 起因)
- `README.md` に再現手順を 3 ステップで記載: `elan which lean` / `lake build` / `cargo run --release --bin ...`

**検証**: `docs/rust-ffi-benchmarks.md` に完成表、README に再現コマンド記載

---

## 進捗報告

**工数見積もりはしない** (A11)。M0 → M1 → **M2 (hard prereq)** → M3 → M4 → M5 の順に進め、各 M 完了時点でユーザーに進捗報告。想定外の時間がかかる箇所 (R1–R5) があれば発生時点で報告・相談。

## リスクと対応

| # | リスク | 発生時対応 |
|---|---|---|
| R1 | `lake update` での Mathlib 取得が遅い | 初回のみ (30 分–1 時間)、以降はキャッシュ。M0 のバッファに含む |
| R2 | `libleanshared.so` が見つからない (elan 未インストール等) | README に前提明記。`LEAN_LIB_DIR` env override を build.rs に追加 |
| R3 | ToLean marshaling で Lean object 構築に失敗 (Aeneas 型形状ミスマッチ) | M4 smoke が落ちる。V=2 の最小入力から増やして特定 |
| R4 | N=1M で OOM | `ru_maxrss` 監視、異常値なら N=100K で打ち切り、結果に注記 |
| R5 | Lean v4.28.0-rc1 固有のバグが発覚 | toolchain 変更は**単独承認を取る** (計画承認に含めない、C11 方針) |
| R6 | (新規) Funs.lean 4 分割後の transitive import 不備で `compute_lmd_ghost_head` が見えない | `import ConsensusLean4.Funs` を Ffi.lean に明示。Funs.lean umbrella が 4 サブを再 export しているので解決するはず |

## ロールバック方針

- M0–M5 各段階で commit を切り、失敗時は前段階まで `git reset --soft` で戻せる状態を維持
- feature branch は main に直接 push しない。完了時に PR 化してレビュー
- 万一 main を壊す変更をした場合は `git revert` で取り消し (`git push --force` は使わない)

## 非スコープ (本タスクでやらないもの)

- SSZ encoding/decoding (issue #4)
- `hash_tree_root_*` real 実装 (issue #5)
- `compute_lmd_ghost_head_fast` (A7、mainnet 級 B=32K の追加 fast path)
- BLS 署名検証
- `lean-toolchain` のアップグレード
- PR #2 / PR #3 の close / merge 判断 (完了後にユーザーが判断)
- `Funs/{Types,JustifiedSlots,ForkChoice,StateTransition}.lean` の編集 (Aeneas 再生成領域)
- `Funs.lean` umbrella の編集 (4 import のままで触らない)

## 承認後の実行順

1. 本計画をユーザーが承認
2. 既に切ってある `feat/ffi-benchmarks` ブランチで作業継続 (現状 docs 2 本のみ、`220e01a` 直上)
3. M0 → M1 → **M2 (hard prereq、A20)** → M3 → M4 → M5 の順に実装、各 M 完了時にユーザーに進捗報告
4. M5 完了後に **M0–M5 をまとめた 1 本の PR** を作成、レビュー待ち

## 2026-04-30 更新事項

PR #17 (Funs.lean → Funs/{Types,JustifiedSlots,ForkChoice,StateTransition}.lean に分割) が main にマージされたことを反映:

- 前提条件 main HEAD: `177fd38` → `220e01a`
- 行番号参照: `Funs.lean:2693-2725` → `Funs/StateTransition.lean:1356`、`Funs.lean:1104-1154` → `Funs/ForkChoice.lean:991`
- `lakefile.lean` の `globs := #[.submodules \`ConsensusLean4]` は**不要**と確定 (現 9 行構成で transitive import が動く)
- M3 / M4 で参照する関数のファイル所在を明記 (process_slots / process_block_header / hash_tree_root_state は `Funs/StateTransition.lean` または `Funs/Types.lean`)
- Funs/ サブディレクトリと umbrella `Funs.lean` は触らない (非スコープに追加)
- R6 を新規追加: 4 分割後の transitive import 不備リスク

## 2026-04-24 決定事項

### 実装計画レベル (A11–A14)

- **A11**: 工数見積もりはしない。M 完了毎に進捗報告
- **A12 (更新、A20 で上書き)**: 旧「axiom 置換は遅延」。→ **A20 により M2 は M3 の hard prereq、5 axiom 全部置換**
- **A13**: ベンチはローカル環境で実行 (CPU governor performance + taskset 推奨)
- **A14**: M0–M5 を 1 本の PR にまとめる (`feat/ffi-benchmarks` → `main`)

### 設計判断レベル (A15–A28)

詳細は [`docs/ffi-feasibility.md` §8](./ffi-feasibility.md) を参照。本実装計画に影響する項目の要約:

- **A15**: Bench ループは Option A (毎 iter で state/block を新規 alloc、FBIP fast path を踏む)
- **A16**: `csf_state_transition` 戻り値は UInt8 sentinel (0=ok, 1=domain err, 2=panic, 3=div)、新 State は破棄
- **A17**: Rust 側に `lean_object*` の RAII / dec_ref 規律は不要 (Option A では Lean が consume)
- **A18**: ベンチ出力形式は人間可読 Markdown 表を stdout へ、`tee` でログ保存、手で docs に貼る
- **A19**: `FastPath.lean` / `Ffi.lean` 冒頭に `set_option maxHeartbeats 1000000`
- **A20**: M2 (FunsExternal 5 axiom 全部置換) を M3 の hard prereq に昇格
- **A21**: build.rs が `../ConsensusLean4/` dir + lakefile/lean-toolchain/lake-manifest を watch
- **A22**: build.rs 冒頭で `lake build` を自動 invoke
- **A23**: Marshal.lean は作らない。Rust が Vec の ctor layout を直接組む (proof irrelevance により property = lean_box(0))
- **A24**: Rust 側 `lean_list_nil` / `lean_list_cons` / `list_from_iter` で List 構築
- **A25**: FFI 境界の所有権規約は owned / single-use、`lean_inc`/`lean_dec` は Rust 側で呼ばない
- **A26**: モジュール初期化は top-level (`initialize_consensus_x2dlean4_ConsensusLean4_Ffi`) 1 本のみ、transitive は Lean runtime に任せる
- **A27**: `*_noop` twin は入力を consume して UInt8=0 で即 return、paired-delta で pipeline 純粋時間を抽出
- **A28**: PR #2 パターンを踏襲する informational 項目 — Result 2 重マッチ / `@[inline]` / 11 IR ディレクトリ走査

## future work (本タスク外、issue で追跡)

- [issue #4](https://github.com/NyxFoundation/consensus-lean4/issues/4): Option III (SSZ バイト列 FFI) 移行
- [issue #5](https://github.com/NyxFoundation/consensus-lean4/issues/5): `hash_tree_root_*` real 実装
- [issue #6](https://github.com/NyxFoundation/consensus-lean4/issues/6): realistic block-chaining benchmark (state chaining)
