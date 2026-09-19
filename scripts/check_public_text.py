#!/usr/bin/env python3
"""Scan text that GitHub publishes -- PR bodies, issue bodies, comments.

**コードは守られていたが、その周りの文章は無検査だった。**

  ファイル内容        Gitleaks（pre-commit / pre-push / CI）
  コミットメッセージ  commit-msg フック
  PR本文・Issue本文   無し   ← ここ

2026-09-19、コミットメッセージに混入したセッションURLを履歴から除去した
その同じ日に、**除去した当のセッションIDの断片を、同じ公開リポジトリの
PR本文に書いた。** 消す作業と、消したものを公開の場へ書き戻す作業を、
同じセッションの中で並行してやっていた。

ローカルのフックでは止められない。`gh pr create` はフックを通らないし、
Web UI から書くこともできる。**だから CI で落とす。** PR や Issue が
開かれたとき・編集されたときに走らせれば、経路によらず必ず通る。

見るもの。

  セッションURL・識別子   commit-msg と同じ形
  Project ID / Number     このリポジトリの実値
  メールアドレス          gcloud アカウントなど
  秘密鍵のヘッダ          貼り付け事故

**検出値そのものは出力しない。** 出すと、検査の実行ログ（公開リポジトリ
では誰でも読める）に転載することになる。secret-scan.sh と同じ扱いで、
種類と位置だけを報告する。

Exit 0 = 問題なし, 1 = 見つかった, 2 = 検査できない。

  python3 scripts/check_public_text.py --stdin < body.txt
  python3 scripts/check_public_text.py path/to/text
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# 種類ごとに、何を見ているかを名前で言えるようにする。値は出さない。
RULES: tuple[tuple[str, re.Pattern[str]], ...] = (
    ("セッションURL・識別子",
     re.compile(r"claude\.ai/\S*session[_/][A-Za-z0-9_-]+|(?<![A-Za-z0-9])session_[A-Za-z0-9]{16,}",
                re.IGNORECASE)),
    ("Claude-Session トレーラー",
     re.compile(r"^\s*Claude-Session\s*:", re.IGNORECASE | re.MULTILINE)),
    ("GCP Project ID",
     re.compile(r"(?<![A-Za-z0-9-])tech-0222-tf-examples(?![A-Za-z0-9-])")),
    ("GCP Project Number",
     re.compile(r"(?<!\d)527031335407(?!\d)")),
    ("メールアドレス",
     re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")),
    ("秘密鍵",
     re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
)

# 置き換え済みの表記と、署名として認めている宛先は落とさない。
ALLOWED = re.compile(
    r"YOUR_PROJECT_ID|YOUR_PROJECT_NUMBER|noreply@anthropic\.com|"
    r"example\.com|user:USER@EXAMPLE\.COM",
    re.IGNORECASE)


def findings(text: str) -> list[str]:
    """What kinds of secret-ish things appear, and on which lines."""
    out: list[str] = []
    for number, line in enumerate(text.splitlines(), start=1):
        if ALLOWED.search(line):
            line = ALLOWED.sub("", line)
        for label, pattern in RULES:
            if pattern.search(line):
                out.append(f"  {number}行目: {label}")
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", nargs="?", help="検査するファイル")
    parser.add_argument("--stdin", action="store_true", help="標準入力から読む")
    parser.add_argument("--label", default="テキスト", help="報告に出す対象の名前")
    args = parser.parse_args()

    if args.stdin:
        text = sys.stdin.read()
    elif args.path:
        try:
            text = Path(args.path).read_text(encoding="utf-8")
        except OSError as exc:
            print(f"読めません: {exc}", file=sys.stderr)
            return 2
    else:
        print("--stdin かファイルのどちらかを指定します", file=sys.stderr)
        return 2

    # 空文字と「読めなかった」を混同しない。空は検査対象が無いだけ。
    if not text.strip():
        print(f"  OK  {args.label}（空）")
        return 0

    hits = findings(text)
    if not hits:
        print(f"  OK  {args.label}")
        return 0

    print(f"::error::{args.label} に公開してはいけない情報が含まれています")
    print("\n".join(hits))
    print("\n**値そのものはここに出しません。** 該当行を開いて置き換えてください。")
    print("Project ID や Project Number はプレースホルダーに、"
          "セッションURLは削除します。")
    return 1


if __name__ == "__main__":
    sys.exit(main())
