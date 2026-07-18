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

- `settings.json` の `Skill(...)` 許可リストは、plugin 導入後もスキル名が同じためそのまま有効
- 以後の更新は `/plugin update` で取得する（コピーの手同期は不要）
