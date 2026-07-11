# HowTune Dashboard（Web ダッシュボード Phase 1）

iOS アプリで記録した **自分の How カード**を Web で振り返るダッシュボード。
既存の Firebase（`howtune-74252`）を単一の真実の源にして、**読み取り専用**で可視化する。

- **フレームワーク**: Next.js（App Router）+ TypeScript
- **認証**: Firebase Auth（iOS アプリと同じアカウント）
- **データ**: Firestore を**直読み**（`how-cards` を `user_id == 自分` で取得）

> 設計の全体像は [`../docs/web-dashboard-architecture.html`](../docs/web-dashboard-architecture.html) を参照。

## セットアップ

```bash
cd web
cp .env.local.example .env.local   # 既に .env.local があれば不要
npm install
npm run dev
```

→ http://localhost:3000 を開く。iOS アプリと同じメール/パスワードでログイン。

## 現状（Phase 1）

- [x] Firebase Auth でログイン
- [x] 自分の How カード一覧を Firestore 直読みで表示
- [x] 件数・総いいね数のサマリ
- [ ] （Phase 2）Cloud Functions で `song_insights` 集計 → 曲ごとの反応ヒートマップ
- [ ] （Phase 3）アーティスト向け B2B インサイト

## メモ

- Firebase の Web 設定値（`NEXT_PUBLIC_FIREBASE_*`）は iOS の `GoogleService-Info.plist` と同じプロジェクトのクライアント公開値。
- `firestore.rules` は `how-cards` を「ログイン済みなら read 可」にしているので、`user_id` で本人分に絞って取得している。
- `where` + `orderBy` は複合インデックスが要るため、並べ替えはクライアント側で実施。
