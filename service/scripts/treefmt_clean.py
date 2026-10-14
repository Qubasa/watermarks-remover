#!/usr/bin/env python3
"""Strip invisible-Unicode marks from text files, as a treefmt formatter.

treefmt (https://treefmt.com) passes the files its include globs selected.
clean_staged.py follows the pre-commit auto-fixer convention instead, which
breaks the treefmt formatter spec in three ways this entry point avoids:

* It exits 0 after cleaning a file. Nonzero means a file could not be
  processed, so treefmt reports a real failure rather than every fix.
* It never writes a file that is already clean, so the mtime stays put and
  treefmt's cache and --fail-on-change see no change.
* It writes no .bak sidecar. The tree is under version control, which is the
  backup. Permission bits are kept, so scripts stay executable.

Every file is cleaned as text whatever its extension, so the result does not
depend on the path. Files that look binary are refused rather than decoded.
"""

from __future__ import annotations

import argparse
import stat
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from common import MAX_INPUT_BYTES, eprint, looks_binary, safe_write_bytes
from text_unicode import clean_text


def clean_one(path: Path) -> str | None:
    """Clean *path* in place; return why it failed, or None on success."""
    try:
        st = path.stat()
        if not stat.S_ISREG(st.st_mode):
            return "not a regular file"
        if st.st_size > MAX_INPUT_BYTES:
            return f"larger than {MAX_INPUT_BYTES} bytes"
        raw = path.read_bytes()
    except OSError as e:
        return e.strerror or str(e)

    binary = looks_binary(raw)
    if binary is not None:
        return f"refusing to clean as text: it looks like {binary}"

    text = raw.decode("utf-8", errors="surrogateescape")
    cleaned, _stats = clean_text(text)
    if cleaned == text:
        return None
    try:
        safe_write_bytes(
            path,
            cleaned.encode("utf-8", errors="surrogateescape"),
            mode=stat.S_IMODE(st.st_mode),
        )
    except OSError as e:
        return e.strerror or str(e)
    return None


def main() -> int:
    """Clean every given file and exit nonzero only if one could not be processed."""
    p = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    p.add_argument("paths", nargs="*", type=Path, help="Text files to clean in place")
    args = p.parse_args()

    failed = False
    for path in args.paths:
        error = clean_one(path)
        if error is not None:
            eprint(f"{path}: {error}")
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
