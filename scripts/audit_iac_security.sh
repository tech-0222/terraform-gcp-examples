#!/usr/bin/env bash
# IaC の設定ミスを Trivy で洗い、件数と内訳を出す。
#
# **これは助言で、落とさない。** 導入時点で959件（HIGH 146 / MEDIUM 397 /
# LOW 416）あり、その大半はこのリポジトリの趣旨そのものだった。
#
#   258件  KSV-*     GKE のデモ用マニフェストのセキュリティコンテキスト
#   102件  GCP-0029 / GCP-0076  全サブネットで VPC フローログが無効
#    28件  GCP-0048 / GCP-0057  GKE ノードのメタデータ設定
#
# サンプルは GCP の特定機能を最小構成で示すためのもので、暗号化・ログ・
# ネットワーク制限を省いているのは意図である。ここを落とす対象にすると、
# 既存サンプルに触れなくなるだけで、質は上がらない（記事の検査で同じ
# 失敗をしている。CLAUDE.md の「90本中87本が落ちる」を参照）。
#
# **ただし全部が意図ではない。** 見るべきものは HIGH に混じっている。
#
#   GCP-0015  Cloud SQL への SSL 接続が強制されていない
#   GCP-0017  Cloud SQL インスタンスが公開されている
#   GCP-0061  GKE の master authorized networks が未設定
#
# この3種は2026-09-19に内容を確認し、**現状維持と判断した。** 理由は各サンプル
# の README に書いてある。GCP-0017 は authorized_networks が無いため実際には
# 接続できず（13 では nc で確認済み）、GCP-0015 は平文で流れる経路が無い。
# GCP-0061 だけは本当に公開エンドポイントなので、その旨を README に明記した。
#
# だから件数を出して推移を見る。**増えたときに気づける**ことが目的で、
# 0 にすることは目的ではない。
#
# Gitleaks との役割分担。Trivy にも Secret 検査があるが使わない。
#
#   Gitleaks  「鍵やパスワードを書いていないか」
#   Trivy     「設定そのものが危険でないか」
#
# 検査できないときは0を返さない。trivy が無ければ終了コード2で止める。
#
#   bash scripts/audit_iac_security.sh [--high]
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Git リポジトリではありません" >&2
  exit 2
}
cd "$ROOT" || exit 2

if ! command -v trivy >/dev/null 2>&1; then
  echo "trivy がありません。検査を実行できないので、通ったことにはしません。" >&2
  exit 2
fi

echo "使用: $(trivy --version | head -1)"

report="$(mktemp)"
trap 'rm -f "$report"' EXIT

# `trivy config` は設定ミス検査そのものなので --scanners は取らない。
if ! trivy config --quiet --format json . > "$report" 2>/dev/null; then
  echo "trivy config が失敗しました。" >&2
  exit 2
fi

only_high=""
[ "${1:-}" = "--high" ] && only_high=1

ONLY_HIGH="$only_high" python3 - "$report" <<'PY'
import json, os, sys
from collections import Counter

with open(sys.argv[1], encoding="utf-8") as handle:
    data = json.load(handle)

rows = []
for result in data.get("Results") or []:
    for miss in result.get("Misconfigurations") or []:
        rows.append((miss["Severity"], miss["ID"], miss.get("Title", ""),
                     result.get("Target", "")))

if not rows:
    print("  指摘はありません。**検査できたうえでの0件かを疑うこと。**")
    raise SystemExit

by_severity = Counter(row[0] for row in rows)
order = ["CRITICAL", "HIGH", "MEDIUM", "LOW", "UNKNOWN"]
summary = "  ".join(f"{sev} {by_severity[sev]}" for sev in order if by_severity[sev])
print(f"  合計 {len(rows)} 件（{summary}）")

# 見るべきものは HIGH に混じっている。意図した最小構成と区別して出す。
WATCH = {"GCP-0015", "GCP-0017", "GCP-0061"}
watched = [row for row in rows if row[1] in WATCH]
if watched:
    print("\n  要確認（サンプルの趣旨では説明できないもの）")
    print("    いずれも判断済み。理由は各サンプルの README の「注意点 / 費用」にある。")
    for sev, rule, title, target in sorted(watched):
        print(f"    [{sev}] {rule}  {target}")
        print(f"           {title}")

if os.environ.get("ONLY_HIGH"):
    raise SystemExit

print("\n  ルール別（上位10）")
for (sev, rule, title), count in Counter(
        (row[0], row[1], row[2]) for row in rows).most_common(10):
    print(f"    {count:>4} [{sev}] {rule}  {title[:52]}")
PY

# 助言なので落とさない。実行できたかどうかだけを終了コードで返す。
exit 0
