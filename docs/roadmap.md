# HowTune ロードマップ / バックログ

「次に何をやるか」の**単一の入り口**。詳細は各 ADR / steering / issue へリンク。

最終更新: 2026-07-04

## 現在地

- **iOS**: ダーク/ライトの OS ネイティブ追従 完了（PR #7 マージ済み）
- **Web ダッシュボード**: Phase 1（本人向け・Firestore 直読み）完了 → ブランチ `feat/web-dashboard-phase1`

## ✅ 完了

- [x] ダーク/ライト OS ネイティブ追従（steering: `20260704-adaptive-color-scheme`）
- [x] Web ダッシュボード Phase 1（ADR-0007 / steering: `20260704-web-dashboard-phase1`）

## ⬜ 次にやること（優先度順）

### Web ダッシュボード（ブランチ `feat/web-dashboard-phase1`）

- [x] Phase 1（本人の How カード一覧・Firestore 直読み）
- [x] **Firebase Hosting デプロイ** → https://howtune-74252.web.app
- [x] **Phase 2**: `song_insights` 集計（密度＝How カード区間 / **推定タグ** / k=5）＋Web 表示 ※集計トリガーは functions デプロイで有効化
- [ ] personal 内で PR → マージ（Phase 1+2）
- [ ] **生 ReactionEvent 保存で「本物の反応密度＋タグ」に（moat）** → [issue #112](https://github.com/engineer-guild-hackathon-2026-05/team-10/issues/112)
- [ ] **Phase 3**: アーティスト認証・曲所有権・反応ヒートマップ（B2B インサイト）

### iOS 小物

- [ ] 一時ログアウトボタン → 正式な設定画面のログアウトに昇格
- [ ] 実機（iPhone + AirPods）での最終確認

### ドキュメント整備

- [x] ダーク/ライト対応を ADR 化（`docs/adr/0008-adaptive-color-scheme.md`）
- [ ] PRD / `architecture.md` / `repository-structure.md` に `web/` を新サーフェスとして追記

## 💡 アイデア（将来）

- Spotify 連携（[issue #110](https://github.com/engineer-guild-hackathon-2026-05/team-10/issues/110)）

## 📁 記録の置き場所（どこに何を書くか）

| 種類                 | 置き場所                                                         |
| -------------------- | ---------------------------------------------------------------- |
| アーキテクチャ決定   | `docs/adr/NNNN-*.md`                                             |
| 機能ごとの設計・進捗 | `.steering/YYYYMMDD-機能名/`（requirements / design / tasklist） |
| 戦略・全体像         | `docs/*.md`, `docs/*.html`                                       |
| プロダクト要求       | `docs/product-requirements.md`（PRD）                            |
| アイデア             | GitHub issue（チームリポジトリ側）                               |
| 次にやること全体     | **このファイル（`docs/roadmap.md`）**                            |
