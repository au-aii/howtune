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
  // 表示用: 0.5s バケットの intensity（ダウンサンプル, NFR-Volume-1）
  "intensity": [ { "t": 44.0, "v": 0.82 }, { "t": 44.5, "v": 0.77 }, … ],
  // 検出済み反応区間サマリ（ReactionEvent 由来。タグは multi-label・排他でない）
  "events": [
    { "start": 44.0, "end": 50.0,
      "tags": ["groove","hit"],        // multi-label
      "arousal": 0.8, "valence": 0.1,  // 次元（valence は低確信）
      "confidence": { "arousal": 0.9, "valence": 0.35 },
      "hr_trend": "rising" }
  ],
  // --- ML 用（P-b 以降・任意）---
  "self_report": { "tags": ["groove","hit"] },  // 弱教師＝ユーザーが選んだ How タグ
  "hr": [ { "t": 44.0, "bpm": 96 }, … ],         // 補助 arousal 信号
  "motion_features": "P-ML 層でのみ保存（後述・生全点は保存しない）"
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

## タグの再定義（生理接地・ML 前提）

精査（requirements.md「生理学的接地と ML 前提」）を反映し、7タグを**直交クラスと見なさず、3層＋確信度**で扱う：

- **実測層（高確信・センサーに情報あり）**: `arousal`(量) / `groove`(拍同期) / `hit`(スパイク)。頭部モーションで直接。
- **推定層（低確信・多モーダル/文脈で補完）**: `valence`(快↔悲) / `immersion` / `afterglow`(=hit 後のフェーズ)。motion 単独では弱く、HR・音響・コメントで補う。
- **追加候補**: `frisson`（測れれば旗艦。要 EDA 等の追加センサー・別 ADR）。

保存は single-tag ではなく **multi-label タグ ＋ arousal/valence の連続値 ＋ 確信度**。UI/集計では確信度を正直に表示する。

## 学習データ要件（ML flywheel）

ML で反応推定を伸ばすには、**入力特徴と教師ラベルを対にして蓄積**する（信号に無い情報は学習で作れない）。

- **教師ラベル（弱教師）**: ユーザーが選んだ How タグ（`self_report.tags`）＋任意で arousal/valence の自己申告。
- **入力特徴**: motion（`interactionIntensity` 時系列＋P-ML で `userAcceleration`/`rotationRate`/`attitude` の**特徴量**＝周期性・スペクトル・分散等。生全点は保存しない）／補助 HR（arousal）／音響特徴（テンポ・オンセット等、曲側）／コメント文（valence の弱教師）。
- **個人化**: `user_id` 単位でモデル校正（frisson/groove 感受性の個人差）。B2B へは集計後の匿名値のみ（生特徴は本人スコープ）。
- **flywheel**: 蓄積 → 学習（`OthelloActivityClassifier` を 3状態 → multi-label＋次元回帰＋時系列へ拡張）→ 推定改善 → 体験改善 → さらに蓄積。
- **出発点**: 既存 `OthelloActivityClassifier`（Create ML・groove/chill/neutral）を土台に拡張。

## 段階案

- **P-a（最小・moat 着火）**: `reaction_sessions` に `events`（multi-label タグ）＋ `self_report.tags`（弱教師ラベル）を保存 → 密度を「実反応区間」に。**ラベルを最初から貯める**のが後の ML の生命線（スキーマは小さい）。
- **P-b**: intensity 0.5s ダウンサンプル＋HR 系列を追加 → How カード非依存の連続密度＋arousal 信号。
- **P-ML（学習）**: 頭部モーション特徴を蓄積し、`OthelloActivityClassifier` を **multi-label＋arousal/valence 回帰＋時系列**へ拡張。個人化。
- **P-c（North Star）**: 学習した表現を「雰囲気レコメンド」の特徴量に接続。

推奨は **P-a を先に**（スキーマ最小・プライバシー審査が軽い・すぐ密度が本物になる。ラベルも同時に貯め始める）。

## テスト戦略

- Functions: エミュレータで `reaction_sessions` 書き込み→`song_insights` 再集計を確認。
- iOS: `xcodebuild` green ＋ 1 セッションが 0.5s バケットで数 KB に収まることを確認。
- プライバシー: rules テストで他人の `reaction_sessions` が read 不可を確認。

## 未決（ユーザー判断待ち → requirements.md「オープンな設計判断」参照）

- 保存粒度（P-a/P-b/P-c のどこから）、同意モデル（opt-in/out）、B2B 二次利用範囲。
