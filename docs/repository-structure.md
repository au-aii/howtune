# リポジトリ構造定義書 (Repository Structure Document)

> **本書は実装の実態に追従する**。2026-05-25 時点の main の実装を反映。

## プロジェクト構造（実態）

iOS ネイティブアプリ（`Othello/`）を中心に、バックエンド・AIモデルを並置する構成。

```
team-10/
├── Othello/            # iOS ネイティブアプリ（Xcode / SwiftUI）
├── functions/          # Firebase Functions（本番 API）
├── web/                # 閲覧用 Web ダッシュボード（Next.js / Firebase Hosting）
├── backend/            # 旧 Express 実装（deprecated / 参照用）
├── ai-recognition/     # 反応分類モデル（Create ML + TS）+ 教師データ収集アプリ
├── frontend/           # フロントエンド置き場（MVP 未使用）
├── docs/               # プロジェクトドキュメント
├── .claude/            # Claude Code 設定
├── .devcontainer/      # Dev Container 設定
├── .coderabbit.yaml    # CodeRabbit（自動レビュー）設定
├── AGENTS.md           # 全エージェント共通ガイド
├── CLAUDE.md           # Claude Code プロジェクトルール
└── AI_USAGE_LOG.md     # AI 活用ログ
```

> プロダクト名は HowTune、Xcode プロジェクト名・チーム名は Othello。

---

## Othello/（iOS アプリ）の実態

**Feature ベース** のモジュール（`Features/`）と、横断的な**共通レイヤー**（ルート直下の `Models/` `ViewModels/` `Views/` `Services/`）のハイブリッド構成。

```
Othello/Othello/
├── OthelloApp.swift              # @main
├── ContentView.swift
├── Features/                     # Feature ベースモジュール（各 Models/Services/ViewModels/Views を内包）
│   ├── AirPodsMotion/            # AirPods 頭部モーション取得
│   │   ├── Models/               # AirPodsMotionEvent / Sample / Status
│   │   ├── Protocols/            # AirPodsMotionManaging / PlaybackPositionProviding
│   │   ├── Services/             # AirPodsMotionManager
│   │   └── ViewModels/           # AirPodsMotionViewModel
│   ├── Playback/                 # MusicKit 再生・再生位置
│   │   ├── Models/               # PlaybackTrack
│   │   ├── Services/             # MusicKitPlaybackService
│   │   └── ViewModels/           # PlaybackViewModel
│   ├── ReactionDetection/        # 反応検出（Core ML 分類）
│   │   ├── Models/               # ActivityPrediction / ReactionFeatureWindow
│   │   ├── Services/             # OthelloActivityClassifierService / ReactionScoringService
│   │   └── ViewModels/           # ReactionDetectionViewModel
│   ├── ReactionDisplay/          # 反応スコアの可視化
│   │   ├── Models/               # ReactionScore
│   │   ├── Services/             # MotionReactionScoreEstimator
│   │   └── ViewModels/           # ReactionDisplayViewModel
│   ├── HowChat/                  # AI 対話・Howカード生成
│   │   ├── Models/               # HowChatMessage
│   │   ├── Services/             # ChatAPIClient
│   │   ├── ViewModels/           # HowChatViewModel
│   │   └── Views/                # HowChatView / HowCardCreationView
│   └── Lyrics/                   # 歌詞（時間同期）
│       ├── Models/               # SynchronizedLyrics / TimedLyricLine / LyricsTrackQuery 他
│       ├── Protocols/            # LyricsProviding
│       ├── Services/             # MusixmatchLyricsProvider / StaticLyricsParser / TimedLyricsResolver / EnvironmentValueProvider
│       └── ViewModels/           # LyricsViewModel
├── Models/                       # 共通モデル
│   ├── FirestoreUser.swift
│   ├── HowCardComment.swift
│   ├── PermissionState.swift
│   ├── ReactionEvent.swift       # 3状態 HowTag（groove/chill/neutral）
│   └── SensorStatus.swift
├── Services/
│   └── FirebaseAPI.swift         # Firebase/backend 通信（横断）
├── ViewModels/                   # 横断 ViewModel
│   ├── AuthViewModel.swift
│   ├── CommunityViewModel.swift
│   ├── HomeViewModel.swift
│   ├── OnboardingViewModel.swift
│   └── ReactionTimelineViewModel.swift
└── Views/                        # 横断 View
    ├── Auth/                     # LoginView / SignUpView
    ├── Home/                     # HomeView / AirPodsReactiveWaveformView / MetalWaveformRenderer
    ├── Onboarding/               # OnboardingView / WelcomePage / MusicPage / MotionPage / Components
    ├── ReactionDisplay/          # ReactionDisplayView / RealtimeReactionDisplayView / ReactionAxisBar
    ├── Timeline/                 # ReactionTimelineView / ReactionEventRow / TimelineBar
    └── Community/                # CommunityView
```

**構成の方針**:

- 新しい・独立性の高い機能は `Features/<機能>/`（Models/Protocols/Services/ViewModels/Views を内包）
- 認証・ホーム・オンボーディングなど横断的なものはルート直下の `Views/` `ViewModels/`
- センサー等は **Protocols/**（`AirPodsMotionManaging`, `PlaybackPositionProviding`, `LyricsProviding`）でインターフェースを定義しモック可能に

---

## functions/ と backend/

| ディレクトリ | 内容                             | エンドポイント                                                     |
| ------------ | -------------------------------- | ------------------------------------------------------------------ |
| `functions/` | Firebase Functions。**本番 API** | `/health`, `/how-cards`, `/users/me`                               |
| `backend/`   | deprecated な旧 Express 実装     | `/sessions` や Claude 連携の参照実装が残るが、本番には反映されない |

> 新規 API 変更は `functions/` に追加する。`backend/` を編集しても本番 deploy には反映されない。

---

## web/（閲覧用 Web ダッシュボード）

| 項目         | 内容                                                                                                                                       |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------ |
| 技術         | Next.js（App Router）+ TypeScript、Firebase JS SDK、静的エクスポート（`output: "export"`）                                                 |
| 役割         | **閲覧専用**。iOS と同じ Firebase Auth でログインし Firestore を直読み。収集は iOS、閲覧は Web（ADR-0007）                                 |
| 主要ファイル | `web/src/lib/firebase.ts`（初期化）/ `howCards.ts`・`songInsights.ts`（データ取得）/ `components/Dashboard.tsx`・`SongInsight.tsx`（表示） |
| 配信         | Firebase Hosting（`howtune-74252`、https://howtune-74252.web.app）。`web/out` を deploy                                                    |

> Web は Firestore を**読むだけ**。書き込みは iOS→`functions/` 経由のまま（ADR-0002）。B2B は Functions 集計済み `song_insights`（匿名・k=5）だけを見せる。

---

## ai-recognition/（反応分類モデル）

**Create ML + TypeScript** によるモデル開発と、教師データ収集アプリ。

```
ai-recognition/
├── OthelloActivityClassifier.mlproj/   # Create ML プロジェクト（学習済みモデル・チェックポイント）
├── packages/ml/                        # TypeScript の学習・推論コード（src / models / data）
└── apps/                               # 教師データ収集アプリ
    ├── collect-ios/                    # iOS 収集アプリ（HowTuneCollector）
    └── collect-web/                    # Web 収集アプリ
```

> 反応分類は **Create ML（`OthelloActivityClassifier`）** で学習し、Othello の `OthelloActivityClassifierService` が利用する（Core ML 推論）。`packages/ml`（TS）は学習・前処理パイプライン。

---

## 命名規則（実態）

| 対象                 | 規則                                     | 例                                                  |
| -------------------- | ---------------------------------------- | --------------------------------------------------- |
| Feature ディレクトリ | PascalCase                               | `AirPodsMotion/`, `ReactionDetection/`              |
| Swift 型・ファイル   | PascalCase                               | `AirPodsMotionManager.swift`, `ReactionEvent.swift` |
| Protocol             | `〜ing` / `〜Providing`                  | `AirPodsMotionManaging`, `LyricsProviding`          |
| View                 | `〜View`                                 | `HowChatView.swift`                                 |
| ViewModel            | `〜ViewModel`                            | `ReactionDisplayViewModel.swift`                    |
| Service              | `〜Service` / `〜Manager` / `〜Provider` | `MusicKitPlaybackService`, `AirPodsMotionManager`   |
| backend ルート       | kebab-case                               | `how-cards.js`                                      |

---

## 依存関係のルール

```
Othello (iOS)  ──HTTPS + Firebase ID token──▶  functions  ──▶  Firestore
                                       ▲
ai-recognition (Create ML/TS) ──.mlmodel──┘（学習成果物を Othello に組み込み）
```

- Howカードコメントは Functions API を経由する。`users/{uid}` はログイン中ユーザー自身に限り Firestore rules 経由で read/write する
- View はセンサー/通信を直接制御せず、Service（Protocol 経由）を使う
- Feature 間の直接依存は避け、共通モデル（`Models/`）を介する

---

## .steering/（作業ステアリング）

```
.steering/
└── YYYYMMDD-task-name/
    ├── requirements.md
    ├── design.md
    └── tasklist.md
```

---

## docs/（ドキュメント）

| ファイル                    | 内容                                    |
| --------------------------- | --------------------------------------- |
| `frontend-spec.md`          | 仕様の source of truth（Notion ミラー） |
| `product-requirements.md`   | PRD                                     |
| `architecture.md`           | アーキテクチャ設計                      |
| `functional-design.md`      | 機能設計                                |
| `repository-structure.md`   | 本ドキュメント                          |
| `development-guidelines.md` | 開発ガイドライン                        |
| `glossary.md`               | 用語集                                  |
| `adr/`                      | 設計決定記録（ADR-0001〜0005）          |
| `mentor-fb-day2.md`         | メンターFB 準備                         |
| `business/`                 | インセプションデッキ・リーンキャンバス  |
