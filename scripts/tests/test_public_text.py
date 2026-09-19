"""Pin what must never reach a PR body, an issue body, or a comment.

2026-09-19、コミットメッセージに混入したセッションURLを履歴から除去した
その同じ日に、除去した当のセッションIDの断片を同じ公開リポジトリのPR本文
に書いた。コードにはGitleaks、コミットメッセージにはフックがあったが、
PR本文だけ無検査だった。
"""
import subprocess
import sys
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / 'check_public_text.py'


def run(text):
    done = subprocess.run([sys.executable, str(SCRIPT), '--stdin'],
                          input=text, capture_output=True, text=True)
    return done.returncode, done.stdout


def test_a_plain_body_passes():
    code, out = run("## Why\n課題を書く。\n\n## What\n変更点を書く。\n")
    assert code == 0
    assert 'OK' in out


def test_the_session_id_that_actually_shipped_is_refused():
    """実際にPR本文へ書いてしまった形。断片でも落とす。"""
    code, out = run("Evidence:\n  claude.ai のセッションURL: "
                    "https://claude.ai/code/session_01PubchWR1jgzFSCUh7tqqUZ\n")
    assert code == 1
    assert 'セッションURL' in out
    # 検出値そのものを出力に載せない。載せると実行ログへ転載される。
    assert 'session_01Pub' not in out


def test_the_project_id_is_refused():
    code, out = run("実行例: gcloud config set project tech-0222-tf-examples\n")
    assert code == 1
    assert 'Project ID' in out
    assert 'tech-0222-tf-examples' not in out, '値を出力しない'


def test_the_project_number_is_refused():
    code, out = run("url_map_name: URL_MAP/527031335407_tf-adv-um\n")
    assert code == 1
    assert 'Project Number' in out


def test_placeholders_are_allowed():
    """置き換え済みの表記で落とすと、正しい書き方が通らなくなる。"""
    code, _ = run("gcloud config set project YOUR_PROJECT_ID\n"
                  "url_map: URL_MAP/YOUR_PROJECT_NUMBER_tf-adv-um\n")
    assert code == 0


def test_an_email_is_refused_but_the_signature_is_not():
    assert run("連絡先: someone@example.org\n")[0] == 1
    # 署名に使う宛先まで落とすと、規約どおりのPRが通らない。
    assert run("Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>\n")[0] == 0


def test_a_private_key_header_is_refused():
    code, out = run("-----BEGIN RSA PRIVATE KEY-----\n")
    assert code == 1
    assert '秘密鍵' in out


def test_an_empty_body_is_not_a_failure():
    # 本文が空のPRはある。空と「読めなかった」を同じ値にしない。
    assert run("")[0] == 0


def test_unreadable_input_is_an_execution_failure(tmp_path):
    done = subprocess.run([sys.executable, str(SCRIPT), str(tmp_path / 'nope')],
                          capture_output=True, text=True)
    assert done.returncode == 2


def test_every_allowlist_entry_has_a_reason():
    """除外リストは、放っておくと検査を黙らせる道具になる。

    値と理由を対で持たせ、理由の無い項目を置けないようにする。増やす
    ときに「なぜ公開されて構わないか」を書かせるのが目的。
    """
    import importlib.util
    spec = importlib.util.spec_from_file_location('c', SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)

    assert mod.ALLOWED_VALUES, '除外リストが空'
    for value, reason in mod.ALLOWED_VALUES.items():
        assert reason.strip(), f'理由が無い: {value}'
        assert len(reason) >= 10, f'理由が短すぎる: {value}'


def test_the_allowlist_judges_the_match_not_the_line():
    """行から除外語を削る方式にしない。

    一度それで書いたところ、サービスアカウントの末尾だけが削られ、
    残りが再びメールとして一致した。検出が2件から3件に増えた。
    """
    # 末尾を削ると ...@container-engine-robot.iam が残って再一致する形。
    code, out = run("実行者: service-123@container-engine-robot.iam.gserviceaccount.com\n")
    assert code == 0, out


def test_a_real_looking_address_still_fails_next_to_an_allowed_one():
    """除外が行全体に効いてしまうと、同じ行の本物を見逃す。"""
    code, out = run("連絡先 someone@personal.example.org と "
                    "service-1@x.gserviceaccount.com\n")
    assert code == 1
    assert 'メールアドレス' in out
