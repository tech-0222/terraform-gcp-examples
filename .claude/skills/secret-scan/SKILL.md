---
name: secret-scan
description: Commitまたはpushの前にGitleaksでAPIキー、トークン、パスワード、秘密鍵などを検査する。
allowed-tools: Bash
---

# Secret scan

commit前は個別に `git add` したあと、次を実行する。

```bash
bash scripts/security/secret-scan.sh staged
```

push前は次を実行する。比較先は既定で `origin/main`。

```bash
bash scripts/security/secret-scan.sh push
```

- 検査不能・検出ありの状態でcommit/pushしない。
- `--no-verify`、`SKIP=gitleaks`、hookの削除で回避しない。
- 検出値そのものを会話やログへ転載しない。rule、file、lineだけを報告する。
- 誤検出と思ってもallowlistへ勝手に追加しない。最小の除外案を示して確認を得る。
- 既にcommitしたSecretは削除だけで解決しない。利用停止・ローテーションを先に提案し、履歴改変は明示的な許可を得る。
