# タスクリスト — 生 ReactionEvent / モーションの永続化

> 本 steering は**設計まで**。実装は下記を承認後に別セッションで着手する。
> 未決事項（保存粒度・同意モデル・B2B 範囲）が確定してから P-a に入る。

## フェーズ 0: 設計（この steering）

- [x] 実データフローの裏取り（`AirPodsMotionSample` / `ReactionEvent` / `createHowCard`）
- [x] requirements.md（課題・要件・プライバシー・未決）
- [x] design.md（`reaction_sessions` スキーマ・書き込み経路・段階案）
- [x] 生理学的精査（frisson / groove / circumplex / 頭部モーション情動推定を文献裏取り）＋ ML 前提（multi-label・arousal/valence 回帰・時系列・多モーダル・個人化）を requirements/design に統合
- [x] **未決4点を確定（2026-07-05）**：①保存粒度=events＋ラベルのみ ②同意=opt-in(既定off) ③B2B=密度精緻化まで ④MLラベル=弱教師＋multi-label＋arousal/valence次元

## フェーズ P-a: 最小（events + 弱教師ラベル・moat 着火）

### バックエンド（実装・検証済み）

- [x] `firestore.rules` に `reaction_sessions/{id}`（本人のみ read、書き込みは Functions のみ）
- [x] Functions: `POST /reaction-sessions`（auth・`routes/reaction-sessions.js` ＋ `createReactionSession` repository。events multi-label タグ＋`self_report.tags` 弱教師ラベル）
- [x] Functions: `onReactionSessionWritten` トリガー（`onHowCardWritten` と同型）
- [x] Functions: `recomputeSongInsights` を how-cards ∪ reaction_sessions の**統合区間**に拡張（後方互換）。**本番データで E2E 検証済み**（反応セッション追加→reactor+1/groove+1→削除で復元）

### iOS（実装・ビルド検証済み）

- [x] iOS: `ContentView` で NowPlaying セッションに検出を束ねる（`reactionDetector.startSession()` / `airPods.latestSample` を `ingest` / 停止で `stopSession`）→ 曲停止時に `events` を `/reaction-sessions` へ POST（`FirebaseAPI.createReactionSession`）。**同意 opt-in（既定 off）チェック**付き
- [x] iOS: `SettingsView` に「反応データの蓄積に同意」トグル（`@AppStorage("reactionDataConsentV1")`）
- [x] iOS: `Services/ReactionSessionPayload.swift`＋`FirebaseAPI.createReactionSession`。`xcodebuild` BUILD SUCCEEDED

### 残り（フォローアップ・デプロイ・実機）→ [issue #9](https://github.com/au-aii/howtune/issues/9)

> デプロイは 2026-07-05 完了（本番トリガー稼働・検証済み）。以下は明日以降。

- [ ] **self_report ラベルの配線**（弱教師）: 現状 `self_report_tags` は空送信。セッション中にユーザーが選んだ How タグ（card 作成時の selectedTags 等）を集約して載せる
- [ ] デプロイ（ユーザー）: `firebase deploy --only functions,firestore:rules`（route・トリガー・rules を本番反映）
- [ ] 実機検証: AirPods 装着で `events` が実際に生成→送信されることを確認（Simulator はモーション無し）＋ rules で他人の reaction_sessions が read 不可

## フェーズ P-b: intensity ダウンサンプル

- [ ] iOS: `interactionIntensity` を 0.5s バケットに集約するバッファを `ReactionDetectionViewModel` に追加
- [ ] `reaction_sessions.intensity[]` を保存、集計を連続密度に
- [ ] 1 セッション数 KB に収まることを確認

## フェーズ P-ML: 反応推定モデルの拡張（学習）

- [ ] 頭部モーション特徴（周期性・スペクトル・分散等）を `reaction_sessions.motion_features` に蓄積
- [ ] `OthelloActivityClassifier` を 3状態 → **multi-label ＋ arousal/valence 回帰 ＋ 時系列**へ拡張
- [ ] 多モーダル（motion＋HR＋音響＋コメント）融合と `user_id` 個人化
- [ ] 確信度を出力し、UI/集計で正直にスコープ表示（valence/没入は低確信）

## フェーズ P-c: 学習素材（North Star）

- [ ] 集計特徴量を雰囲気レコメンドの入力に接続（別 steering で設計）

## 実装後の振り返り

（P-a 着手時に記入）
