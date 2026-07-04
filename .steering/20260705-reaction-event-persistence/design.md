# 設計書 — 生 ReactionEvent / モーションの永続化

## アーキテクチャ概要

「収集=iOS / 集計=Functions / 閲覧=Web」の責務分離（ADR-0007）を崩さず、**反応セッション**という新しい保存単位を足す。生モーション全点は保存せず、**曲時間に沿ってダウンサンプルした intensity 列 + 検出済み ReactionEvent サマリ**を 1 曲 = 1 セッションドキュメントで書く。B2B へは必ず Functions 集計・匿名化を経由する。

```
AirPodsMotionSample（毎サンプル, on-device）
   └─ interactionIntensity を曲時間 0.5s バケットに集約（ダウンサンプル）
      └─ 曲終了/停止時に ReactionEvent[] と共に1ドキュメントへバッチ書き込み
         └─ reaction_sessions/{sessionId}（本人のみ read）
            └─ onWrite トリガーで song_insights を「実反応」で再集計（k=5 匿名）
```

## データモデル（Firestore）

### 新規: `reaction_sessions/{sessionId}`（本人のみ read、書き込みは Functions 経由 or rules で本人）

```jsonc
{
  "user_id": "…",                 // 本人。B2B には絶対に出さない
  "song_id": "…", "song_title": "…", "artist_id": "…",
  "recorded_at": Timestamp,
  "duration_sec": 213.4,
  "consent_version": "v1",        // 同意バージョン（NFR-Privacy-2）
  // 生全点ではなくダウンサンプル（NFR-Volume-1）: 0.5s バケットの intensity
  "intensity": [ { "t": 44.0, "v": 0.82 }, { "t": 44.5, "v": 0.77 }, … ],
  // 検出済み反応区間サマリ（ReactionEvent 由来）
  "events": [
    { "start": 44.0, "end": 50.0, "intensity": 0.9, "tags": ["groove"], "hr_trend": "rising" }
  ]
}
```

- `intensity` は `AirPodsMotionSample.interactionIntensity` を **0.5s バケットで平均/最大**した軽量列（生 `userAcceleration`/`rotationRate`/`attitude` の全点は保存しない）。
- `events` は `Models/ReactionEvent.swift` の `startTime/endTime/intensity/tags/heartRateTrend` を写像（`score` 内訳は将来必要になったら追加）。
- **1ドキュメント/曲**でまとめる（サブコレクション大量ドキュメントを避け、読み書き・コスト・プライバシー削除を単純化）。

### 既存 `song_insights/{songId}` の精緻化

`functions/repositories/insights.js` の `recomputeSongInsights` を拡張し、密度を「How カード区間の重なり」ではなく **`reaction_sessions.intensity` の合算**から出す。k=5 匿名（`user_id` を含めない・5人未満バケット非表示）は不変。How カードしか無い曲は現行ロジックにフォールバック（後方互換）。

## データフロー / 書き込み経路

1. 再生中: `AirPodsMotionManager` → `AirPodsMotionSample` を既存どおり取得。
2. `ReactionDetectionViewModel` が既存どおり `ReactionEvent` を検出。**加えて** intensity を 0.5s バケットへ集約（新規の軽量バッファ）。
3. 曲終了/停止時（`ContentView.onChange(nowPlayingContext)` で `airPods.stop()` する箇所）に、同意があれば `reaction_sessions` を **1回バッチ書き込み**（NFR-Battery-1）。書き込みは既存の Functions 経由（ADR-0002）を第一候補、rules で本人書き込み許可を第二候補。
4. `onReactionSessionWritten` トリガー（`onHowCardWritten` と同型の v1 Firestore トリガー）で `recomputeSongInsights(song_id)`。

## プライバシー設計（最重要）

- `reaction_sessions` は `firestore.rules` で **`allow read: if request.auth.uid == resource.data.user_id`（本人のみ）**、B2B は集計済み `song_insights` だけ。
- 同意: オンボーディングの motion 許可とは別に「反応データ蓄積」への明示同意画面を追加し `consent_version` を記録。未同意なら書き込みしない。
- 削除: 本人が設定画面（`SettingsView`）から自分の `reaction_sessions` を一括削除できる導線（将来）。
- 生の姿勢(attitude)・加速度全点は保存しない（再識別リスク・データ量の低減）。

## 段階案

- **P-a（最小・moat 着火）**: `reaction_sessions` に `events` のみ保存 → 密度を「実反応区間」に。intensity 列は未保存。
- **P-b**: intensity 0.5s ダウンサンプルを追加 → How カード非依存の連続密度。
- **P-c（学習素材）**: 集計を雰囲気レコメンドの特徴量に接続（North Star）。

推奨は **P-a を先に**（スキーマ最小・プライバシー審査が軽い・すぐ密度が本物になる）。

## テスト戦略

- Functions: エミュレータで `reaction_sessions` 書き込み→`song_insights` 再集計を確認。
- iOS: `xcodebuild` green ＋ 1 セッションが 0.5s バケットで数 KB に収まることを確認。
- プライバシー: rules テストで他人の `reaction_sessions` が read 不可を確認。

## 未決（ユーザー判断待ち → requirements.md「オープンな設計判断」参照）

- 保存粒度（P-a/P-b/P-c のどこから）、同意モデル（opt-in/out）、B2B 二次利用範囲。
