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
  非公開リポジトリへの参照  PR・Issue・コメントの本文だけ（後述）

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
    # GCP が払い出すサービスアカウントは除く。CLAUDE.md が「GCPが払い出した
    # リソースのIP・名前」を対象外としているのと同じ理由で、書き手を特定
    # しない。実測では6ファイルがこれに当たり、すべて PROJECT_NUMBER は
    # プレースホルダー化済みだった。
    ("メールアドレス",
     re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")),
    ("秘密鍵",
     re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
)

# 落とさないもの。**理由を必ず書く。**
#
# 除外リストは、放っておくと検査を黙らせる道具になる。だから値と理由を
# 対にして持ち、理由の無い項目を置けないようにしている（テストで固定）。
# 増やすときは「なぜ公開されて構わないか」を1行で言えるかを先に考える。
#
# 2種類ある。構造的に安全なもの（ドメインの性質で決まる）と、個別に
# 判断したもの。後者は増えるほど検査が弱くなるので、慎重に足す。
# **本文だけに掛ける規則。** ファイル全体の走査（--repo）には掛けない。
#
# 2026-09-25、この公開リポジトリの PR 本文とコミットに、非公開リポジトリの
# ファイル名と Issue 番号を書いた。直しても、PR 本文の編集履歴と force-push
# 前のコミットには残った。**公開される文章は、最初の版から書かないしかない。**
# だから gh pr create の前に手で流すこの検査で止める。
#
# 対象はリポジトリ名だけにする。名前は CLAUDE.md で既に公開されているが、
# 非公開側のファイル名やパスをここへ列挙すると、この検査自身が公開してしまう。
# ファイルに掛けないのは、CLAUDE.md や skill が「対になるブログ」として
# リポジトリ名を正当に書いているから。
TEXT_ONLY_RULES: tuple[tuple[str, re.Pattern[str]], ...] = (
    ("非公開リポジトリ（hugo-blog）への参照",
     re.compile(r"hugo-blog", re.IGNORECASE)),
)

ALLOWED_VALUES: dict[str, str] = {
    # --- 構造的に安全 ---
    "YOUR_PROJECT_ID": "置き換え済みのプレースホルダー",
    "YOUR_PROJECT_NUMBER": "置き換え済みのプレースホルダー",
    "example.com": "RFC 2606 の予約ドメイン。実在しない",
    "USER@EXAMPLE.COM": "規約が示す置き換え後の表記",
    "noreply@anthropic.com": "コミットの署名に使う宛先。個人を指さない",
    ".gserviceaccount.com":
        "GCP が払い出すサービスアカウント。CLAUDE.md が「GCPが払い出した"
        "リソースの名前」を対象外としているのと同じ理由で、書き手を特定しない",
    "system@google.com":
        "監査ログに出る Google 側のシステム実行者。`@google.com` 全体は"
        "通さない（実在の個人を見逃すため）、この1語だけを除く",
    "users.noreply.github.com":
        "GitHub が配る返信不可のアドレス。配送されず、記事では伏せ字と"
        "組み合わせた例示にしか出てこない",

    "XXXXX@github.com":
        "記事中の伏せ字済みの例示。ユーザー名を XXXXX に置き換えてある",

    # --- 個別に判断したもの ---
    "info@inaccel.com":
        "minikube addons list の実出力に含まれる第三者メンテナの公開連絡先。"
        "伏せると『実行結果は実際の出力を使う』に反する",
}

ALLOWED = re.compile("|".join(re.escape(v) for v in ALLOWED_VALUES), re.IGNORECASE)


def allowed(hit: str) -> bool:
    """Is this specific match one of the values we decided is safe?

    **行から除外語を消す方式にしてはいけない。** 一度それで書いたところ、
    `service-X@container-engine-robot.iam.gserviceaccount.com` から末尾だけ
    削られ、残った `...@container-engine-robot.iam` が再びメールとして
    一致した。判定するのは一致した箇所そのもの。
    """
    return bool(ALLOWED.search(hit))


def findings(text: str, rules=RULES) -> list[str]:
    """What kinds of secret-ish things appear, and on which lines."""
    out: list[str] = []
    for number, line in enumerate(text.splitlines(), start=1):
        for label, pattern in rules:
            for hit in pattern.finditer(line):
                if allowed(hit.group(0)):
                    continue
                out.append(f"  {number}行目: {label}")
                break
    return out


# この検査自身は、検出するパターンを書いているので必ず引っかかる。
# 例外はここに明示する。増やすときは、なぜ要らないのかを書く。
SELF = ("scripts/check_public_text.py", "scripts/tests/test_public_text.py",
        "scripts/check_commit_message.py", "scripts/tests/test_commit_message.py")


def scan_repository(under: str = "") -> int:
    """Check what CI actually reads: every tracked file.

    **CIのログを濾すのではなく、ログの元を断つ。** リポジトリの中身が
    綺麗で、リポジトリシークレットが無く、PR・Issue・コミットメッセージ
    を検査しているなら、公開ログに出る元が残らない。ここはその前提の
    うち一番大きいものを固定する。
    """
    import subprocess

    done = subprocess.run(["git", "ls-files"], capture_output=True, text=True)
    if done.returncode != 0:
        print("追跡ファイルを列挙できません", file=sys.stderr)
        return 2

    skipped = 0
    failed = 0
    scanned = 0
    for name in done.stdout.splitlines():
        if under and not name.startswith(under):
            continue
        if not name or name in SELF:
            skipped += 1
            continue
        path = Path(name)
        if path.suffix.lower() in (".svg", ".png", ".jpg", ".jpeg", ".ico", ".woff2"):
            skipped += 1
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            skipped += 1
            continue
        scanned += 1
        hits = findings(text)
        if hits:
            failed += 1
            print(f"::error::{name}")
            print("\n".join(hits))

    if failed:
        print(f"\n{failed} ファイルに公開してはいけない情報があります。"
              "**値そのものはここに出しません。**")
        return 1
    where = f"{under} 配下の" if under else ""
    print(f"  OK  {where}追跡ファイル {scanned} 件（除外 {skipped} 件）")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", nargs="?", help="検査するファイル")
    parser.add_argument("--stdin", action="store_true", help="標準入力から読む")
    parser.add_argument("--label", default="テキスト", help="報告に出す対象の名前")
    parser.add_argument("--repo", action="store_true",
                        help="追跡ファイルを見る（CIの入力そのものを確かめる）")
    parser.add_argument("--under", default="",
                        help="走査を この接頭辞の配下に限る（例: content）")
    args = parser.parse_args()

    if args.repo:
        return scan_repository(args.under)

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

    hits = findings(text, RULES + TEXT_ONLY_RULES)
    if not hits:
        print(f"  OK  {args.label}")
        return 0

    print(f"::error::{args.label} に公開してはいけない情報が含まれています")
    print("\n".join(hits))
    print("\n**値そのものはここに出しません。** 該当行を開いて置き換えてください。")
    print("Project ID や Project Number はプレースホルダーに、"
          "セッションURLは削除します。")
    print("非公開リポジトリへの参照は「リポジトリ外の文書」など一般的な言い方にします。")
    return 1


if __name__ == "__main__":
    sys.exit(main())
