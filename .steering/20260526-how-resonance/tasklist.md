# タスクリスト: How Resonance

## 🚨 タスク完全完了の原則

全タスクが `[x]` になるまで継続。未完了を残して終了しない。

---

## フェーズ0: 準備

- [x] feat/how-chat-deepening から新ブランチ feat/how-resonance 作成
- [x] 最新 main をマージ（競合解決・ビルド通過）
- [x] steering ドキュメント作成（requirements/design/tasklist）
- [x] ADR 作成（Firestore 直リアルタイム購読の採用）→ ADR-0006

## フェーズ1: ピークモーション検出（FR-RES-01）

- [x] `PeakMoment` モデル作成
- [x] `PeakMotionTracker` 作成（samples → ピーク抽出の純関数）
- [x] `AirPodsMotionViewModel` に `peakMoment` 算出を追加（既存API不変）
- [x] ビルド確認

## フェーズ2: 1回目の決めうち問いかけ（FR-RES-02）

- [x] `HowResonancePromptBuilder` 作成（固定 question/choices）
- [x] ピーク地点の時刻フォーマット（`PeakMoment.formattedTime`）
- [x] ビルド確認

## フェーズ3: 2回目LLM深掘り接続（FR-RES-03）

- [x] 既存 HowChat の2ターン目が LLM（変更不要を確認）
- [x] 1回目固定文 → 2回目LLM の接続（`HowChatViewModel` に optional peak 追加、turn0 を決めうち化）

## フェーズ4: マッチング（FR-RES-04）

- [x] `ResonanceReactor` モデル作成
- [x] `ResonanceMatchService` 作成（Firestore how-cards 購読 + 同地点判定 `isSameSpot`）
- [x] ~~`ResonanceMatchViewModel` 作成~~（ObservableObject の Service を View で直接使用＝VM省略・下記振り返り参照）
- [x] `ResonanceMatchView` 作成（同地点🔥/別地点リスト）
- [x] ビルド確認

## フェーズ5: 共鳴演出（FR-RES-05）

- [x] `QuantumIgnitionView` 作成（Canvas/TimelineView: 量子→摩擦→発火）
- [x] `ResonanceVisualConfig`（richMode 切替）
- [x] マッチ出現時に演出再生 + 🔥（`onChange(sameSpotReactors)` で ignition トリガー）
- [x] ビルド確認

## フェーズ6: リアルタイムDM（FR-RES-06, 07）

- [x] `ResonanceMessage` モデル作成
- [x] `ResonanceChatService` 作成（messages 購読・楽観的送信）
- [x] ~~`ResonanceDMViewModel` 作成~~（Service を View で直接使用＝VM省略）
- [x] `ResonanceDMView` 作成（Apple ネイティブ調）
- [x] 🔥タップ → DM 遷移（`NavigationLink(value: reactor)`）
- [x] ビルド確認

## フェーズ7: Firestore rules + seed

- [x] Firestore rules に how-cards read / conversations read-write を追加
- [x] `functions/scripts/seed-resonance.js`（複数地点 how-cards + mock users）
- [x] seed 手順を docs に記載（data-model.md）

## フェーズ8: 最終確認・成果物

- [x] 全体ビルド通過（xcodebuild: BUILD SUCCEEDED）
- [x] AI_USAGE_LOG 追記
- [x] スライド作成（HTML + PPTX）
- [x] コミット・プッシュ

---

## 実装後の振り返り

### 実装完了日

2026-05-26

### 計画と実績の差分

**計画と異なった点**:

- `ResonanceMatchViewModel` / `ResonanceDMViewModel` を作らず、`ResonanceMatchService` / `ResonanceChatService` を `ObservableObject` として View から直接利用した。薄い VM ラッパーは boilerplate と監視（ネスト ObservableObject）問題を増やすだけだったため省略。
- `ResonanceChatService` は当初 failable init だったが、`@StateObject` でネスト ObservableObject が監視されない問題があり、非 failable init に変更して View で直接 `@StateObject` 化した。
- マッチングは新規コレクションを作らず、既存 `how-cards` を `song_id` で購読する方式に集約（書き込みは Functions 経由のまま、ADR-0006）。
- デモ song_id は `ResonanceDemo.songId` 定数に固定。実曲との紐づけは投稿時 song_id を合わせる将来課題。

**新たに必要になったタスク**:

- `import Combine` 追加（@Published 利用）
- `ResonanceReactor` の `Hashable` 準拠（NavigationLink value）
- 最新 main の再マージ・競合解決（HowChatViewModel sessionID / AI_USAGE_LOG）

### 学んだこと

- SwiftUI で failable init の Service を `@StateObject` にできないため、Service は非 failable にして内部で nil ハンドリングするのが素直。
- Canvas + TimelineView + 決定的乱数で、Metal 非依存でも十分リッチな粒子→発火演出が作れる（headless でビルド確認のみ可、見た目は実機確認）。
- 既存を壊さない接続は「optional 引数 + デフォルト nil」が有効（HowChat の peak、HowCard の songId）。

### 次回への改善提案

- 実曲 song_id をマッチングに通すため、ReactionEvent / 再生中トラックの song_id を HowChat→HowCard→Resonance まで伝播させる。
- 演出のリッチ版を Metal（既存 MetalWaveformRenderer 資産）へ寄せて品質を上げる。
- DM の既読・通知・会話一覧（presence）を追加。

---

## Phase 1 後処理（2026-06-30）

- [x] T1+T2: README 個人化（ハッカソン固有セクション削除・個人継続プロジェクトバナー追加・Firebase 切り替え手順追加）
- [x] T3: QuantumIgnitionView 待機ループ改善（`pulseEpoch` + `.task` で `cycleDuration` ごとにリセット）
- [x] T4: LyricHowCardComposerView に Resonance 導線追加（`resonanceButton` + `fullScreenCover`）
- [x] T6: functions/README.md にシードスクリプト手順追記
- [x] ビルド確認（BUILD SUCCEEDED）
