# OVERNIGHT_QUEUE — 自律オーバーナイト実行キュー

> このファイルは **HowTune 残バックログを朝までに自律で片付ける**ためのキュー兼プロトコル。
> 実行方式: **この端末セッションを生かしたまま（`caffeinate` 済み）、`ScheduleWakeup` で budget リセット後に自分を叩き直して継続**する自己再開ループ。
> 取りこぼした時の手動再開: ユーザーが「continue overnight」と打てば、このキューの続きから走る。**文脈ゼロでも実行できるよう自己完結**に書いてある。
> （※ cloud cron の新セッション自動起動は Mac 外の環境しか選べず iOS/ローカル firebase が動かないため不採用）
> 元作戦: `/Users/sunsun/.claude/plans/elegant-fluttering-kernighan.md`

## ループ・プロトコル（各起動でやること）

1. この `OVERNIGHT_QUEUE.md` を読む。
2. **未チェック `[ ]` の最上位タスクを1つだけ**取る（`[blocked]` は飛ばす）。
3. そのタスクの「対象/手順/検証」に従い実装。
4. **検証コマンドが通ってから** `[x]` にする。通らなければ直す。設計判断が必要で決められない時は `[blocked]` にし理由と必要な判断をここに書いて**次のタスクへ**（勝手に決めない）。
5. `AI_USAGE_LOG.md` に1行追記（審査証跡）。
6. feature ブランチに**小さくコミット**（`git log --oneline -1` で確認）。
7. まだ `[ ]` が残っていれば 2 に戻る。budget/時間が続く限り複数タスク消化してよい。
8. **一区切り or budget が尽きそうなターン末で、次の再開のため `ScheduleWakeup` を再設定**する（`delaySeconds` ≈ 3000〜3300＝リセット後に発火、`prompt` = 「continue overnight — read /Users/sunsun/Developer/team-10/OVERNIGHT_QUEUE.md and continue the loop」）。これを毎回やらないとループが止まる。
9. **全タスクが `[x]`/`[blocked]` になったら**、`ScheduleWakeup` を再設定せず、`AI_USAGE_LOG.md` に完了サマリを追記して終了。

## 環境・事実（確認済み）

- repo: `/Users/sunsun/Developer/team-10`
- 作業ブランチ: `feat/web-dashboard-phase1`（Phase1+2＋Node22固定まで済み。最新 `243f92b`）
- remotes: `personal` = `https://github.com/au-aii/howtune.git`（**push はここだけ**）／`origin`(team) は **push 無効化済み・触るな**
- **node は 22 をフルパスで**: `/opt/homebrew/opt/node@22/bin/node` ／ npm: `/opt/homebrew/opt/node@22/bin/npm`（既定 `node`=Homebrew v26 は firebase-admin を gzip で壊す。詳細 `CLAUDE.md`）
- Firebase project: `howtune-74252`（`firebase` CLI は認証済みで動く）
- 次の ADR 番号: **0008**（既存は 0007 まで。※0006 は重複2件あり）
- 参照: `docs/roadmap.md`（バックログ）/ `docs/vision.md`（moat/North Star）/ `docs/adr/0007-read-only-web-dashboard.md` / steering `.steering/20260704-*`

## ガードレール（絶対）

- `main`/`master` へ commit・push **禁止**（`hooks/guard.sh` が物理 block）。作業は必ず feature ブランチ。
- **`origin`（team）へ push 禁止**。push は `personal` のみ。
- **検証してから `[x]`**：web=`npm run build` 成功 / iOS=`xcodebuild ... build` green / functions=`node --check` 等。
- **設計判断を勝手に確定しない**（特に Phase3 認証・所有権・rules）。迷ったら `[blocked]` にして疑問を残す。
- 大物（Phase3/moat 実装）は**自動マージしない**。レビュー用 PR まで。
- コミット末尾に `Co-Authored-By: Claude <noreply@anthropic.com>`。
- 破壊的操作（force-push・履歴改変・大量削除）はしない。
- **並行実行注意**: 本セッションと cron 新セッションが重なりうる。こまめに commit し、`git pull --rebase`（personal）で衝突回避。異なるファイルを触るタスクを優先。

---

## タスクキュー（優先度順・上から実行）

> **ブランチ方針（更新・上書き）**: オーバーナイトの作業は全て **`feat/web-dashboard-phase1` に集約**する（各タスク内の「別ブランチを切る」指示は**無視**）。PR は **#8 (au-aii/howtune)** を umbrella とし、朝にユーザーが **squash-merge** する。個別マージは AI 単独では不可（分類器がブロック）。

### Tier 1 — 低リスク・高価値

- [x] **T1-1: `AI_USAGE_LOG.md` に本日(2026-07-05)分を記録**
  - 対象: `AI_USAGE_LOG.md`（末尾の「## 全体振り返り」より前にエントリ追記、既存フォーマット踏襲）
  - 内容: Firebase データフロー復習 / Web Phase1 デプロイ / Web Phase2（song_insights 集計・k=5・密度・推定タグ・SongInsight.tsx）/ guard.sh の sandbox 無効化ブロック / Node22 固定（volta pin＋.node-version）/ seed の Node26 対応（Firestore uid 解決）
  - 検証: ファイルが壊れず追記されている（目視）
  - ブランチ: `feat/web-dashboard-phase1`

- [x] **T1-2: ダーク/ライト OS 追従を ADR 化**
  - 対象: 新規 `docs/adr/0008-adaptive-color-scheme.md`
  - 元ネタ: steering `.steering/20260704-adaptive-color-scheme/`（requirements/design/tasklist を読んで決定と理由を要約）
  - 内容: 決定＝セマンティックカラー＋`themePreference`(system/light/dark) で OS 追従。ブランド赤/グラデ/HowTag 色/赤地白文字は維持。背景・理由・代替案・結果。
  - 検証: `docs/roadmap.md` の「ダーク/ライト対応を ADR 化」を `[x]` に更新
  - ブランチ: `feat/web-dashboard-phase1`

- [x] **T1-3: `web/` を新サーフェスとして永続ドキュメントに追記**
  - 対象: `docs/architecture.md` / `docs/repository-structure.md` / `docs/product-requirements.md`（該当箇所に web ダッシュボードを追記。Next.js 静的エクスポート→Firebase Hosting、Firestore 直読み＋song_insights、read-only、ADR-0007 参照）
  - 検証: 各ファイル整合（目視）＋ `docs/roadmap.md` の該当項目 `[x]`
  - ブランチ: `feat/web-dashboard-phase1`

- [x] **T1-4: Phase 1+2 を personal で PR 作成**（マージは人間レビュー待ち → `[blocked]`。PR: https://github.com/au-aii/howtune/pull/8）
  - 手順: `git push personal feat/web-dashboard-phase1` → `gh pr create --repo au-aii/howtune --base main --head feat/web-dashboard-phase1 --title "feat: Web ダッシュボード Phase 1+2（本人閲覧＋曲別インサイト）" --body "..."` → CI 無ければ `gh pr merge --repo au-aii/howtune --merge`（or squash）
  - 注意: **personal のみ**。`origin` へは触らない。guard.sh に触れないよう main へ直接は触らず PR 経由。
  - 検証: PR がマージされ personal/main に反映（`gh pr view`）
  - メモ: PR 前に fresh subagent で差分レビュー（`/code-review` 相当）できれば尚可。

### Tier 2 — 中リスク・ブロッカーあり

- [x] **T2-1: 集計トリガー `onHowCardWritten` を本番デプロイ（ライブ集計化）** ✅発火検証済み（追加10→11 / 削除11→10）
  - 対象: `functions/index.js`（既に v1 Firestore トリガー実装済み）を deploy
  - 手順: `cd functions && firebase deploy --only functions:onHowCardWritten,firestore:rules --project howtune-74252`
  - 検証: deploy 成功ログ。成功したら how-card を1件書いて `song_insights` が自動更新されるか確認（`/opt/homebrew/opt/node@22/bin/node scripts/seed-insights.js --write` の後 song_insights が更新）
  - **ブロック時**: Eventarc/PubSub IAM 権限エラー（project owner 必要）なら `[blocked]` にし、下の「ブロック記録」に必要ロール（例 roles/eventarc.admin, roles/pubsub.admin, roles/run.invoker）と `gcloud` 付与コマンド、正確なエラーを残してユーザーに委ねる。**IAM を勝手に変更しない**。

- [x] **T2-2: iOS 一時ログアウト → 設定画面の正式ログアウト** ✅ xcodebuild BUILD SUCCEEDED
  - 対象: iOS（`Othello/`）。まず現状の「一時ログアウトボタン」を grep で特定 → 設定画面（無ければ最小の Settings ビュー）にログアウトを移す
  - 検証: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Othello/Othello.xcodeproj -scheme Othello -destination 'generic/platform=iOS Simulator' build` が green
  - **設計判断が要るなら**（設定画面の構成など）`[blocked]` にして案を2つ残す
  - ブランチ: iOS 変更用に `feat/ios-settings-logout` を新規に切る（web ブランチと混ぜない）

### Tier 3 — 大物・設計優先（潤沢 budget 時）

- [x] **T3-1: moat #112 の設計（実装しない）** ✅ `.steering/20260705-reaction-event-persistence/`（requirements/design/tasklist）。未決3点はユーザー確定待ち
  - 対象: 新規 `.steering/20260705-reaction-event-persistence/`（requirements.md / design.md / tasklist.md）
  - 内容: 生 `ReactionEvent`/モーションの保存設計。`docs/vision.md` の moat 文脈に接地。現状「ReactionEvent は未保存」の gap、保存スキーマ案、プライバシー/データ量/背景ログの論点、段階導入。**実データフローを先に実コードで裏取り**（憶測設計禁止）。
  - 検証: 3ファイルが揃い、既存コードの参照（作成経路・保存先）が具体
  - ブランチ: `feat/web-dashboard-phase1`（doc のみ）or 新規 doc ブランチ

- [ ] **T3-2: Phase 3 設計 → 動く縦スライス → レビュー用 PR**
  - まず `.steering/20260705-phase3-artist-insights/` に requirements/design（アーティスト認証・曲所有権・B2B ヒートマップ閲覧）。**認証は既存 Firebase Auth 流用**、所有権は Firestore、rules 追加、Web にアーティスト画面。
  - 設計で**決めきれない分岐は `[blocked]` に列挙してユーザー判断待ち**（例: アーティスト認証方式、曲所有権の紐付けキー）。決まっている範囲で**動く縦スライス**を実装。
  - 検証: web `npm run build` green、rules 構文 OK。**自動マージ禁止**、`personal` に push して**レビュー用 PR 作成まで**。
  - ブランチ: `feat/phase3-artist-insights`

---

## 自動化不可（ユーザー手動・申し送り）

- 実機（iPhone + AirPods）最終確認。

## ブロック記録（loop が追記する。ユーザーが朝に見る）

- **PR #8 のマージ**（T1-4）: auto-mode 分類器が「AI が自作 PR を無レビューでマージ」を拒否。web ビルド green・Phase1+2 は動作検証済み。→ **ユーザーが https://github.com/au-aii/howtune/pull/8 を確認して squash-merge**してください。

## 進捗ログ（loop が1行ずつ追記）

- 2026-07-05 セットアップ: キュー作成。
- 2026-07-05 T1-1 完了: AI_USAGE_LOG に本日分 #017–#020 追記。
- 2026-07-05 T1-2 完了: ADR-0008 ダーク/ライト追従を作成、roadmap 更新。
- 2026-07-05 T1-3 完了: architecture/repository-structure/PRD に web/ サーフェス追記。
- 2026-07-05 T1-4: web ビルド green → personal に push → PR #8 作成。マージは分類器ブロックでユーザー待ち。
- 2026-07-05 T2-1 完了: onHowCardWritten を本番デプロイ＋発火検証（自動再集計 OK）。node20 runtime 廃止予定(2026-10-30)は将来対応。
- 2026-07-05 T2-2 完了: SettingsView 新設＋ContentView の一時ログアウトを歯車→設定シートに昇格。xcodebuild green。
- 2026-07-05 T3-1 完了: moat 永続化の設計 steering 作成（reaction_sessions スキーマ・段階案）。実データ接地済み。未決3点あり。
