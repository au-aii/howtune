# 設計書

## アーキテクチャ概要

**システムセマンティックカラー中心 + ブランド色固定** のハイブリッド。新規アセットカタログは作らず、iOS 標準の semantic color（`Color(.systemBackground)` / `Color(.label)` 等）へ置換する。ブランド色（アクセント赤・グラデーション・HowTag）は固定値のまま維持する。

```
汎用色（背景/文字/副次/境界/サーフェス） → システムセマンティックカラー（OS 追従）
ブランド色（accent赤/gradient/HowTag 7色）  → 固定値のまま（両モードで不変）
テーマ制御（preferredColorScheme）          → themePreference enum で system/light/dark
```

## コンポーネント設計

### 1. HowTuneDesign（トークン中核）

`Othello/Views/Onboarding/OnboardingComponents.swift`

**責務**: 全画面共通の色トークンを供給する。

**実装の要点**:

- `background = Color.black` → `Color(.systemBackground)`
- `surface = Color.white.opacity(0.06)` → `Color(.secondarySystemBackground)`
- `divider = Color.gray.opacity(0.3)` → `Color(.separator)`
- `accent` / `accentGradient` は **変更しない**（ブランド赤）
- `primaryButton` のグラデーション上の `.white` 文字は **固定のまま**

### 2. テーマ設定（OS 追従）

`Othello/OthelloApp.swift`, `Othello/Views/ForYou/ForYouView.swift`

**責務**: OS 外観に追従しつつ手動上書きも可能にする。

**実装の要点**:

- `@AppStorage("prefersDarkTheme") var prefersDarkTheme: Bool` → `themePreference`（`system`/`light`/`dark`、デフォルト `system`）
- `system` のとき `.preferredColorScheme(nil)`＝OS 追従
- ForYou トグルは 3 状態循環（アイコン: `circle.lefthalf.filled`/`sun.max.fill`/`moon.fill`）
- `prefersDarkTheme` 参照箇所を漏れなく更新

### 3. 全画面カラー置換

54 ファイルを機能グループ（G1〜G8）に分割し、**dev-agent を並列バックグラウンド実行**。ファイル非重複で編集衝突なし。

## データフロー

### 置換ルール適用

```
1. 各ファイルのハードコード色を検出
2. 置換ルール表に照合（背景/文字/副次/塗り/境界）
3. 置換禁止リスト（アクセント赤・グラデーション内・赤地の白文字）を除外
4. セマンティックカラーへ置換
```

## 置換ルール表

| 現在のパターン                              | 置換先                                  |
| ------------------------------------------- | --------------------------------------- |
| `Color.black`（背景）                       | `Color(.systemBackground)`              |
| `.white`（主要文字・アイコン）              | `Color(.label)`                         |
| `.gray`（副次文字）                         | `Color(.secondaryLabel)`                |
| `.white.opacity(0.30–0.45)`（弱文字）       | `Color(.tertiaryLabel)`                 |
| `.white.opacity(0.45–0.65)`（副次文字）     | `Color(.secondaryLabel)`                |
| `.white.opacity(0.03–0.15)`（塗り・カード） | `Color(.secondarySystemBackground)`     |
| `.white.opacity(0.08–0.14)`（境界線）       | `Color(.separator)`                     |
| `.gray.opacity(0.2–0.3)`（境界線）          | `Color(.systemGray4)`                   |
| アクセント赤の重複定義                      | `HowTuneDesign.accent` に統一（値不変） |

## 置換禁止（そのまま維持）

- アクセント赤 `Color(red:1.0,green:0.3,blue:0.3)` の**色値**
- `accentGradient` などグラデーション内の色
- `HowTag` の 7 色（`Models/HowTag.swift`）
- アクセント/グラデーション背景の上の `.white` 文字（赤地に白が正しい）

## テスト戦略

### ビルド検証

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Othello.xcodeproj -scheme Othello -destination 'generic/platform=iOS Simulator' build`

### 目視検証（ライト/ダーク）

- `xcrun simctl ui booted appearance light` / `dark` で切替
- 主要4画面（Login / ForYou / NowPlaying / MusicFeed）のスクショ比較

## ディレクトリ構造

```
変更: Othello/Views/Onboarding/OnboardingComponents.swift  # トークン
変更: Othello/OthelloApp.swift, Othello/Views/ForYou/ForYouView.swift  # テーマ
変更: G1〜G8 の 54 ファイル  # 一括置換
不変: Othello/Models/HowTag.swift  # 置換禁止の参照
```

## 実装の順序

1. HowTuneDesign トークンをアダプティブ化（先行）
2. OthelloApp / ForYouView のテーマ設定を OS 追従に
3. 全画面のハードコード色を機能グループ単位で並列置換
4. ライト/ダーク両方でビルド＆スクショ検証、崩れを補正

## セキュリティ考慮事項

- なし（表示のみの変更。API・認証・データに影響しない）

## パフォーマンス考慮事項

- セマンティックカラーは iOS 標準で軽量。パフォーマンス影響なし。

## 将来の拡張性

- 将来ブランド専用のライト色味を作り込む場合は、アセットカタログに colorset を足して `HowTuneDesign` の参照先を差し替えるだけで拡張可能。
