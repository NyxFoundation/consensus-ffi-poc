---
title: 実運用 timing 予算リファレンス
last_updated: 2026-05-05
tags:
  - timing
  - budget
  - benchmark
  - leanspec
---

# 実運用 timing 予算リファレンス

## 目的

M5 ベンチ ([`docs/ffi-implementation-plan.md`](./ffi-implementation-plan.md) §M5) の結果を「実運用で許容される実行時間」と照らし合わせて評価するための基準値を 1 箇所に集める。

**本 doc は基準値の保管庫**。M5 ベンチの実測値を埋めた表は、M5 完了時に作成される `docs/rust-ffi-benchmarks.md` 側に置く。本 doc には判定列のテンプレ形と判定式のみを示し、実測値はコピーしない (drift 防止)。

## 出典の固定 (commit-pinned + line-anchored)

外部 spec の数値は `https://github.com/<org>/<repo>/blob/<commit-SHA>/<path>#L<line>` 形式で引用。SHA 取得時点 2026-05-05:

- **leanSpec**: `941abe7ba6d7ea81b5e0beb2eb6b7d4b8fcd08b8` (main)
- **ethereum/consensus-specs**: `5e5abe333f9d03eca5bd0c756827123e61388cd6` (master)

将来 spec が更新されても、本 doc の数値は当該 SHA 時点で固定される。本 doc の `last_updated` を更新する際は SHA も併せて更新する。

## 1. leanSpec spec 定数 (本プロジェクトが formalize する仕様)

出典: [`leanSpec@941abe7:src/lean_spec/subspecs/chain/config.py`](https://github.com/leanEthereum/leanSpec/blob/941abe7ba6d7ea81b5e0beb2eb6b7d4b8fcd08b8/src/lean_spec/subspecs/chain/config.py)

| 定数 | 値 | line |
|---|---:|---:|
| `SECONDS_PER_SLOT` | 4 | [L33](https://github.com/leanEthereum/leanSpec/blob/941abe7ba6d7ea81b5e0beb2eb6b7d4b8fcd08b8/src/lean_spec/subspecs/chain/config.py#L33) |
| `MILLISECONDS_PER_SLOT` | 4000 | [L36](https://github.com/leanEthereum/leanSpec/blob/941abe7ba6d7ea81b5e0beb2eb6b7d4b8fcd08b8/src/lean_spec/subspecs/chain/config.py#L36) |
| `INTERVALS_PER_SLOT` | 5 | [L20](https://github.com/leanEthereum/leanSpec/blob/941abe7ba6d7ea81b5e0beb2eb6b7d4b8fcd08b8/src/lean_spec/subspecs/chain/config.py#L20) |
| `MILLISECONDS_PER_INTERVAL` | 800 | [L39](https://github.com/leanEthereum/leanSpec/blob/941abe7ba6d7ea81b5e0beb2eb6b7d4b8fcd08b8/src/lean_spec/subspecs/chain/config.py#L39) |
| `GOSSIP_DISPARITY_INTERVALS` | 1 (~800ms) | [L23](https://github.com/leanEthereum/leanSpec/blob/941abe7ba6d7ea81b5e0beb2eb6b7d4b8fcd08b8/src/lean_spec/subspecs/chain/config.py#L23) |
| `JUSTIFICATION_LOOKBACK_SLOTS` | 3 | [L42](https://github.com/leanEthereum/leanSpec/blob/941abe7ba6d7ea81b5e0beb2eb6b7d4b8fcd08b8/src/lean_spec/subspecs/chain/config.py#L42) |
| `MAX_ATTESTATIONS_DATA` | 16 / block | [L56](https://github.com/leanEthereum/leanSpec/blob/941abe7ba6d7ea81b5e0beb2eb6b7d4b8fcd08b8/src/lean_spec/subspecs/chain/config.py#L56) |

## 2. Slot 内 schedule

出典: [`leanSpec@941abe7:src/lean_spec/forks/lstar/spec.py::tick_interval`](https://github.com/leanEthereum/leanSpec/blob/941abe7ba6d7ea81b5e0beb2eb6b7d4b8fcd08b8/src/lean_spec/forks/lstar/spec.py#L1664-L1693) (interval-based dispatch: [L1684-L1690](https://github.com/leanEthereum/leanSpec/blob/941abe7ba6d7ea81b5e0beb2eb6b7d4b8fcd08b8/src/lean_spec/forks/lstar/spec.py#L1684-L1690))

| Interval | t (ms) | アクション |
|---:|---:|---|
| 0 | 0–800 | block 受理 + (提案者なら) attestation 受理 |
| 1 | 800–1600 | block 伝播 + state_transition 適用 + validator が attestation 出力 |
| 2 | 1600–2400 | aggregate (集約者のみ) |
| 3 | 2400–3200 | `update_safe_target` (fork choice 実行) |
| 4 | 3200–4000 | accept_new_attestations |

`compute_lmd_ghost_head` は interval 境界毎 (interval 3 の `update_safe_target`) + on_block / on_attestation 着信毎に再実行される ([on_block at L1159](https://github.com/leanEthereum/leanSpec/blob/941abe7ba6d7ea81b5e0beb2eb6b7d4b8fcd08b8/src/lean_spec/forks/lstar/spec.py#L1159))。1 slot 内で最大 5 回以上の呼び出しが想定される。

## 3. Per-call 上限 (spec schedule から導出)

> **位置付け**: 本セクションの上限は spec で文字通り規定された閾値ではなく、§2 の interval 構造から**導出**される値。"absolute outer limit" として、これを超えれば spec の interval 構造が成立しないライン。pass/fail 判定の主基準ではなく、§4 の SLO target が破綻していないかを補助的に確認するための列として使う。

| エントリポイント | 上限 | 根拠 |
|---|---:|---|
| `state_transition` (= on_block hot path) | < 800 ms | block 到着後、validator が interval 1 (800–1600ms) 末までに attestation を出すには、handler 全体が 1 interval 以内に収束する必要 |
| `compute_lmd_ghost_head` | < 800 ms | 1 interval 内に fork choice + 他の処理 + イベントが同居するため、上限としては 1 interval が absolute outer limit。fork choice 単独で使い切れる枠ではない |

## 4. Per-call SLO target (プロジェクト判断、pass/fail 主基準)

> **位置付け**: 本セクションの target は spec で規定された値**ではない**。プロジェクトとして「interval 構造内の他処理 + イベント競合 + ジッター」を踏まえた運用マージン目安として設定。**M5 ベンチの pass/fail 判定の主基準はこちら**。target を超えるが §3 の outer limit には収まるセルは "marginal" 扱い。

| エントリポイント | target | 根拠 |
|---|---:|---|
| `state_transition` | < 200 ms | `GOSSIP_DISPARITY_INTERVALS = 1` (~800ms 許容スキュー) と、interval 1 内で attestation 提出までの余裕を確保することを考慮した運用マージン |
| `compute_lmd_ghost_head` | < 100 ms | 1 slot で 5+ 回呼ばれる前提で、各呼び出しが 1 interval (800ms) を圧迫しないようにするための運用マージン |

## 5. 判定基準の使い方

M5 で `docs/rust-ffi-benchmarks.md` を作成する際、各 (N) / (B, A) cell の中央値を以下の式で評価:

```
target_pass = (cell_median_ms < target_ms)
outer_pass  = (cell_median_ms < outer_limit_ms)
```

判定列の例:

- `target_pass = ✓`, `outer_pass = ✓` → **緑** (実運用域内)
- `target_pass = ✗`, `outer_pass = ✓` → **黄** (spec 上は成立、運用マージン不足)
- `target_pass = ✗`, `outer_pass = ✗` → **赤** (spec の interval 構造を破綻)

主基準は `target_pass`。`outer_pass` は補助列。

## 6. `compute_lmd_ghost_head` の計算量に関する注記

リポ内の権威的記述は [`ConsensusLean4/Ffi.lean#L61`](../ConsensusLean4/Ffi.lean#L61):

> "Direct passthrough to the Aeneas-generated fork choice (linear in attestations, quadratic in blocks)."

この記述は **`O(A + B²)`** とも **`O(A·B²)`** とも厳密に確定できない曖昧な表現。`docs/ffi-feasibility.md` §2.2 では `O(A·B²)` と書かれているが、形式的解析ではなく経験的外挿の根拠付け。

本 doc では:
- 計算量式は `Ffi.lean#L61` のコメントを authoritative として扱う
- 外挿時間の数値は **PR #3 fast 係数からの経験的外挿** (実測ではない) と位置付ける
- B 軸の経験値ベースで判定する (式から導かない)

## 7. 比較リファレンス: mainnet beacon chain (12s slot)

> **重要**: 本セクションの値は **illustrative only / non-normative**。本プロジェクトの ベンチ pass/fail 判定は §3 の outer limit と §4 の SLO target (= leanSpec) のみで行う。mainnet 値は「leanSpec 4s slot との桁感比較」のためだけに併記する。

出典: [`consensus-specs@5e5abe3:configs/mainnet.yaml`](https://github.com/ethereum/consensus-specs/blob/5e5abe333f9d03eca5bd0c756827123e61388cd6/configs/mainnet.yaml), [`presets/mainnet/phase0.yaml`](https://github.com/ethereum/consensus-specs/blob/5e5abe333f9d03eca5bd0c756827123e61388cd6/presets/mainnet/phase0.yaml)

| 定数 | 値 | line |
|---|---:|---:|
| `SLOT_DURATION_MS` | 12000 | [configs L68](https://github.com/ethereum/consensus-specs/blob/5e5abe333f9d03eca5bd0c756827123e61388cd6/configs/mainnet.yaml#L68) |
| `ATTESTATION_DUE_BPS` | 3333 (~33% → t=4s) | [configs L80](https://github.com/ethereum/consensus-specs/blob/5e5abe333f9d03eca5bd0c756827123e61388cd6/configs/mainnet.yaml#L80) |
| `AGGREGATE_DUE_BPS` | 6667 (~67% → t=8s) | [configs L82](https://github.com/ethereum/consensus-specs/blob/5e5abe333f9d03eca5bd0c756827123e61388cd6/configs/mainnet.yaml#L82) |
| `SLOTS_PER_EPOCH` | 32 | [phase0 L34](https://github.com/ethereum/consensus-specs/blob/5e5abe333f9d03eca5bd0c756827123e61388cd6/presets/mainnet/phase0.yaml#L34) |
| `MAX_ATTESTATIONS` | 128 / block (leanSpec の 8 倍) | [phase0 L79](https://github.com/ethereum/consensus-specs/blob/5e5abe333f9d03eca5bd0c756827123e61388cd6/presets/mainnet/phase0.yaml#L79) |
| `MAX_COMMITTEES_PER_SLOT` | 64 | [phase0 L6](https://github.com/ethereum/consensus-specs/blob/5e5abe333f9d03eca5bd0c756827123e61388cd6/presets/mainnet/phase0.yaml#L6) |

実クライアント実測 (公開コミュニティ値、illustrative only、SHA で pin 不可、本判定には使わない):

- `state_transition`: 通常 50–300 ms、epoch 境界で ~1s、4s 超過で missed attestation
- `compute_lmd_ghost_head` 相当 (LMD GHOST fork choice): 通常 1–50 ms

## 8. 3SF (Three-Slot Finality) の根拠

なぜ leanSpec は **slot=4s** で mainnet (12s) より厳しい timing を採用するか:

- 楽観 finality: `JUSTIFICATION_LOOKBACK_SLOTS × SECONDS_PER_SLOT` = 3 × 4 = **12 秒**
- 対比: mainnet は 3 epoch × 32 slots × 12s ≈ **19 分**
- → leanSpec は finality を 1/95 に圧縮するために短スロット設計を採用、よって per-call timing budget も厳しい

Justifiability rule: `delta ≤ 5` ∨ perfect square ∨ pronic (`delta = slot - finalized_slot`)
出典: [`ConsensusLean4/Funs/StateTransition.lean#L364-L391`](../ConsensusLean4/Funs/StateTransition.lean#L364-L391) (`state_transition.slot_is_justifiable_after`)

## 9. M5 ベンチ判定列のテンプレ形

> **重要**: 本セクションは**列定義のテンプレのみ**。実測値は M5 完了時に作成される `docs/rust-ffi-benchmarks.md` 側に埋める。本 doc には実測値をコピーしない (drift 防止)。

### `state_transition` 軸 (A=64 固定)

```
| N         | 種別          | 中央値 | IQR | 外挿 | outer (<800ms) | target (<200ms) | 判定 |
|----------:|---------------|-------:|----:|-----:|:--------------:|:---------------:|:----:|
| 100       | 実測 5 trials | …      | …   | ~1ms | …              | …               | …    |
| 1,000     | 実測 5 trials | …      | …   | ~10ms| …              | …               | …    |
| 10,000    | 実測 5 trials | …      | …   | ~100ms| …             | …               | …    |
| 100,000   | 実測 5 trials | …      | …   | ~1s  | …              | …               | …    |
| 1,000,000 | 参考 1 trial  | …      | n/a | ~10s | …              | …               | …    |
```

### `compute_lmd_ghost_head` 軸 (B × A、複雑度は §6 参照)

```
| B      | A   | 種別          | 中央値 | IQR | 外挿 | outer (<800ms) | target (<100ms) | 判定 |
|-------:|----:|---------------|-------:|----:|-----:|:--------------:|:---------------:|:----:|
| 100    | 32  | 実測 5 trials | …      | …   | ~100µs| …             | …               | …    |
| 100    | 128 | 実測 5 trials | …      | …   | ~100µs| …             | …               | …    |
| 1,000  | 32  | 実測 5 trials | …      | …   | ~10ms | …             | …               | …    |
| 1,000  | 128 | 実測 5 trials | …      | …   | ~10ms | …             | …               | …    |
| 10,000 | 32  | 実測 5 trials | …      | …   | ~1s   | …             | …               | …    |
| 10,000 | 128 | 実測 5 trials | …      | …   | ~1s   | …             | …               | …    |
```

判定式は §5 を参照。
