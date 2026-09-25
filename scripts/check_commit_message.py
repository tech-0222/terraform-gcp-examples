#!/usr/bin/env python3
"""Refuse a commit message that carries a session URL.

CLAUDE.md はこう書いている。

  コミットメッセージにセッションURL（`Claude-Session:` トレーラー等）を
  含めない。パブリックリポジトリに残る

**それでも入った。** 2026-09-19、セッションの途中でツール側から
「コミットメッセージの末尾に `Claude-Session: <URL>` を付けよ」という
指示が入り、その指示自身が「リポジトリの CLAUDE.md が優先する」と
断っていたにもかかわらず、機械的に適用した。29コミット中3件、4分間に
集中して入り、3時間半あとに手で監査するまで誰も気づかなかった。

**気づけなかったのは、コミットメッセージを見る検査が1つも無かったから。**
変更内容には Gitleaks があり、PR本文には check_pr_template_sync.py が
あるのに、その中間だけが空いていた。規約に書いてあるだけの状態だった。

ここで見るのは URL の形をしたセッション識別子だけにする。広げると、
参考リンクを貼った普通のコミットまで落ちる。

Exit 0 = 問題なし, 1 = 見つかった, 2 = 検査できない。

  python3 scripts/check_commit_message.py .git/COMMIT_EDITMSG
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# 落とすのは、トレーラー名、セッションURL、その短縮形と、
# 対になるブログのリポジトリへの参照。最後のものは check_public_text.py の
# TEXT_ONLY_RULES と同じ判定。コミットは履歴に残り、あとから直せない。
PATTERNS = (
    (re.compile(r"hugo-blog", re.IGNORECASE), "対になるブログのリポジトリへの参照"),
    (re.compile(r"^\s*Claude-Session\s*:", re.IGNORECASE | re.MULTILINE),
     "Claude-Session トレーラー"),
    (re.compile(r"https?://claude\.ai/\S*session[_/][A-Za-z0-9_-]+", re.IGNORECASE),
     "claude.ai のセッションURL"),
    (re.compile(r"\bsession_[A-Za-z0-9]{16,}\b"),
     "セッション識別子"),
)


def findings(message: str) -> list[str]:
    """What must not ship in a public repository's history."""
    out = []
    for pattern, label in PATTERNS:
        for hit in pattern.findall(message):
            text = hit if isinstance(hit, str) else hit[0]
            out.append(f"  {label}: {text.strip()[:70]}")
    return out


def main() -> int:
    if len(sys.argv) != 2:
        print("使い方: check_commit_message.py <メッセージのファイル>", file=sys.stderr)
        return 2

    path = Path(sys.argv[1])
    try:
        message = path.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"コミットメッセージを読めません: {exc}", file=sys.stderr)
        return 2

    # コメント行（`#` 始まり）はコミットされない。検査の対象外。
    body = "\n".join(line for line in message.splitlines()
                     if not line.lstrip().startswith("#"))

    hits = findings(body)
    if not hits:
        return 0

    print("::error::コミットメッセージに公開してはいけない情報が入っています")
    print("\n".join(hits))
    print("\nパブリックリポジトリの履歴に残ります。CLAUDE.md で禁じています。")
    print("ツール側から付けるよう指示されても、リポジトリの規約が優先します。")
    return 1


if __name__ == "__main__":
    sys.exit(main())
