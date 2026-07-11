# Claude Code — Team 10 プロジェクトルール

グローバルルール（`~/.claude/CLAUDE.md`）を継承しつつ、このリポ固有の規約を追加する。

## このプロジェクトについて

Engineer Guild Hackathon 2026/05 の Team 10 リポジトリ。
開発期間中は速度優先で、AI ツールを積極的に活用する。

## AI 活用ログ

**Claude を使って作業した際は必ず [`AI_USAGE_LOG.md`](./AI_USAGE_LOG.md) に記録する。**
審査項目「AI 活用度」の根拠資料になる。最低 1 日 3 件以上を目安に。

## ブランチ戦略

- `main` への直接コミット・プッシュは禁止
- 作業ブランチ → PR → マージの流れを守る
- ブランチ名は `feat/xxx` / `fix/xxx` / `docs/xxx` の形式

## Node バージョン（重要・過去に繰り返しハマった）

- **Node は 22（LTS）に固定**。`functions/package.json` と `web/package.json` の `volta` フィールドで pin 済み。
- **Volta を使う**：一度 `volta setup` を実行して shim を PATH に通せば、`cd` するだけで自動的に 22 に切り替わる。以後 `node scripts/...` と普通に叩けばよい。
- **⚠️ Homebrew の `node`（v26 等の bleeding-edge）で直接叩かない**。firebase-admin 同梱の node-fetch が gzip 解凍で壊れ（`ERR_STREAM_PREMATURE_CLOSE` / `oauth2.googleapis.com/token: Premature close`）、Firestore/Auth への読み書きが全滅する。ネットワークではなく Node バージョンが原因なので、まず `node --version` が 22 か確認する。
- Volta 未導入の人向けに repo 直下 `.node-version`（22.23.1）も置いてある（fnm / nodenv / asdf 用）。

## コミット規約

- prefix: `feat` / `fix` / `docs` / `refactor` / `chore` / `test`
- 末尾に `Co-Authored-By: Claude <noreply@anthropic.com>` を付ける

## 秘匿情報

- API キーや認証情報は `.env`（`.gitignore` 対象）で管理
- 公開リポ化に備え、キーをコードにハードコードしない
