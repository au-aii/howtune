# .claude — エージェント・コマンドの導入について

このリポジトリはかつて agents / commands / skills の物理コピーを `.claude/` 配下に持っていたが、
配布元とのドリフトが実害を生んだため、Claude Code の plugin marketplace 導入へ移行した
（経緯: au-aii/claude-dotfiles#63）。

## 導入手順（各開発者が一度だけ・Claude Code のチャットで）

```
/plugin marketplace add au-aii/claude-config
/plugin install dev@claude-config-marketplace
/plugin install common@claude-config-marketplace
```

- ⚠️ `settings.json` の `Skill(...)` 許可リストは **plugin 導入後は名前が変わるため効かなくなる**。plugin 由来のコンポーネントは `<plugin>:<name>` で名前空間化されるので、`Skill(prd-writing)` は `Skill(dev:prd-writing)` に書き換えが要る（2026-08-01 実測・au-aii/claude-dotfiles の ADR-0024）
- コマンド・エージェントも同様に `/dev:ship`・`common:code-reviewer` になる
- 以後の更新は `/plugin update` で取得する（コピーの手同期は不要）
