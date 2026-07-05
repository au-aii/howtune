# タスクリスト — 生 ReactionEvent / モーションの永続化

> 本 steering は**設計まで**。実装は下記を承認後に別セッションで着手する。
> 未決事項（保存粒度・同意モデル・B2B 範囲）が確定してから P-a に入る。

## フェーズ 0: 設計（この steering）

- [x] 実データフローの裏取り（`AirPodsMotionSample` / `ReactionEvent` / `createHowCard`）
- [x] requirements.md（課題・要件・プライバシー・未決）
- [x] design.md（`reaction_sessions` スキーマ・書き込み経路・段階案）
- [x] 生理学的精査（frisson / groove / circumplex / 頭部モーション情動推定を文献裏取り）＋ ML 前提（multi-label・arousal/valence 回帰・時系列・多モーダル・個人化）を requirements/design に統合
- [ ] **未決4点をユーザーが確定**（保存粒度 / 同意 opt-in・out / B2B 二次利用範囲 / ML ラベル方針）

## フェーズ P-a: 最小（events + 弱教師ラベル・moat 着火）

- [ ] `firestore.rules` に `reaction_sessions/{id}`（本人のみ read、書き込みは Functions/本人）
- [ ] iOS: 曲停止時に `ReactionEvent[]`（multi-label タグ）＋ `self_report.tags`（弱教師ラベル）を `reaction_sessions` へバッチ書き込み（同意チェック付き）
- [ ] Functions: `onReactionSessionWritten` トリガー（`onHowCardWritten` と同型）
- [ ] Functions: `recomputeSongInsights` を `reaction_sessions.events` 由来の密度に拡張（How カードのみの曲はフォールバック）
- [ ] 検証: エミュレータで書き込み→再集計、rules で他人読み取り不可、iOS `xcodebuild` green

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
