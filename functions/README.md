# HowTune Functions

HowTune バックエンドの **Firebase Cloud Functions v2** デプロイターゲット。
本番環境はここからデプロイされる。

---

## アーキテクチャ

- **ランタイム:** Node.js 20 on Cloud Run（Functions v2 の実体）
- **リージョン:** `asia-northeast1`（東京）
- **エクスポート:**
  - `api` — HTTPS Function に Express アプリ全体をマウント
  - `onUserSignup` — Firebase Auth の `onCreate` トリガー（v1）。新規サインアップ時に `users/{uid}` を自動生成
- **認証:** Firebase ID トークン（`middleware/auth.js`）
- **データ:** Firestore（`repositories/firestore.js`、Admin SDK）

### コールドスタート対策

`index.js` の `onRequest` に `minInstances: 1` を設定済み。
常時 1 インスタンス温めるため、HTTP API のコールドスタートはほぼ発生しない。

**コスト:** 256 MiB × 1 インスタンス常駐 ≒ 月 5 USD 程度。
不要になったら `minInstances: 0` に変更して再デプロイすれば停止する。

Auth トリガー (`onUserSignup`) には `minInstances` を設定していない（サインアップは頻度が低く、多少のコールドスタートは許容）。

### Auth トリガー (onUserSignup)

Firebase Auth で新規ユーザー作成が走ったタイミングで `users/{uid}` を自動生成する。

- 発火条件: Firebase Auth で新規ユーザーが作成された時（iOS の初回サインアップ）
- 既存ユーザーには発火しない（onCreate なので新規のみ）
- iOS 側の `PUT /users/me`、または Firestore rules で許可された自分自身の `users/{uid}` 直接 read/write は追加同期用。メールアドレスは ID トークンの値を正とする
- ドキュメント内容: `{ user_id, email, display_name, created_at, updated_at }`
- 実装は v1 SDK（`firebase-functions/v1`）。v2 の Auth トリガーは blocking 専用なので、非同期で完了する onCreate には v1 を使う

---

## ディレクトリ構成

```text
functions/
├── index.js                  # Functions エントリ（HTTP api + Auth トリガー）
├── app.js                    # Express アプリビルダー（mount だけ、listen しない）
├── middleware/
│   └── auth.js               # Firebase ID トークン検証
├── repositories/
│   └── firestore.js          # Firestore 読み書き（how-cards / users）
├── routes/
│   ├── how-cards.js          # /how-cards 配下
│   ├── recommended-comments.js # /recommended-comments
│   └── users.js              # /users / /users/me
├── package.json
└── .gitignore
```

---

## 初回デプロイ

### 1. 前提条件の確認

```powershell
firebase --version            # 14.x 以上
firebase projects:list        # egh-howtune が見えること
firebase use egh-howtune      # アクティブプロジェクト設定（.firebaserc にあるので通常は不要）
```

未インストールなら:

```powershell
npm install -g firebase-tools
firebase login
```

### 2. 依存関係インストール

```powershell
cd functions
npm install
```

### 3. デプロイ

```powershell
firebase deploy --only "functions,firestore:indexes"
```

> PowerShell では `--only` の値全体を **ダブルクオートで囲む**こと。クオート無しだとカンマが PowerShell のオプション区切りと解釈されてエラーになる。

初回は 5〜10 分（Cloud Run プロビジョニング込み）。2 回目以降は 1〜3 分。

### 4. デプロイ後の URL

```text
https://asia-northeast1-egh-howtune.cloudfunctions.net/api
```

動作確認:

```powershell
curl https://asia-northeast1-egh-howtune.cloudfunctions.net/api/health
# → {"status":"ok"} が返れば OK
```

iOS チームには上記の URL をベース URL として共有する。

### 5. Auth トリガーの動作確認

iOS でテストユーザーを新規サインアップ → Firebase Console の Firestore で `users/{uid}` ドキュメントが自動生成されていることを確認する。

---

## エンドポイント一覧

ベース URL: `https://asia-northeast1-egh-howtune.cloudfunctions.net/api`

| メソッド | パス                     | 認証 | 用途                                                   |
| -------- | ------------------------ | ---- | ------------------------------------------------------ |
| GET      | `/health`                | ❌   | 死活確認                                               |
| GET      | `/how-cards`             | ✅   | Howカードコメント一覧（デフォルト最新50件、最大250件） |
| GET      | `/how-cards?song_id=...` | ✅   | 曲ごとのHowカードコメント一覧                          |
| GET      | `/how-cards/:id`         | ✅   | Howカードコメント取得                                  |
| GET      | `/how-cards/:id/replies` | ✅   | Howカードへの返信一覧                                  |
| POST     | `/how-cards`             | ✅   | Howカードコメント作成                                  |
| PATCH    | `/how-cards/:id`         | ✅   | 自分のHowカードコメント更新                            |
| POST     | `/how-cards/:id/like`    | ✅   | いいね（冪等、二重防止）                               |
| POST     | `/how-cards/:id/replies` | ✅   | Howカードへ返信                                        |
| GET      | `/recommended-comments`  | ✅   | Home dashboard 向けおすすめコメント一覧                |
| GET      | `/users/me`              | ✅   | 自分のユーザー情報取得                                 |
| PUT      | `/users/me`              | ✅   | 自分のユーザー情報作成・更新                           |

### `POST /how-cards`

ユーザー入力の Howカードコメントを作成する。

**リクエスト**

```json
{
  "comment": "このベースラインの入りが好き",
  "song_start": 78.4,
  "song_end": 84.2,
  "song_id": "1704093812",
  "song_slug": "ado-show",
  "artist_id": "ado"
}
```

| フィールド   | 型     | 説明                                                                                 |
| ------------ | ------ | ------------------------------------------------------------------------------------ |
| `comment`    | string | ユーザー記入のコメント（空文字不可）                                                 |
| `song_start` | number | 区間開始（秒、0 以上）                                                               |
| `song_end`   | number | 区間終了（秒、`song_start` より大きい）                                              |
| `song_id`    | string | MusicKit / Apple Music / iTunes の数値曲 ID（例: `1704093812`）。slug や表示名は不可 |
| `song_slug`  | string | 任意。表示・移行用の曲 slug。`song_id` には入れない                                  |
| `artist_id`  | string | アーティスト ID                                                                      |

`song_id` は client が MusicKit metadata lookup に使う canonical ID とする。slug や曲名由来の値は `song_slug` など別フィールドで送る。

**レスポンス**

```json
{
  "howCard": {
    "id": "card456",
    "comment": "このベースラインの入りが好き",
    "song_start": 78.4,
    "song_end": 84.2,
    "song_id": "1704093812",
    "itunes_id": "1704093812",
    "artist_id": "ado",
    "user_id": "uid123",
    "likes": 0
  }
}
```

### `GET /how-cards`

最新の Howカードコメント一覧を返す（デフォルト 50 件、`limit` 指定時は最大 250 件、`created_at` 降順）。
`song_id` を指定した場合は曲ごとのコメント一覧を返す。

新規作成・更新では `song_id` に数値の MusicKit / Apple Music / iTunes ID だけを受け付けるが、GET は既存データ互換のため `ここのっか-ここのっか` のような legacy slug も検索できる。legacy ドキュメントは canonical ID がない場合に限り、レスポンスの `song_id` へ保存済み slug を返す。

**レスポンス**

```json
{
  "howCards": [
    {
      "id": "card456",
      "comment": "...",
      "song_start": 78.4,
      "song_end": 84.2,
      "song_id": "1704093812",
      "itunes_id": "1704093812",
      "song_slug": "ado-show",
      "song_title": "Show",
      "artist_name": "Ado",
      "artist_id": "ado",
      "user_id": "uid123",
      "user_name": "Atsushi",
      "likes": 3,
      "reply_count": 2
    }
  ]
}
```

`user_name` は `users/{user_id}.display_name` から Admin SDK で参照した表示用フィールド。メールアドレスなどの user 詳細は返さない。

### `GET /how-cards/:id/replies`

Howカードに付いた返信を `created_at` 昇順で返す。`limit` は 1〜100。未指定時は 50 件。

```json
{
  "replies": [
    {
      "id": "reply123",
      "how_card_id": "card456",
      "body": "その聴き方わかる",
      "user_id": "uid123",
      "user_name": "Atsushi",
      "created_at": "2026-05-26T12:00:00.000Z",
      "updated_at": null
    }
  ]
}
```

### `POST /how-cards/:id/replies`

Howカードに返信を作成する。本文は 1〜180 文字。親 Howカードの `reply_count` を transaction で更新する。

```json
{ "body": "ここの声の掠れ方、同じところで止まりました" }
```

```json
{
  "reply": {
    "id": "reply123",
    "how_card_id": "card456",
    "body": "ここの声の掠れ方、同じところで止まりました",
    "user_id": "uid123",
    "user_name": "Atsushi",
    "created_at": null,
    "updated_at": null
  },
  "reply_count": 3
}
```

### `GET /recommended-comments`

Home dashboard 向けのおすすめ Howカードコメント一覧を返す。`created_at` が新しいコメントと `likes` が多いコメントから候補を取り、Functions 側でスコアリングして混ぜる。

`limit` は 1〜50。未指定時は 12 件。

**レスポンス**

```json
{
  "comments": [
    {
      "id": "card456",
      "comment": "...",
      "song_start": 78.4,
      "song_end": 84.2,
      "song_id": "1704093812",
      "itunes_id": "1704093812",
      "song_slug": "ado-show",
      "artist_id": "ado",
      "user_id": "uid123",
      "user_name": "Atsushi",
      "likes": 12,
      "created_at": "2026-05-25T12:00:00.000Z"
    }
  ]
}
```

### `POST /how-cards/:id/like`

カードに「いいね」を付ける。冪等（同じユーザーが何度叩いても 1 件のみカウント）。

**レスポンス**

```json
{ "likes": 4 }
```

**動作:**

- `how-cards/{id}/liked-by/{uid}` の存在を確認
- 未いいねなら: `liked-by/{uid}` 作成 + `likes` を +1
- 既いいねなら: ノーオペ（現在の `likes` を返す）

### `GET /users/me` / `PUT /users/me`

`onUserSignup` で自動生成された `users/{uid}` を取得・追加同期する。
現行 iOS では起動時や Howカード読み込み時の users seed は行わない。ユーザー情報の作成・更新は Auth トリガーと `PUT /users/me` に寄せ、iOS は必要に応じて自分自身の `users/{uid}` を読み取るだけにする。
`PUT /users/me` では ID トークンのメールアドレスを正とし、body の `email` が異なる場合は 400 を返す。ID トークンにメールアドレスがない場合は `null` として保存する。

**リクエスト**

```json
{
  "email": null,
  "display_name": "Atsushi"
}
```

---

## Firestore スキーマ

```text
users/{uid}
  user_id: string
  email: string | null
  display_name: string | null
  created_at: timestamp
  updated_at: timestamp

how-cards/{cardId}
  comment: string
  song_start: number
  song_end: number
  song_id: string          # 新規は MusicKit / Apple Music / iTunes の数値曲 ID。既存 legacy slug も読み取り互換対象
  itunes_id: string | null # canonical 曲 ID（新規は song_id と同じ値）
  song_slug: string | null # 表示・移行用 slug
  song_title: string | null
  artist_name: string | null
  artist_id: string
  user_id: string
  likes: number
  reply_count: number
  created_at: timestamp
  updated_at: timestamp | absent

how-cards/{cardId}/liked-by/{uid}
  user_id: string
  liked_at: timestamp

how-cards/{cardId}/replies/{replyId}
  body: string
  user_id: string
  created_at: timestamp
  updated_at: timestamp | absent
```

### `song_id` 契約と migration

`POST /how-cards` と `PATCH /how-cards/:id` の `song_id` は MusicKit の catalog song ID として iOS がそのまま解決できる数値文字列だけを受け付ける。
`radwimps-愛にできることはまだあるかい` のような slug / 表示名由来の値は write API では `400` として拒否する。

ただし、既存 Firestore には legacy slug が残っているため、`GET /how-cards` と `GET /how-cards?song_id=...` は読み取り互換として legacy slug のドキュメントも返す。MusicKit metadata を解決できる `itunes_id` がある場合は `itunes_id` を canonical ID として返し、ない場合は保存済み `song_id` を表示・検索用 ID として返す。

既存データに slug が残っている場合は migration script を使う。デフォルトは dry-run:

```powershell
cd functions
npm run migrate:how-card-song-ids
npm run migrate:how-card-song-ids -- --write
```

既知の legacy slug は `song_slug` に退避し、`song_id` を MusicKit ID に置換する。

---

## 既知の注意点

### URL パスの prefix

Functions v2 では、エクスポート名 `api` がパスに含まれる可能性がある:

- 現状動作確認済み: `https://...cloudfunctions.net/api/health` → Express は `/health` として正しく受信する
- 万一 Express が `/api/health` として受信し始めた場合は `app.js` で `app.use('/api', ...)` マウントに変更が必要

### v1 と v2 の混在

`index.js` で `firebase-functions/v2/https` の `onRequest` と `firebase-functions/v1` の `auth.user().onCreate` を併用している。これは Firebase が公式に許容しているパターン（v2 の Auth トリガーは blocking 専用なので、非同期処理を後追いで走らせたいケースでは v1 を使う）。

---

## ローカル開発

本番 API の変更はこの `functions/` を正とする。旧 `../backend/` は deprecated な参照実装であり、編集しても本番 deploy には反映されない。

Functions emulator を使う場合:

```powershell
cd functions
npm install
npx firebase-tools emulators:start --only functions,firestore
```

---

## Resonance デモ用シードデータ投入

`scripts/seed-resonance.js` は Resonance マッチングのデモ用データを Firestore に投入します。
1 台の実機のみで🔥同地点マッチを体験できるようになります。

### 前提条件

- Node.js 18 以上
- Firebase Admin SDK（`npm install`）
- サービスアカウントキー（`serviceAccountKey.json`）

### サービスアカウントキーの取得

1. [Firebase Console](https://console.firebase.google.com/) → プロジェクト設定 → サービスアカウント
2. 「新しい秘密鍵を生成」をクリック
3. ダウンロードした JSON を `functions/serviceAccountKey.json` に配置する（`.gitignore` 対象）

### 実行手順

```bash
cd functions
npm install

# dry-run（書き込みなし・内容確認）
node scripts/seed-resonance.js

# 実際に投入
GOOGLE_APPLICATION_CREDENTIALS=serviceAccountKey.json node scripts/seed-resonance.js --write
```

### 投入されるデータ

- デモユーザー 3 名（あおい・れん・みお）
- HowCard 5 件（20s / 44s / 77s / 116s / 158s）
- 曲 ID: `howtune-demo-song`（アプリ内 `ResonanceDemo.songId` と一致）

アプリで HowChat フロー（ホーム画面 → AirPods 反応検出 → HowChat）を使い、
`howtune-demo-song` に紐づく HowCard を投稿すると Resonance 画面に🔥マッチが表示されます。
