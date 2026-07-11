# 設計書

## アーキテクチャ概要

**Next.js（App Router）+ Firebase JS SDK のクライアントサイド構成。** 既存 Firebase に読み取りクライアントを足すだけ（ADR-0007）。

```
[ブラウザ]
  Next.js (App Router, 'use client')
    ├─ Firebase Auth ─────────→ 同じ Firebase プロジェクト(howtune-74252)
    └─ Firestore 直読み ───────→ how-cards (user_id == 自分)
```

## コンポーネント設計

### 1. `src/lib/firebase.ts`

**責務**: Firebase 初期化（Auth / Firestore のエクスポート）。
**要点**: `NEXT_PUBLIC_FIREBASE_*`（クライアント公開値）から config を構築。`getApps()` で二重初期化を防ぐ。

### 2. `src/lib/howCards.ts`

**責務**: `how-cards` の直読みと型定義。
**要点**: `where("user_id","==",uid)` で取得。`where + orderBy` は複合インデックスが要るため、**並べ替えはクライアント側**で `createdAt` 降順。`formatRange` で反応区間を整形。

### 3. `src/app/page.tsx`（認証ゲート）

**責務**: `onAuthStateChanged` でログイン状態を監視し、未ログイン→`LoginForm` / ログイン済み→`Dashboard` を出し分け。

### 4. `src/components/LoginForm.tsx`

**責務**: メール/パスワードで `signInWithEmailAndPassword`。

### 5. `src/components/Dashboard.tsx`

**責務**: `fetchMyHowCards(uid)` で一覧取得、サマリ（件数・総いいね）とカード一覧を表示、ログアウト。

## データフロー

### 本人の How カード表示

```
1. onAuthStateChanged で user を取得
2. user.uid で fetchMyHowCards() → Firestore how-cards を where(user_id==uid) で取得
3. クライアントで createdAt 降順ソート
4. 件数・総いいねを算出して表示
```

## セキュリティ考慮事項

- `firestore.rules` の `how-cards: read if isSignedIn()` を利用。`user_id` で本人分に絞る（他人の read も技術上は可能だが、UI は自分の uid のみ問い合わせる）。
- `NEXT_PUBLIC_FIREBASE_*` は Firebase のクライアント公開値（秘密ではない）。`.env.local` は慣習に従い gitignore、`.env.local.example` を配布。

## テスト戦略

- `npm run build`（コンパイル + 型チェック + 静的生成）
- dev サーバー起動 → HTTP 200 とページ配信を確認
- 実データ確認（手動）: iOS と同じアカウントでログイン → 自分の how-cards が出る

## ディレクトリ構造

```
web/
  package.json / next.config.mjs / tsconfig.json
  .env.local(.example)
  src/
    lib/firebase.ts, howCards.ts
    app/layout.tsx, page.tsx, globals.css
    components/LoginForm.tsx, Dashboard.tsx
  README.md
```

## 実装の順序

1. 雛形＋Firebase 初期化
2. 認証ゲート＋ログインフォーム
3. how-cards 直読み＋一覧表示
4. ビルド・起動検証

## 将来の拡張性

- Phase 2: `onSnapshot` でリアルタイム化、Cloud Functions で `song_insights` 集計。
- Phase 3: アーティスト認証・曲所有権・ヒートマップ（B2B）。
