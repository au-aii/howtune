# 設計書

承認済みプラン（`~/.claude/plans/elegant-fluttering-kernighan.md`）の要約。詳細はそちら。

## アーキテクチャ

```
iOS: how-card 作成時に tags を送信（ReactionEvent 由来）
  → Functions(api): tags を検証して how-cards に保存
  → Firestore トリガー onHowCardWritten: 該当曲を再集計
     → song_insights/{songId}（匿名・前計算）に保存
  → Web: song_insights を直読みしてヒートマップ＋タグ表示
```

## コンポーネント

### iOS（タグ保存）

- `Models/HowCardComment.swift`：`tags: [HowTag]` 追加（CodingKeys/encode/decode）。
- `Services/HowCardCommentPayload.swift`：`tags: [String]`（rawValue）を送信。
- 作成経路 `HowCardCreationView`（selectedTags）/ `ClipCreationViewModel` / `LyricHowCardComposerView` で tags を載せる。

### Functions（保存＋集計）

- `routes/how-cards.js`：body の `tags` を既知 HowTag の部分集合に検証（上限6）。
- `repositories/firestore.js`：createHowCard/updateHowCard で `tags` 保存。
- `index.js`：v2 `onDocumentWritten('how-cards/{cardId}')` トリガー追加。
- `repositories/insights.js`（新規）`recomputeSongInsights(songId)`：
  - distinct user_id=reactor_count、<5 なら doc 削除。
  - 密度：0〜max(song_end) を約5秒バケット、区間重なりの distinct user_id 数、<5 バケットは伏せる。
  - タグ：card.tags（無ければコメント推測フォールバック）を集計。
  - `song_insights/{songId}` = `{ song_id, reactor_count, density:[{t,count}], tags:{…}, updated_at }`。

### rules

- `firestore.rules`：`song_insights` は `read: if isSignedIn()` / `write: if false`。

### Web

- `web/src/lib/songInsights.ts`（新規）：直読み＋型。
- `web/src/components/SongInsight.tsx`（新規）：密度ヒートマップ＋タグ棒。
- `web/src/components/Dashboard.tsx`：曲選択→インサイト表示。

## 匿名化（k=5）

- 曲レベル（reactor_count≥5）＋区間レベル（各バケット≥5）の両方で抑制。user_id は song_insights に一切含めない。

## 検証

- Functions: emulator でトリガー確認 / iOS: xcodebuild green / Web: npm run build / E2E: 5人以上 seed → 表示確認。
