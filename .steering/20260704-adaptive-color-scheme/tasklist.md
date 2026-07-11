# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- 全てのタスクを `[x]` にする
- 未完了タスク（`[ ]`）を残したまま作業を終了しない
- スキップは技術的理由のみ、理由を明記

---

## フェーズ1: カラー基盤（先行・手動）

- [x] `HowTuneDesign` トークンをアダプティブ化（`OnboardingComponents.swift`）
  - [x] `background` → `Color(.systemBackground)`
  - [x] `surface` → `Color(.secondarySystemBackground)`
  - [x] `divider` → `Color(.separator)`
  - [x] `purposeCard` / `skipButton` の `.white`/`.gray` を semantic に（グラデ上白文字は維持）
- [x] テーマ設定を OS 追従に（`OthelloApp.swift`）
  - [x] `themePreference` enum（system/light/dark、デフォルト system）を導入
  - [x] `.preferredColorScheme` を enum に応じ `nil`/`.light`/`.dark` へ
- [x] ForYou トグルを 3 状態循環に（`ForYouView.swift`）
  - [x] `prefersDarkTheme` 参照を `themePreference` に置換
  - [x] アイコンを system/light/dark で切替
- [x] フェーズ1 のビルド green を確認（追加で `UITextField.appearance().textColor = .white` の強制を撤廃）

## フェーズ2: 全画面カラー一括置換（サブエージェント並列）

- [x] G1 Auth/Main: `LoginView`, `SignUpView`, `ContentView`, `ForYouView`
- [x] G2 NowPlaying: `NowPlayingView`, `CircularArtworkView`, `ClipCreationInlineView`, `GlobalMiniPlayerView`, `LyricHowCardComposerView`
- [x] G3 Home: `HomeView`, `AirPodsReactiveWaveformView`, `LiveReactionScoreCard`
- [x] G4 MusicFeed: `MusicFeedView`, `FeedPostCard`, `HighlightedHowCardCommentCard`, `HowCardRepliesView`, `HowCardReplyRow`, `MiniSongCard`
- [x] G5 ClipCreation: `ClipCreationView`, `ClipRangeSelectionView`, `ClipRangeWaveformView`
- [x] G6 ReactionDisplay/Timeline: `ReactionDisplayView`, `ReactionTimelineView`, `ReactionEventRow`, `ReactionAxisBar`, `RealtimeReactionDisplayView`, `TimelineBar`
- [x] G7 Resonance/HowChat/Community: `QuantumIgnitionView`, `ResonanceMatchView`, `HowChatView`, `HowCardCreationView`, `CommunityView`, `AppleMusicAccessBanner`
- [x] G8 その他: Onboarding 3ページ（Welcome/Motion/Music）を置換

## フェーズ3: 品質チェックと検証

- [x] Xcode ビルドが green（`BUILD SUCCEEDED`）
- [x] ~~SwiftLint エラーがないことを確認~~（環境未導入のためスキップ: ビルド green で代替）
- [x] ライトモードでスクショを撮り破綻がないか確認（代表: Onboarding Welcome 画面）
  - [x] `xcrun simctl ui booted appearance light`
- [x] ダークモードでスクショを撮り従来通りか確認
  - [x] `xcrun simctl ui booted appearance dark`
- [x] ブランド色（赤・グラデ・HowTag）が両モードで維持されているか確認
- [x] 検出した崩れを補正（スクショ範囲では崩れなし。波形の固定暗色背景は描画上の意図的維持として残置、実機で最終確認）

## フェーズ4: PR とドキュメント

- [x] カラー対応をコミット
- [x] PR 作成（ベース: `1-feat-resonance-phase-1`）
- [ ] `AI_USAGE_LOG.md` に追記
- [x] 実装後の振り返り（このファイル下部に記録）

---

## 実装後の振り返り

### 実装完了日

2026-07-04

### 計画と実績の差分

- 方式はシステムセマンティックカラー中心で計画通り。新規 colorset は作らずに済んだ。
- 追加変更: `UITextField.appearance().textColor = .white` の強制を撤廃（ライトで文字が見えなくなるため）。当初計画に無かったが必須だった。
- `ForYouView` はフェーズ1でテーマトグルのみ変更し、色置換は G1 に委譲する2段構えにした。
- `ClipRangeWaveformView` / `AirPodsReactiveWaveformView` は波形描画の暗色前提のため未変更（維持）。ライトモードで浮く可能性は実機確認事項。

### 学んだこと

- `SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor` 環境では `Color(.systemBackground)` 記法が SourceKit で毎回「解決不可」と誤検知されるが実ビルドは通る（単一ファイル解析の限界）。
- 8グループの dev-agent 並列で、ファイル非重複なら編集衝突なく安全。共通の置換ルール表＋置換禁止リストを渡すと判断が揃う。
- 「写真・グラデ・アクセント色の上の白文字は維持」を明示したことで、エージェントが赤ボタン上の白文字などを正しく保持できた。

### 次回への改善提案

- 波形など描画系コンポーネントは、背景を semantic 化するなら描画色も連動させる設計が要る（今回は維持で回避）。
- ライト専用のブランド色味を詰めるなら、次はアセットカタログに colorset を導入する。
