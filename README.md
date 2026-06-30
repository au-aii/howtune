# HowTune — Engineer Guild Hackathon 2026/05

> **1行ピッチ**：何を聴くかではなく、どう聴いているかでつながる。音楽が好きで、曲の自分なりの聴き方を持つ人が、同じ聴き方の人とつながる iOS アプリ。

> **個人継続プロジェクト**: ハッカソン終了後、ソロで開発を継続しています。

## スクリーンショット

<!-- README先頭の見栄え兼SNS素材。Day2 終了までに最低1枚は貼る -->

<img width="750" height="424" alt="image" src="https://github.com/user-attachments/assets/c47cee68-2fb9-47ce-8dd6-3e7ad4c3db8d" />

## プロダクト概要

既存の音楽サービスは「何を聴くか（What）」でつながる。しかし熱狂が本当に伝わるのは「どう聴いているか（How）」が共有されたときだ。HowTune は 歌詞や区間に対するコメントを「Howカード」として可視化。曲やジャンルではなく、**同じ聴き方をしている人**との出会いを生み出す。

### 解決したい課題

同じような音楽の聴き方をしている人となかなか出会えない。

### ターゲットユーザー

- 音楽が好きなリスナー
- 自分の聴き方を発信し、近い価値観の人とつながりたい人

## デモ・関連リンク

| 種別                      | URL                                                                                                                                                                |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| デモ（実機 / TestFlight） | https://testflight.apple.com/join/mK7WXTJT                                                                                                                         |
| プレゼン資料              | [https://canva.link/g7eobtoh0v7zu0z](https://canva.link/g7eobtoh0v7zu0z)                                                                                           |
| デモ動画                  | [https://youtube.com/shorts/YGX9DLsSwg4](https://youtube.com/shorts/YGX9DLsSwg4), [https://youtube.com/shorts/t9B-z5PbwYY](https://youtube.com/shorts/t9B-z5PbwYY) |
| 仕様書（source of truth） | [`docs`](./docs)                                                                                                                                                   |

## 技術スタック

- **iOS アプリ（`Othello/`）**：Swift / SwiftUI（Xcode）
- **センサー**：CMHeadphoneMotionManager（AirPods 頭部）
- **音楽再生**：MusicKit
- **ML（`ai-recognition/`）**：TensorFlow で学習 → Core ML に変換し端末推論
- **バックエンド（`functions/`）**：Firebase Cloud Functions v2 + Express + Firestore Admin SDK
- **AI 対話**：HowChat に mock/legacy client が残る。Functions 本番 contract には未接続
- **データ**：Firestore
- **利用 AI ツール**：Codex / Claude Code

### 使用した外部 API / サービス

| サービス名     | 用途                           | プラン             | 備考                                       |
| -------------- | ------------------------------ | ------------------ | ------------------------------------------ |
| Apple MusicKit | 楽曲情報・再生位置取得         | サブスクリプション | AppleMusicのサブスクリプションが必要       |
| Musixmatch     | 時間同期歌詞または静的歌詞取得 | 要 API key         | `ENV.plist` の `MUSIXMATCH_API_KEY` に設定 |

→ API キー・秘匿情報は `.env` / `ENV.plist`（`.gitignore` 対象）で管理し、git に含めない。

### MusicKit / Musixmatch 連携メモ

- MusicKit の `Song` から曲名・アーティスト名・アルバム名・ISRC・曲長を取り出し、Musixmatch の照合に使う。
- Musixmatch の `matcher.track.get` で `track_id` を解決し、`track.subtitle.get` で LRC 形式の時間同期歌詞を試す。
- 同期歌詞が取得できない場合は `track.lyrics.get` の静的歌詞へ fallback する。実機検証では Xcode コンソールの `[MusixmatchLyricsProvider]` ログで `status` / `hint` / 試行した ID を確認する。
- Spotify Web API は MVP では使用しない。

## リポジトリ構成

```
team-10/
├── Othello/          # iOS ネイティブアプリ（Xcode / SwiftUI）
├── functions/        # Firebase Functions（本番 API）
├── backend/          # 旧 Express 実装（deprecated / 参照用）
├── ai-recognition/   # AIモデル（TensorFlow 学習 → Core ML 変換）
├── frontend/         # フロントエンド置き場（LP/管理画面・MVP未使用）
└── docs/             # ドキュメント（仕様は docs/frontend-spec.md が正）
```

## セットアップ

詳細な手順は **[`docs/setup.md`](./docs/setup.md)** を参照してください。

> 本番 API は Firebase Functions にデプロイ済みです。通常の実機確認ではローカル backend の起動は不要です。

```bash
cp Othello/Othello/ENV.example.plist Othello/Othello/ENV.plist
# API_BASE_URL と MUSIXMATCH_API_KEY を設定
```

`.env` に必要なキー：

| 変数名               | 説明                 |
| -------------------- | -------------------- |
| `API_BASE_URL`       | Functions API の URL |
| `MUSIXMATCH_API_KEY` | Musixmatch API キー  |

### 2. iOS アプリを起動する

```bash
# リポジトリのクローン
git clone https://github.com/engineer-guild-hackathon-2026-05/team-10.git
cd team-10

# iOS アプリを Xcode で開く
open Othello/Othello.xcodeproj
# 署名チームを設定し、実機（iPhone）を選んで Run
```

- **実機必須**：AirPods の頭部モーションはシミュレータで取得できません（iPhone + 対応 AirPods が必要）
- **権限**：`Info.plist` に `NSMotionUsageDescription` が必要
- **MusicKit**：Apple Developer の App ID で MusicKit App Service を有効化し、プロビジョニングプロファイルを更新してから実機ビルドする
- **Musixmatch**：`Othello/Othello/ENV.example.plist` を `ENV.plist` にコピーし、`MUSIXMATCH_API_KEY` を設定する。`matcher.track.get` と `track.lyrics.get` が 401/402/403 を返す場合は API key・利用上限・契約プランを確認する

### Firebase プロジェクトの切り替え

1. Firebase Console で新しいプロジェクトを作成する
2. iOS アプリを追加し `GoogleService-Info.plist` をダウンロードして `Othello/Othello/` に配置する
3. `Othello/Othello/ENV.plist` の `API_BASE_URL` を新しい Cloud Functions のエンドポイントに書き換える
4. `functions/scripts/seed-resonance.js` を実行してデモ用データを投入する（詳細: `docs/resonance-phase1/`）

> **Note**: Apple Developer Program に未加入のため TestFlight 配布は不可。Xcode から直接実機にインストールして動作確認してください。

## ドキュメント

| ファイル                                                             | 内容                                                 |
| -------------------------------------------------------------------- | ---------------------------------------------------- |
| [`docs/frontend-spec.md`](./docs/frontend-spec.md)                   | **仕様の source of truth**（Notion ミラー、SDD）     |
| [`docs/product-requirements.md`](./docs/product-requirements.md)     | プロダクト要求定義（PRD）                            |
| [`docs/architecture.md`](./docs/architecture.md)                     | アーキテクチャ設計                                   |
| [`docs/functional-design.md`](./docs/functional-design.md)           | 機能設計                                             |
| [`docs/setup.md`](./docs/setup.md)                                   | ローカル開発環境のセットアップ手順                   |
| [`docs/data-model.md`](./docs/data-model.md)                         | データモデル設計（Firestore スキーマ・反応区間構造） |
| [`docs/repository-structure.md`](./docs/repository-structure.md)     | リポジトリ構造                                       |
| [`docs/development-guidelines.md`](./docs/development-guidelines.md) | 開発ガイドライン                                     |
| [`docs/glossary.md`](./docs/glossary.md)                             | 用語集                                               |

> Notion は git からの一方向ミラーです。**仕様の編集は git 側（`docs/`）で行ってください。**
