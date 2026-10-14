from __future__ import annotations

import os
import stat
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
TREEFMT_CLEAN = ROOT / "service" / "scripts" / "treefmt_clean.py"

ZWSP = chr(0x200B)
MARKED = f"Hello{ZWSP} world\n"
CLEANED = "Hello world\n"
PAST_NS = 1_000_000_000 * 10**9


def _run(*paths: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(TREEFMT_CLEAN), *map(str, paths)],
        capture_output=True,
        text=True,
        check=False,
    )


def _write_old(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")
    os.utime(path, ns=(PAST_NS, PAST_NS))


def test_marked_file_is_cleaned_with_exit_zero_and_no_backup(tmp_path: Path):
    target = tmp_path / "notes.md"
    target.write_text(MARKED, encoding="utf-8")

    proc = _run(target)

    assert proc.returncode == 0, proc.stderr
    assert target.read_text(encoding="utf-8") == CLEANED
    assert sorted(p.name for p in tmp_path.iterdir()) == ["notes.md"]


def test_clean_file_is_not_rewritten(tmp_path: Path):
    target = tmp_path / "notes.md"
    _write_old(target, CLEANED)
    inode = target.stat().st_ino

    proc = _run(target)

    assert proc.returncode == 0, proc.stderr
    assert target.stat().st_mtime_ns == PAST_NS
    assert target.stat().st_ino == inode


def test_second_run_is_a_no_op(tmp_path: Path):
    target = tmp_path / "notes.txt"
    target.write_text(MARKED, encoding="utf-8")
    assert _run(target).returncode == 0
    first = target.read_bytes()
    os.utime(target, ns=(PAST_NS, PAST_NS))

    assert _run(target).returncode == 0
    assert target.read_bytes() == first
    assert target.stat().st_mtime_ns == PAST_NS


@pytest.mark.skipif(not hasattr(os, "fchmod"), reason="no POSIX permission bits")
def test_permission_bits_survive_a_rewrite(tmp_path: Path):
    script = tmp_path / "run.sh"
    script.write_text(f"#!/bin/sh\necho hi{ZWSP}\n", encoding="utf-8")
    script.chmod(0o750)

    assert _run(script).returncode == 0
    assert stat.S_IMODE(script.stat().st_mode) == 0o750
    assert script.read_text(encoding="utf-8") == "#!/bin/sh\necho hi\n"


@pytest.mark.parametrize("name", ["doc.md", "default.nix", "README"])
def test_result_does_not_depend_on_extension(tmp_path: Path, name: str):
    target = tmp_path / name
    target.write_text(MARKED, encoding="utf-8")

    assert _run(target).returncode == 0
    assert target.read_text(encoding="utf-8") == CLEANED


def test_failure_is_reported_and_other_files_are_still_cleaned(tmp_path: Path):
    binary = tmp_path / "blob.md"
    binary_bytes = b"\x00\x01\x02" + MARKED.encode("utf-8")
    binary.write_bytes(binary_bytes)
    missing = tmp_path / "gone.md"
    good = tmp_path / "good.md"
    good.write_text(MARKED, encoding="utf-8")

    proc = _run(binary, missing, good)

    assert proc.returncode != 0
    assert str(binary) in proc.stderr
    assert str(missing) in proc.stderr
    assert binary.read_bytes() == binary_bytes
    assert good.read_text(encoding="utf-8") == CLEANED


def test_undecodable_bytes_round_trip(tmp_path: Path):
    target = tmp_path / "latin1.txt"
    target.write_bytes(b"caf\xe9" + ZWSP.encode("utf-8") + b"\n")

    assert _run(target).returncode == 0
    assert target.read_bytes() == b"caf\xe9\n"
