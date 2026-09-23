#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import pathlib
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed


TEST_SUFFIXES = ("-test", "-tests", "_test", "_tests")
IGNORED_DIRS = {
    ".git",
    ".mypy_cache",
    ".pytest_cache",
    ".venv",
    "__pycache__",
    "node_modules",
    "venv",
}
PASS_MARKER = "\u2705"
FAIL_MARKER = "\u274c"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run MetaMo MeTTa tests through a PeTTa checkout."
    )
    parser.add_argument(
        "--root",
        default=".",
        help="Repository root to search for MeTTa test files.",
    )
    parser.add_argument(
        "--petta-runner",
        help="Path to PeTTa's run.sh. Defaults to PETTA_RUNNER, PETTA_PATH/run.sh, PATH, or ../PeTTa/run.sh.",
    )
    parser.add_argument(
        "--jobs",
        type=int,
        default=int(os.environ.get("METTA_TEST_JOBS", "1")),
        help="Number of test files to run concurrently.",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=int(os.environ.get("METTA_TEST_TIMEOUT", "300")),
        help="Timeout per test file in seconds.",
    )
    parser.add_argument(
        "--allow-empty",
        action="store_true",
        help="Exit successfully when no matching MeTTa test files are found.",
    )
    return parser.parse_args()


def is_ignored(path: pathlib.Path) -> bool:
    return any(part in IGNORED_DIRS for part in path.parts)


def is_metta_test(path: pathlib.Path) -> bool:
    return path.suffix == ".metta" and path.stem.endswith(TEST_SUFFIXES)


def discover_tests(root: pathlib.Path) -> list[pathlib.Path]:
    tests = [
        path
        for path in root.rglob("*.metta")
        if not is_ignored(path) and is_metta_test(path)
    ]
    return sorted(tests)


def resolve_petta_runner(root: pathlib.Path, explicit_runner: str | None) -> pathlib.Path:
    candidates: list[pathlib.Path] = []

    if explicit_runner:
        candidates.append(pathlib.Path(explicit_runner).expanduser())

    env_runner = os.environ.get("PETTA_RUNNER")
    if env_runner:
        candidates.append(pathlib.Path(env_runner).expanduser())

    env_path = os.environ.get("PETTA_PATH")
    if env_path:
        candidates.append(pathlib.Path(env_path).expanduser() / "run.sh")

    path_runner = shutil.which("run.sh")
    if path_runner:
        candidates.append(pathlib.Path(path_runner))

    candidates.append(root.parent / "PeTTa" / "run.sh")

    for candidate in candidates:
        if candidate.is_file():
            return candidate.resolve()

    searched = "\n".join(f"  - {candidate}" for candidate in candidates)
    raise FileNotFoundError(
        "Could not find PeTTa run.sh. Set PETTA_PATH, PETTA_RUNNER, or pass "
        f"--petta-runner.\nSearched:\n{searched}"
    )


def count_test_forms(path: pathlib.Path) -> int:
    count = 0
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.lstrip()
        if stripped.startswith(";"):
            continue
        if "!(" in stripped and stripped.startswith("!(test"):
            count += 1
    return count


def run_test_file(
    root: pathlib.Path,
    petta_runner: pathlib.Path,
    test_file: pathlib.Path,
    timeout: int,
) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["SHELL"] = "/bin/bash"

    return subprocess.run(
        ["sh", str(petta_runner), str(test_file.relative_to(root))],
        cwd=root,
        env=env,
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )


def output_tail(output: str, max_lines: int = 80) -> str:
    lines = output.strip().splitlines()
    return "\n".join(lines[-max_lines:])


def summarize_result(
    path: pathlib.Path,
    result: subprocess.CompletedProcess[str],
) -> tuple[bool, str]:
    output = "\n".join(part for part in (result.stdout, result.stderr) if part)
    expected_tests = count_test_forms(path)
    passed = output.count(PASS_MARKER)
    failed = output.count(FAIL_MARKER)

    if result.returncode != 0:
        return (
            False,
            f"exit code {result.returncode}; {passed} passed marker(s), {failed} failed marker(s)",
        )

    if failed:
        return False, f"{failed} failed marker(s), {passed} passed marker(s)"

    if expected_tests and passed < expected_tests:
        return (
            False,
            f"expected {expected_tests} test marker(s), saw {passed}",
        )

    if expected_tests == 0 and passed == 0:
        return False, "file matched test naming convention but produced no test markers"

    return True, f"{passed}/{expected_tests or passed} test marker(s) passed"


def main() -> int:
    args = parse_args()
    root = pathlib.Path(args.root).resolve()
    jobs = max(1, args.jobs)
    tests = discover_tests(root)

    if not tests:
        suffixes = ", ".join(f"*{suffix}.metta" for suffix in TEST_SUFFIXES)
        print(f"No MeTTa test files found. Expected one of: {suffixes}")
        return 0 if args.allow_empty else 1

    try:
        petta_runner = resolve_petta_runner(root, args.petta_runner)
    except FileNotFoundError as exc:
        print(exc, file=sys.stderr)
        return 1

    print(f"PeTTa runner: {petta_runner}")
    print(f"Discovered {len(tests)} MeTTa test file(s):")
    for test in tests:
        print(f"  - {test.relative_to(root)}")

    failures: list[tuple[pathlib.Path, str, str]] = []

    with ThreadPoolExecutor(max_workers=jobs) as executor:
        future_to_test = {
            executor.submit(run_test_file, root, petta_runner, test, args.timeout): test
            for test in tests
        }

        for future in as_completed(future_to_test):
            test = future_to_test[future]
            rel_test = test.relative_to(root)

            try:
                result = future.result()
            except subprocess.TimeoutExpired as exc:
                message = f"timed out after {args.timeout}s"
                output = "\n".join(part for part in (exc.stdout, exc.stderr) if part)
                failures.append((test, message, output))
                print(f"FAIL {rel_test}: {message}")
                continue
            except Exception as exc:  # pragma: no cover - defensive CI reporting
                message = f"runner exception: {exc}"
                failures.append((test, message, ""))
                print(f"FAIL {rel_test}: {message}")
                continue

            passed, message = summarize_result(test, result)
            print(f"{'PASS' if passed else 'FAIL'} {rel_test}: {message}")

            if not passed:
                output = "\n".join(
                    part for part in (result.stdout, result.stderr) if part
                )
                failures.append((test, message, output))

    if failures:
        print("\nFailed MeTTa test file(s):")
        for test, message, output in failures:
            print(f"\n--- {test.relative_to(root)} ---")
            print(message)
            if output.strip():
                print(output_tail(output))
        return 1

    print(f"\nAll {len(tests)} MeTTa test file(s) passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
