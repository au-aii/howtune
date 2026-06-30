# 要件定義 — Resonance Phase 1 & README 個人化

> 作成日: 2026-06-30
> ブランチ: feat/how-resonance
> スコープ: Issue #1

---

## 背景

HowTune はハッカソン（Engineer Guild Hackathon 2026/05）として開発されたが、
今後はソロ開発・ホビープロジェクトとして継続する。
本フェーズでは「AirPods 反応検出 → HowCard 投稿 → Resonance マッチング → DM」の
コアループを 1 台のデバイスでデモできる状態に仕上げる。

---

## スコープ 1: README 個人化

### 要求

| ID     | 要求内容                                                                                      |
| ------ | --------------------------------------------------------------------------------------------- |
| RDM-01 | ハッカソン審査用のチーム情報・メンバー表・提出チェックリストを整理する                        |
| RDM-02 | 個人プロジェクトとして語れる形（1行ピッチ・プロダクト説明）に書き直す                         |
| RDM-03 | デモ動画と主要スクリーンショットは維持する                                                    |
| RDM-04 | セットアップ手順（ENV.plist / Firebase 切り替え）を独立した README セクションとして記述する   |
| RDM-05 | `docs/setup.md` へのリンクを維持しつつ、README 単体でも最低限のセットアップが分かる構成にする |

### 受け入れ条件

- ハッカソン固有のセクション（審査観点・運営連絡先・担当メンター・壁打ち履歴）を削除または最小化する
- Firebase プロジェクト切り替え手順（`ENV.plist` + `GoogleService-Info.plist` の差し替え）が明記される
- デモ動画 URL・スクリーンショットが残る
- Apple Developer Program なしでの制約（TestFlight 不可・実機署名のみ）が明記される

---

## スコープ 2: Resonance Phase 1

### 目的

AirPods で反応を検出してから DM 画面に到達するまでのコアループを、
1 台の実機 + シードデータで完結してデモできるようにする。

### 要求

| ID     | 要求内容                                                                                              | 優先度 |
| ------ | ----------------------------------------------------------------------------------------------------- | ------ |
| RES-01 | デモモードで `howtune-demo-song` のシードデータに対して Resonance マッチングが動作する                | 必須   |
| RES-02 | NowPlaying（歌詞タップ）フローでも HowCard 投稿後に Resonance 画面へ遷移できる                        | 必須   |
| RES-03 | `QuantumIgnitionView` の待機中状態（マッチ未確定）がループするアニメーションで表現される              | 必須   |
| RES-04 | Resonance 画面（`ResonanceMatchView`）への入口が UI 上で明確にユーザーへ提示される                    | 必須   |
| RES-05 | シードスクリプト（`seed-resonance.js`）を新しい Firebase プロジェクトでも実行できる手順が文書化される | 推奨   |
| RES-06 | `ENV.plist` の差し替えだけで Firebase プロジェクトを切り替えられるようコードが整理される              | 推奨   |

### 現状の実装（既に動作している）

- `ResonanceMatchService` — Firestore リアルタイム購読（動作確認済み）
- `ResonanceChatService` — 2者間 DM（動作確認済み）
- `ResonanceMatchView` — マッチング一覧 UI（実装済み）
- `ResonanceDMView` — DM 画面（実装済み）
- `QuantumIgnitionView` — 量子→発火演出（実装済み、2.6秒 1サイクル）
- `ResonanceDemo.songId` = `"howtune-demo-song"`（定数定義済み）
- `seed-resonance.js` — 5件のシードカード投入スクリプト（実装済み）

### 現状の課題（本フェーズで解消する）

| 課題 ID | 内容                                                                                                                          |
| ------- | ----------------------------------------------------------------------------------------------------------------------------- |
| GAP-01  | `LyricHowCardComposerView`（NowPlaying 歌詞タップ）の投稿完了後に Resonance への導線がない                                    |
| GAP-02  | `LyricHowCardComposerView` は `song.firestoreSongID`（実曲 ID）を使うため、`howtune-demo-song` シードとマッチしない           |
| GAP-03  | `QuantumIgnitionView` の待機状態（`hasSameSpot = false`）でアニメーションが静止する（`Date.distantPast` を渡すと p=1.0 固定） |
| GAP-04  | HowChat フローと NowPlaying 歌詞フローでデモ体験の一貫性がない                                                                |

### デモモードの定義

- 曲: `howtune-demo-song`（仮想曲 ID）
- シードデータ: `seed-resonance.js` が投入する 5 件の how-cards（20〜165 秒の複数区間）
- 動作確認環境: iPhone 1 台（AirPods 接続）
- TestFlight 不要・Apple Developer Program なし

### 受け入れ条件

- `howtune-demo-song` でシードデータが入った Firebase に接続すると、Resonance 画面に🔥同地点マッチが表示される
- NowPlaying 歌詞タップ → Howcard 投稿 → Resonance 画面の遷移が 3 ステップで完了する
- Resonance 待機中（マッチ未確定）に量子ゆらぎアニメーションがループ再生される
- Resonance 画面から DM 画面に遷移してメッセージを送受信できる
- 新しい Firebase プロジェクトへの切り替えは `ENV.plist` + `GoogleService-Info.plist` の差し替えのみで完了する

---

## 対象外（本フェーズ外）

- Firebase 新規プロジェクトの作成・設定作業（インフラ作業として別途実施）
- TestFlight / App Store 配信
- プッシュ通知
- HowChat エンドポイントの本番接続
- AirPods 以外のセンサー（HealthKit 心拍など）
