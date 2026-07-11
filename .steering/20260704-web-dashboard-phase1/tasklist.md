# タスクリスト

> 注: 本 steering は実装後にプロセス整合のため記録（retroactive）。全タスク完了済み。

## フェーズ1: 雛形と Firebase 初期化

- [x] `web/` に Next.js（App Router）+ TypeScript の雛形
- [x] `package.json` / `tsconfig.json` / `next.config.mjs`
- [x] `.env.local(.example)` に Firebase Web 設定（クライアント公開値）
- [x] `src/lib/firebase.ts`（Auth / Firestore 初期化、二重初期化ガード）

## フェーズ2: 認証

- [x] `src/app/page.tsx` で `onAuthStateChanged` 認証ゲート
- [x] `src/components/LoginForm.tsx`（メール/パスワードログイン）
- [x] iOS と同じアカウントでログインできることを設計上担保

## フェーズ3: How カード表示

- [x] `src/lib/howCards.ts`（`where user_id==uid` 直読み、クライアントソート、型定義）
- [x] `src/components/Dashboard.tsx`（一覧・サマリ・ログアウト）
- [x] `globals.css`（ブランド赤 + prefers-color-scheme でライト/ダーク追従）

## フェーズ4: 検証とドキュメント

- [x] `npm install` 成功
- [x] `npm run build`（型チェック含む）通過
- [x] dev サーバー起動・HTTP 200・ページ配信を確認
- [x] `web/README.md`（セットアップ手順）
- [x] `docs/adr/0007-read-only-web-dashboard.md`（アーキテクチャ決定）

---

## 実装後の振り返り

### 実装完了日

2026-07-04

### 計画と実績の差分

- 当初は steering を先に書く運用だが、今回は先に実装 → 後追いで steering/ADR を整備した（プロセス的には要改善）。
- `where + orderBy` の複合インデックスを避けるため、並べ替えをクライアント側にした（インデックス設定不要で MVP を早く動かせる）。
- Firebase Web 設定は iOS の `GoogleService-Info.plist` の公開値をそのまま流用でき、Web アプリ登録なしで Auth/Firestore が動くことを確認。

### 学んだこと

- Firebase の web config（apiKey 等）はクライアント公開値で、appId を省いても Auth/Firestore は動く。
- Next.js の client component は SSR で初期状態（読み込み中）を描画し、Firebase 呼び出しは useEffect でクライアント実行される。

### 次回への改善提案

- 次フェーズ（Phase 2 集計）は steering を先に書いてから着手する。
- リアルタイム化（onSnapshot）とデプロイ（Firebase Hosting）は別タスクに分ける。
