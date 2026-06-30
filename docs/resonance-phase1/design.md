# 設計方針 — Resonance Phase 1 & README 個人化

> 作成日: 2026-06-30
> ブランチ: feat/how-resonance

---

## 1. 現状フロー分析

### 1-A. HowChat フロー（現在 Resonance まで繋がっている）

```
HomeView
  → ReactionDetectionViewModel（AirPods ピーク検出）
  → HowChatView
  → HowCardCreationView
      - postHowCard() は ChatAPIClient.shared.postHowCard() を使用
      - songId のデフォルト = ResonanceDemo.songId（"howtune-demo-song"）
      - 投稿完了オーバーレイに「同じ瞬間に反応した人を見る」ボタン
      → ResonanceMatchView（fullScreenCover）
          → ResonanceDMView（NavigationLink）
```

### 1-B. NowPlaying 歌詞フロー（Resonance への導線なし）

```
HomeView / MiniPlayer
  → NowPlayingView
  → 歌詞行タップ → LyricHowCardDraft 生成
  → LyricHowCardComposerView（sheet）
      - postHowCard() は FirebaseAPI.shared.createHowCard() を使用
      - songId = song.firestoreSongID（実曲 ID、デモシードとは不一致）
      - 投稿完了後に didPost = true となり、チェックマークのみ表示
      ※ Resonance への遷移なし
```

### 1-C. QuantumIgnitionView の待機状態

`ResonanceMatchView` は `hasSameSpot` が false のとき `startDate = Date.distantPast` を渡す。
`Date.distantPast` から現在までの elapsed が巨大になるため `progress = 1.0` 固定となり、
発火アニメーションが完了状態（🔥が最大輝度で静止）のまま、テキストオーバーレイで隠れる。
待機中の「量子ゆらぎ」という体験が成立していない。

---

## 2. 設計判断

### 2-A. LyricHowCardComposerView への Resonance 導線追加

**判断**: `LyricHowCardComposerView` の投稿完了後 UI（`didPost = true` 状態）に
「共鳴した人を見る」ボタンを追加し、`ResonanceMatchView` を `fullScreenCover` で呈示する。

**根拠**:

- `HowCardCreationView` の `postedOverlay` と同じパターンを踏む
- `LyricHowCardComposerView` は `Song` を受け取っているため、`draft.songStart` / `draft.songEnd` で
  マッチング区間を構成できる
- `ResonanceMatchView(songId:songTitle:myInterval:)` はすでに正しいインタフェースを持つ

**songId の扱い**:
デモ時は `song.firestoreSongID` ではなく `ResonanceDemo.songId` を使いたい。
ただし `LyricHowCardComposerView` は `Song` しか受け取らないため、
`song.firestoreSongID == ResonanceDemo.songId` の場合のみデモシードとマッチする。
代替案として、Resonance 画面への遷移時に渡す `songId` を `ResonanceDemo.songId` に
上書きする ENV フラグ（`HOWTUNE_RESONANCE_DEMO=true`）を検討したが、
複雑になるため、まず `song.firestoreSongID` をそのまま渡してデモ動画で使う曲を
シードと揃える運用とする（シードに実曲の song_id を追加するか、デモ専用フローを使う）。

実質的なデモでは引き続き HowChat フロー（`HowCardCreationView`）を使い、
NowPlaying 歌詞フローは導線を追加して「つながっている」ことを示す。

### 2-B. QuantumIgnitionView の待機ループ

**判断**: 待機中（`hasSameSpot = false`）に `startDate` を定期的にリセットしてアニメーションを
ループさせる。`ResonanceMatchView` に `Timer` か `TimelineView` ベースのループ管理を追加する。

実装方法:

- `ResonanceMatchView` に `@State private var pulseEpoch: Date = Date()` を追加
- `TimelineView(.periodic(from: ..., by: ResonanceVisualConfig.cycleDuration))` でエポックを更新
- `hasSameSpot` が false のとき `QuantumIgnitionView(startDate: pulseEpoch)` を渡す
- `hasSameSpot` が true のとき `ignitionStart` を渡す（現行の動作を維持）

`ResonanceVisualConfig.cycleDuration` (2.6秒) に合わせてループするため設定値の変更は不要。

### 2-C. ENV.plist による Firebase 切り替え

**判断**: コードを変更しない。`ENV.plist` + `GoogleService-Info.plist` を差し替えれば
Firebase プロジェクトが切り替わることを文書化するのみ。

`EnvironmentValueProvider` はすでに `ENV.plist` からキーを読み込む汎用設計になっており、
Firebase の初期化は `GoogleService-Info.plist` を参照するため、コード変更は不要。

### 2-D. README の構成方針

**判断**: 既存 README の構造を活かし、ハッカソン固有セクションのみ削除・縮小する。
大きな書き直しよりも、削除と一部書き換えに留める（週 1〜2 時間の制約内で完了させる）。

削除: チームメンバー表・提出ステータス・提出物チェックリスト・審査観点・担当メンター壁打ち履歴・運営連絡先・公開許諾セクション

追加: Firebase 切り替え手順の簡易セクション・Apple Developer Program なし前提の注記

維持: 1行ピッチ・スクリーンショット・デモ動画リンク・技術スタック・リポジトリ構成・セットアップ手順への参照

---

## 3. 影響ファイル一覧

### README 個人化

| ファイル    | 変更種別 | 内容                                                         |
| ----------- | -------- | ------------------------------------------------------------ |
| `README.md` | 編集     | ハッカソン固有セクション削除・個人プロジェクト向けに書き換え |

### Resonance Phase 1

| ファイル                                                            | 変更種別 | 内容                                                                                 |
| ------------------------------------------------------------------- | -------- | ------------------------------------------------------------------------------------ |
| `Othello/Othello/Views/NowPlaying/LyricHowCardComposerView.swift`   | 編集     | `didPost = true` 状態に Resonance 誘導ボタンと `fullScreenCover` 追加                |
| `Othello/Othello/Features/Resonance/Views/ResonanceMatchView.swift` | 編集     | 待機中ループアニメーション実装（`pulseEpoch` + `TimelineView` か `onAppear` + Task） |
| `functions/scripts/seed-resonance.js`                               | 変更なし | 現行スクリプトで十分。手順文書化のみ                                                 |
| `docs/resonance-phase1/`                                            | 新規     | 本ドキュメント群                                                                     |

### 変更しないファイル（影響なし）

| ファイル                       | 理由                                                          |
| ------------------------------ | ------------------------------------------------------------- |
| `ResonanceMatchService.swift`  | 動作確認済み、変更不要                                        |
| `ResonanceChatService.swift`   | 動作確認済み、変更不要                                        |
| `ResonanceDMView.swift`        | 動作確認済み、変更不要                                        |
| `QuantumIgnitionView.swift`    | View 自体は変更しない。呼び出し側（ResonanceMatchView）で制御 |
| `ResonanceDemo.swift`          | 定数のみ、変更不要                                            |
| `HowCardCreationView.swift`    | すでに Resonance 導線あり、変更不要                           |
| `PeakMotionTracker.swift`      | 変更不要                                                      |
| `AirPodsMotionViewModel.swift` | 変更不要                                                      |

---

## 4. アーキテクチャ上の判断

### Firestore 直読みの維持

`ResonanceMatchService` は Firestore を直接購読している（Functions 経由なし）。
これはリアルタイム性の優先という既存設計（ADR-0006）に沿っており、変更しない。

### デモ songId の二重管理を避ける

`LyricHowCardComposerView` に `ResonanceDemo.songId` を直接埋め込むと、
本番運用時に誤ったマッチングが起きる。
デモ体験では HowChat フローを主経路とし、NowPlaying 歌詞フローは
「導線がある」ことを示すに留める。

### QuantumIgnitionView のループは呼び出し側で制御

`QuantumIgnitionView` 自体は startDate をもとに 1 サイクル（2.6秒）を描画する
純粋な描画 View であり、ループロジックを内包させない。
ループ制御は `ResonanceMatchView` 側が責務を持つ（単一責任の原則）。

---

## 5. 既存パターンとの整合性

| パターン                        | 既存実装                                                | 本フェーズ                                      |
| ------------------------------- | ------------------------------------------------------- | ----------------------------------------------- |
| HowCard 投稿後の Resonance 遷移 | `HowCardCreationView.postedOverlay` → `fullScreenCover` | `LyricHowCardComposerView` に同じパターンを踏む |
| Firestore リアルタイム購読      | `onAppear` で start、`onDisappear` で stop              | 変更なし                                        |
| ダークテーマ UI                 | `Color.black` + `preferredColorScheme(.dark)`           | 追加 UI も同じスタイルを踏む                    |
| ENV 設定                        | `EnvironmentValueProvider.value(forKey:)`               | コード変更なし、文書化のみ                      |
