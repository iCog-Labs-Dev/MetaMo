#!/usr/bin/env python3
"""Run the curated offline full-loop scenarios using the common Core launcher.

This is a scoped harness entry point, not a replacement for run-tests.py or
Task 5's complete regression gate. Each scenario runs in a fresh process.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile
import time

REPO = Path(__file__).resolve().parent.parent
LAUNCHER = REPO / 'scripts/run-omegaclaw.py'
TESTS = REPO / 'applications/omegaclaw_v1/tests'
# Explicit assertion contracts for these curated scenarios; changes to their
# assertions must update this manifest. No heuristic source-form counting.
SCENARIOS = {
    'scoring': ('outcome_scoring_test.metta', 59),
    'modes': ('host_mode_transition_test.metta', 180),
    'callbacks': ('full_loop_callbacks_test.metta', 46),
    'invalidation': ('full_loop_invalidation_test.metta', 92),
}
PASS = re.compile(r'^is .*\. ✅[ \t]*$', re.MULTILINE)
DIAGNOSTIC = re.compile(r'^ERROR:|^Traceback \(most recent call last\):|^\(Error import!', re.MULTILINE)


def verdict(name, expected, returncode, stdout, stderr, timed_out):
    passed = len(PASS.findall(stdout))
    reasons = []
    if timed_out:
        reasons.append('timeout')
    if returncode != 0:
        reasons.append(f'exit code {returncode}')
    if '❌' in stdout or '❌' in stderr:
        reasons.append('failed assertion')
    if DIAGNOSTIC.search(stdout) or DIAGNOSTIC.search(stderr):
        reasons.append('interpreter or import error')
    if passed != expected:
        reasons.append(f'expected {expected} assertions, observed {passed}')
    if f'(FullLoopFinished {name})' not in stdout.splitlines():
        reasons.append('missing scenario completion marker')
    return {'passed': not reasons, 'assertions': passed,
            'expected_assertions': expected, 'reasons': reasons}


def run_scenario(name, workspace, artifacts, timeout, launcher=LAUNCHER):
    filename, expected = SCENARIOS[name]
    stdout_path = artifacts / f'{name}.stdout.log'
    stderr_path = artifacts / f'{name}.stderr.log'
    imports_path = artifacts / f'{name}.imports.json'
    command = [sys.executable, str(launcher), str(TESTS / filename),
               '--workspace', str(workspace), '--report', str(imports_path)]
    started = time.monotonic()
    timed_out = False
    with stdout_path.open('w', encoding='utf-8') as stdout, stderr_path.open('w', encoding='utf-8') as stderr:
        try:
            with subprocess.Popen(command, cwd=REPO, stdin=subprocess.DEVNULL,
                                  stdout=stdout, stderr=stderr, start_new_session=True,
                                  env={**os.environ, 'PYTHONUNBUFFERED': '1'}) as process:
                try:
                    returncode = process.wait(timeout=timeout)
                except subprocess.TimeoutExpired:
                    timed_out = True
                    # The common launcher spawns SWI; terminate the whole group.
                    try:
                        os.killpg(process.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                    returncode = process.wait()
        except OSError as error:
            stderr.write(f'ERROR: could not start launcher: {error}\n')
            returncode = -1
    result = verdict(name, expected, returncode,
                     stdout_path.read_text(errors='replace'),
                     stderr_path.read_text(errors='replace'), timed_out)
    imported_sources = {}
    try:
        for edge in json.loads(imports_path.read_text(encoding='utf-8')):
            source = Path(edge['resolved'])
            imported_sources[str(source)] = source_hash(source)
    except (OSError, ValueError, KeyError, TypeError) as error:
        result['passed'] = False
        result['reasons'].append(f'missing or invalid import-resolution report: {error}')
    return {**result, 'scenario': name, 'command': command,
            'imported_source_sha256': imported_sources,
            'returncode': returncode, 'timed_out': timed_out,
            'elapsed_seconds': round(time.monotonic() - started, 3),
            'stdout': str(stdout_path), 'stderr': str(stderr_path),
            'imports': str(imports_path)}


def source_hash(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None


def revision(path):
    result = subprocess.run(['git', '-C', str(path), 'rev-parse', 'HEAD'],
                            capture_output=True, text=True, check=False)
    return result.stdout.strip() if result.returncode == 0 else None


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--workspace', type=Path, default=REPO.parent,
                        help='PeTTa workspace containing src/ and repos/OmegaClaw-Core')
    parser.add_argument('--scenario', choices=SCENARIOS, action='append',
                        help='Select a scenario; defaults to all four')
    parser.add_argument('--output', type=Path,
                        help='Parent directory for a unique run directory; default: system temp')
    parser.add_argument('--timeout', type=float, default=300,
                        help='Maximum seconds per scenario')
    args = parser.parse_args(argv)
    if not 0 < args.timeout < float('inf'):
        parser.error('--timeout must be finite and positive')
    workspace = args.workspace.expanduser().resolve()
    if args.output:
        args.output = args.output.expanduser().resolve()
        args.output.mkdir(parents=True, exist_ok=True)
    artifacts = Path(tempfile.mkdtemp(prefix='omegaclaw-offline-', dir=args.output))
    names = list(dict.fromkeys(args.scenario or SCENARIOS))
    sources = [Path(__file__), LAUNCHER, REPO / 'scripts/petta-imports.pl',
               TESTS / 'fixtures/full_loop.metta',
               workspace / 'src/metta.pl', workspace / 'src/parser.pl']
    sources.extend(TESTS / SCENARIOS[name][0] for name in names)
    summary = {
        'started_utc': datetime.now(timezone.utc).isoformat(),
        'workspace': str(workspace), 'python': sys.version,
        'revisions': {'metamo': revision(REPO), 'petta': revision(workspace),
                      'core': revision(workspace / 'repos/OmegaClaw-Core')},
        'source_sha256': {str(path): source_hash(path) for path in sources},
        'results': [], 'passed': False,
    }
    report = artifacts / 'summary.json'
    print(f'Artifacts: {artifacts}', flush=True)
    for name in names:
        result = run_scenario(name, workspace, artifacts, args.timeout)
        summary['results'].append(result)
        report.write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
        status = 'PASS' if result['passed'] else 'FAIL'
        print(f"{status} {name}: {result['assertions']}/{result['expected_assertions']} assertions", flush=True)
        for reason in result['reasons']:
            print(f'  {reason}', flush=True)
    summary['passed'] = all(result['passed'] for result in summary['results'])
    report.write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
    print(f'Report: {report}', flush=True)
    return 0 if summary['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
