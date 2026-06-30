# タスクリスト — Resonance Phase 1 & README 個人化

> 1タスク = 1〜2時間で完了できる粒度
> ブランチ: feat/how-resonance

## ステータス凡例

- [ ] 未着手
- [x] 完了

---

## タスク

### Phase 1: README 個人化

- [ ] T1: README からハッカソン固有セクションを削除する
  - 対象: チームメンバー表・提出ステータス・提出物チェックリスト・審査観点・担当メンター壁打ち履歴・運営連絡先・公開許諾
  - 1行ピッチ・スクリーンショット・デモ動画リンク・技術スタックは維持する

- [ ] T2: README に「個人プロジェクトとして継続」の前書きと Firebase 切り替え手順を追加する
  - Apple Developer Program なし（TestFlight 不可・実機署名のみ）の注記
  - `ENV.plist` + `GoogleService-Info.plist` の差し替えで Firebase プロジェクトを切り替えられることを明記
  - `docs/setup.md` へのリンクを維持する

### Phase 2: Resonance 待機アニメーション改善

- [ ] T3: `ResonanceMatchView` の待機中アニメーションをループさせる
  - `@State private var pulseEpoch: Date = Date()` を追加
  - `hasSameSpot == false` のとき `QuantumIgnitionView(startDate: pulseEpoch)` を渡す
  - `cycleDuration`（2.6秒）ごとに `pulseEpoch = Date()` を更新するループを実装する
    - 実装案: `task` + `while !Task.isCancelled` ループ か `.onAppear` + `Timer`
  - `hasSameSpot == true` になったとき `ignitionStart` に切り替える現行ロジックはそのまま維持する
  - 動作確認: Xcode Preview または実機で待機中に粒子がゆらぎ続けることを確認する

### Phase 3: NowPlaying 歌詞フローへの Resonance 導線追加

- [ ] T4: `LyricHowCardComposerView` の投稿完了 UI に Resonance 誘導ボタンを追加する
  - `@State private var showResonance = false` を追加
  - `didPost == true` 状態で「共鳴した人を見る」ボタンを表示する（`HowCardCreationView.postedOverlay` を参考にする）
  - `.fullScreenCover(isPresented: $showResonance)` で `ResonanceMatchView` を呈示する
    - `songId`: `song.firestoreSongID`
    - `songTitle`: `song.title`
    - `myInterval`: `(draft.songStart, draft.songEnd)`
  - 動作確認: 歌詞タップ → コメント入力 → 投稿 → ボタンタップ → Resonance 画面が開くことを確認する

### Phase 4: デモ動作確認

- [ ] T5: シードデータを Firebase に投入してデモループを通しで確認する
  - 前提: `functions/scripts/seed-resonance.js` の dry-run で出力を確認する（`node scripts/seed-resonance.js`）
  - `--write` オプションで実際に投入する（`GOOGLE_APPLICATION_CREDENTIALS=serviceAccountKey.json node scripts/seed-resonance.js --write`）
  - アプリで HowChat フロー（`HowCardCreationView`）から `howtune-demo-song` を使い Resonance 画面に到達する
  - 🔥同地点マッチが表示されることを確認する
  - マッチ行をタップして DM 画面に入り、メッセージを送信できることを確認する

- [ ] T6: シードスクリプトの実行手順を `docs/resonance-phase1/` または `functions/README.md` に追記する
  - 新しい Firebase プロジェクトへの切り替え後に seed を再投入する手順を記載する
  - `serviceAccountKey.json` の取得方法（Firebase Console → プロジェクト設定 → サービスアカウント）を記載する
