#!/usr/bin/env python3
"""Launch or audit v1 with one explicit PeTTa workspace; never search PATH for petta."""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import subprocess
import sys

REPO = Path(__file__).resolve().parent.parent


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("entry", type=Path, help="MeTTa entry file, relative to the caller")
    parser.add_argument("--workspace", type=Path, default=REPO.parent)
    parser.add_argument("--audit", action="store_true", help="Resolve imports without executing code")
    parser.add_argument("--report", type=Path, help="Write import edges and physical source paths as JSON")
    args, runtime_args = parser.parse_known_args()
    workspace = args.workspace.expanduser().resolve()
    entry = args.entry.expanduser().resolve()
    for path in (workspace / "src/metta.pl", workspace / "lib/lib_import.metta", entry):
        if not path.is_file():
            parser.error(f"Required source is missing: {path}")
    report = str(args.report.resolve()) if args.report else "-"
    command = [
        "swipl", "--stack_limit=8g", "-q", "-s", str(REPO / "scripts/petta-imports.pl"),
        "--", str(workspace), str(REPO), str(entry),
        "audit" if args.audit else "run", report, "-s", *runtime_args,
    ]
    # One cwd for host runtime resources, regardless of the invoking shell/test root.
    return subprocess.call(command, cwd=workspace, env=os.environ.copy())


if __name__ == "__main__":
    sys.exit(main())
