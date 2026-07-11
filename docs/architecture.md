# 技術仕様書 (Architecture Design Document)

> 2026-05-25 時点の実装に追従する。対象は **iOS ネイティブ（Xcode / SwiftUI）** と **Firebase Cloud Functions v2**。

## テクノロジースタック

### iOS アプリ（`Othello/`）

| 技術                     | 用途                                       |
| ------------------------ | ------------------------------------------ |
| Swift / SwiftUI          | UI・アプリ全般                             |
| MusicKit                 | Apple Music の楽曲検索・再生・再生位置取得 |
| CMHeadphoneMotionManager | AirPods 頭部モーション取得                 |
| Core ML                  | `OthelloActivityClassifier` による補助推論 |
| Firebase Auth            | ログイン、ID token 取得                    |
| URLSession               | Functions / Musixmatch API 連携            |
| Musixmatch API           | 時間同期歌詞または静的歌詞取得             |
| AVFoundation             | 出力音量取得、UI visualizer の補助値       |

HealthKit / 心拍連携は現行実装から削除済み。

### バックエンド（`functions/`）

| 技術                        | 用途                                         |
| --------------------------- | -------------------------------------------- |
| Firebase Cloud Functions v2 | 本番 API のデプロイ                          |
| Node.js 20 / Express        | HTTP routing                                 |
| Firebase Admin SDK          | Firestore read/write、Firebase ID token 検証 |
| Firestore                   | `users` / `how-cards` 永続化                 |

旧 `backend/` は deprecated な参照実装。Claude / `/sessions` 系 API は Functions 本番には接続されていない。

### Web ダッシュボード（`web/`）

| 技術                                | 用途                                                                     |
| ----------------------------------- | ------------------------------------------------------------------------ |
| Next.js（App Router）/ TypeScript   | 閲覧用 UI（静的エクスポート `output: "export"`）                         |
| Firebase JS SDK（Auth / Firestore） | iOS と同じアカウントでログイン、Firestore を直読み                       |
| Firebase Hosting                    | 同一プロジェクト `howtune-74252` で配信（https://howtune-74252.web.app） |

**閲覧専用**の新サーフェス。収集は iOS、閲覧は Web、真実の源は Firebase という責務分離（ADR-0007）。本人向けは `how-cards` を `user_id==自分` で直読み（Phase 1）、B2B は Functions で集計・匿名化した `song_insights`（k=5・`user_id` を含めない）のみを見せる（Phase 2）。

### AI モデル（`ai-recognition/`）

| 技術                | 用途                                      |
| ------------------- | ----------------------------------------- |
| Create ML / Core ML | 3状態（groove / chill / neutral）推論候補 |
| TypeScript tooling  | 学習・前処理パイプライン                  |

---

## 全体構成

```text
┌──────────────────────────────────────────────────────────┐
│ iOS アプリ（Othello / SwiftUI）                          │
│                                                          │
│ View                                                     │
│ - Login / Onboarding                                    │
│ - ForYou / MusicFeed / GlobalMiniPlayer / NowPlaying     │
│ - Home / Lyrics / HowChat / HowCardCreation              │
│                                                          │
│ ViewModel                                                │
│ - AuthViewModel / PlaybackViewModel                      │
│ - AirPodsMotionViewModel / ReactionDetectionViewModel    │
│ - MusicFeedViewModel / CommunityViewModel                │
│                                                          │
│ Service                                                  │
│ - MusicKitPlaybackService                                │
│ - AirPodsMotionManager                                   │
│ - MusixmatchLyricsProvider                               │
│ - FirebaseAPI                                            │
└───────────────┬───────────────────────┬──────────────────┘
                │                       │
                │ HTTPS + Firebase ID   │ HTTPS
                │ token                 │
┌───────────────▼────────────────┐      │
│ Firebase Functions v2           │      │
│ - GET /health                   │      │
│ - /how-cards                    │      │
│ - /users/me                     │      │
└───────────────┬────────────────┘      │
                │                       │
          ┌─────▼─────┐          ┌──────▼────────┐
          │ Firestore │          │ Musixmatch API │
          └───────────┘          └───────────────┘
```

---

## レイヤー責務

### View

- 画面表示とユーザー操作を扱う。
- センサー・再生・通信の詳細は ViewModel / Service に委譲する。

### ViewModel

- UI state を `@Published` で管理する。
- Service を呼び出し、画面表示に必要な形へ変換する。

### Service

- `MusicKitPlaybackService`: MusicKit 認証、検索、再生、再生位置供給。
- `AirPodsMotionManager`: AirPods 頭部モーション取得。再生位置が取れる場合は曲中時刻に同期する。
- `ReactionDetectionViewModel` / `ReactionScoringService`: 2秒窓の頭部モーション特徴量から 3状態スコアを算出する。
- `MusixmatchLyricsProvider`: Musixmatch の `matcher.track.get` → `track.subtitle.get` → `track.lyrics.get` fallback。
- `FirebaseAPI`: Functions API との通信。Firebase ID token を付与する。

### Functions

- Firebase ID token を検証する。
- Howカードコメントの作成・取得・更新・いいねを処理する。
- Howカードへの返信一覧取得・作成を処理する。
- ユーザー情報の取得・更新を処理する。
- Firestore への直接 client access を避け、Admin SDK 経由に集約する。

---

## ディレクトリ構成

```text
team-10/
├── Othello/                    # iOS ネイティブアプリ
├── functions/                  # Firebase Functions 本番 API
├── web/                        # 閲覧用 Web ダッシュボード（Next.js / Firebase Hosting）
├── backend/                    # deprecated 参照実装
├── ai-recognition/             # 反応分類モデル
├── frontend/                   # MVP 未使用
└── docs/                       # ドキュメント
```

---

## データ永続化

詳細は [`docs/data-model.md`](./data-model.md) を参照。

現行 Functions が永続化する主な collection:

- `users/{uid}`
- `how-cards/{cardId}`
- `how-cards/{cardId}/liked-by/{uid}`
- `how-cards/{cardId}/replies/{replyId}`

`sessions` は現行 Functions では作成しない。

---

## パフォーマンス要件

| 操作                       | 目標                                          |
| -------------------------- | --------------------------------------------- |
| MusicKit 再生位置更新      | UI を阻害しない                               |
| AirPods 頭部モーション取得 | background queue で処理                       |
| 反応スコア更新             | 体感的にリアルタイム                          |
| Howカード一覧取得          | 2 秒以内                                      |
| 歌詞取得                   | 失敗時は静的歌詞または歌詞なし表示へ fallback |

---

## セキュリティ

- Firebase ID token を Functions 側で検証する。
- Howカードコメントは iOS から Firestore に直接書き込まず、Functions API 経由で保存する。
- `users/{uid}` はログイン中ユーザー自身に限って iOS から Firestore rules 経由で read/write する。
- `MUSIXMATCH_API_KEY` と `API_BASE_URL` は `ENV.plist` で管理し、git に含めない。
- Howカードコメントの Firestore 書き込みは Functions の Admin SDK に集約する。
- HealthKit / 心拍データは取得しない。

---

## 技術的制約

- AirPods 頭部モーションは対応 AirPods と iPhone 実機が必要。
- MusicKit は Apple Music カタログ再生権限が必要な場合がある。
- Musixmatch の同期歌詞は契約・楽曲 availability に依存するため、静的歌詞 fallback を前提にする。
- HowChat の legacy `/sessions` client は Functions 本番 API と未接続。デモ時は mock mode または別途 Functions 実装が必要。

---

## テスト戦略

- `node --check` で Functions の構文確認。
- Xcode build で iOS のコンパイル確認。
- 実機で MusicKit 再生、AirPods 頭部モーション、歌詞 fallback、Howカード API 保存を確認。
- Functions API は `/health`、未認証時 401、認証付き `/how-cards` を確認する。
