# 要求内容

## 概要

アプリ全体のダーク/ライト表示を **iOS の OS 外観設定にネイティブ追従**させる。現状ダークテーマ強制でハードコードされた色を、システムセマンティックカラーへ全面置換する。

## 背景

- 発端は autofill パスワード文字が黒背景に黒で見えない不具合。根本原因は色のハードコード。
- 現状 `OthelloApp` の `.preferredColorScheme(.dark)` 強制と、**54 ファイル・約 260 箇所**の `Color.black`（背景）/ `.white`（文字）ハードコードにより、OS の外観設定（ライト/ダーク）に一切追従しない。
- アダプティブカラー（colorset）は実質未定義（`AccentColor` のみ・空）。
- ユーザー要望：「OS にネイティブ追従する形でダーク/ライト両対応を今すぐ全面一括で」。

## 実装対象の機能

### 1. カラートークンのアダプティブ化

- `HowTuneDesign` の `background` / `surface` / `divider` をシステムセマンティックカラーに変更。
- これを参照する画面が自動で OS 追従する。

### 2. OS 外観への追従

- `.preferredColorScheme` の強制をやめ、テーマ設定（`system` / `light` / `dark`）に応じて追従。デフォルト `system`。
- `ForYouView` の手動トグルを 3 状態循環に発展。

### 3. 全画面のハードコード色を一括置換

- 54 ファイル・約 260 箇所を置換ルールに従いセマンティックカラー化。
- ブランド色（アクセント赤・グラデーション・HowTag 7色）は固定維持。

## 受け入れ条件

### カラートークン / OS 追従

- [ ] `HowTuneDesign.background` などがアダプティブになっている
- [ ] `.preferredColorScheme` がテーマ設定に応じ `nil`(system)/`.light`/`.dark` を返す
- [ ] ForYou のトグルで system→light→dark→system を循環できる

### 全画面置換

- [ ] ライトモードで背景が白・文字が黒になり読める（黒地に黒／白地に白が消えている）
- [ ] ダークモードで従来の見た目が保たれている
- [ ] アクセント赤・グラデーション・HowTag 色が両モードで維持されている
- [ ] アクセント/グラデーション背景の上の白文字が保たれている
- [ ] Xcode ビルドが green（`BUILD SUCCEEDED`）

## 成功指標

- ライト/ダーク両方でスクショを撮り、主要4画面（Login / ForYou / NowPlaying / MusicFeed）が破綻なく表示される。
- 追従が iOS の「設定 > 画面表示と明るさ」に連動する。

## スコープ外

以下はこのフェーズでは実装しません:

- 完璧なライト専用デザインの作り込み（微妙な opacity・グラデーションの再設計は検証時の補正に留める）
- 新規アセットカタログ（colorset）の大量作成（システムセマンティックカラー中心で対応）
- テーマ切替の凝った設定 UI（3状態トグルのみ）
- HowTag 色のアセット化

## 参照ドキュメント

- `docs/architecture.md` - アーキテクチャ設計書
- `docs/development-guidelines.md` - Swift コーディング規約
- `~/.claude/plans/elegant-fluttering-kernighan.md` - 事前調査に基づく実装プラン
