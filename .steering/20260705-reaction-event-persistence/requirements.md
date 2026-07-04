# 要件定義書 — 生 ReactionEvent / モーションの永続化（moat の燃料）

関連: [issue #112] / `docs/vision.md`（North Star・moat）/ ADR-0003（ルールベース→フライホイール）

## 背景・課題（実コードで裏取り済み）

HowTune の moat は「低レイヤーの反応データ（頭部モーション・生理・エンゲージメント）」の蓄積とフライホイール（`docs/vision.md`）。しかし現状、その**核心データが永続化されていない**。

実装の実態:

- `Features/AirPodsMotion/Models/AirPodsMotionSample.swift`: `userAcceleration` / `rotationRate` / `attitude` / `playbackTime` / 導出 `interactionIntensity` を **on-device で毎サンプル生成**。
- `Features/ReactionDetection/ViewModels/ReactionDetectionViewModel.swift`: そのモーションから反応を検出し `Models/ReactionEvent.swift`（`startTime`/`endTime`/`intensity`/`tags`/`score`/`heartRateTrend`）を組み立てる。
- `ViewModels/ClipCreationViewModel.swift` の `createHowCard` が Firestore へ送るのは **How カード（comment・song_start/end・tags）だけ**。
- ⇒ **生モーション列と ReactionEvent（intensity 時系列・score 内訳）は破棄**され、Firestore の `song_insights` は「How カード区間の重なり」という粗い近似で密度を出しているに過ぎない。

## 目的・ゴール

- 生の反応シグナル（モーション由来の intensity 時系列 / ReactionEvent）を**プライバシーを守りつつ蓄積**し、
  - 「本物の反応密度」（How カード有無に依らない、実際に体が動いた瞬間）で `song_insights` を精緻化、
  - 将来の「雰囲気レコメンド」「ホルモン/低レイヤー分解」（North Star）の学習素材にする。

## スコープ

### In

- `ReactionEvent`（検出済み区間サマリ）の Firestore 永続化スキーマと書き込み経路の設計。
- モーション由来 `interactionIntensity` の**ダウンサンプリング時系列**（生 CMDeviceMotion 全点ではなく、曲時間に沿った軽量サマリ）の保存設計。
- プライバシー（匿名化・同意・データ量・保持期間）の設計。
- 既存 `song_insights` 集計をこの新データに接続する段階案。

### Out（この steering では扱わない）

- 実装そのもの（本 steering は設計まで。実装は別 tasklist で着手）。
- 生 CMDeviceMotion の全点ロー保存（データ量・電池・プライバシーが過大 → 却下方針）。
- 心拍/生理の新規センサー追加（既存 `heartRateTrend` の範囲に留める。ADR-0005 参照）。

## 機能要件

- FR-1: 反応記録セッション（1 曲の再生中）ごとに、ReactionEvent 群と intensity ダウンサンプル列を 1 ドキュメントで保存できる。
- FR-2: 保存単位に `song_id` / `user_id` / `playbackTime` 基準の時刻を持ち、`song_insights` 集計が「How カード」ではなく「実反応」を密度に使える。
- FR-3: 既存 How カード作成フローと**疎結合**（How カードを作らなくても反応セッションは保存されうる／その逆も可）。

## 非機能要件（特に重要）

- NFR-Privacy-1: 生データは **本人のみ read**、B2B へは必ず Functions 集計・匿名化（k=5・`user_id` 除去）を経由（ADR-0007 の原則を踏襲）。
- NFR-Privacy-2: **明示同意**（オンボーディングの motion 許可とは別に「反応データの蓄積」への同意）と、保持期間・削除手段。
- NFR-Volume-1: 1 曲あたりの保存サイズを抑える（生全点ではなくバケット/ダウンサンプル）。目安: 数 KB/曲。
- NFR-Battery-1: バックグラウンド書き込みは曲終了時などにバッチ化し、再生体験・電池に影響しない。

## 受け入れ基準

- スキーマ・書き込み経路・プライバシー・段階案が design.md に、実装単位が tasklist.md に落ちている。
- 設計上の未決事項（下記）がユーザー判断待ちとして明示されている。

## オープンな設計判断（ユーザー判断待ち）

1. **保存粒度**: ReactionEvent サマリのみ / +intensity ダウンサンプル / +姿勢(attitude) まで、のどこまで蓄積するか（moat 価値 vs データ量・プライバシー）。→ design.md に3案。
2. **同意モデル**: デフォルト on（オプトアウト）/ デフォルト off（オプトイン）。プライバシー訴求と蓄積速度のトレードオフ。
3. **B2B での二次利用範囲**: 集計密度の精緻化まで / 学習用データセット化まで。
