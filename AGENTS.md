# AGENTS.md

リポジトリの規約は `CLAUDE.md` を参照する。

commitまたはpushの前には `.agents/skills/secret-scan/SKILL.md` に従い、
Gitleaksを実行する。失敗時に `--no-verify` やskipで回避しない。

`.sh` と `.github/workflows/` を変更したら、あわせて静的検査をかける。
導入時点で0件のため、落とす対象にしている。

```bash
bash scripts/lint_sources.sh all
```
