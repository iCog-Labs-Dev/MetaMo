"""Launch isolated comparisons through the common launcher; retain every run.

The trusted MeTTa entry consumes OMEGACLAW_BENCHMARK_SCENARIO and uses normal
runtime APIs. Adapter matrix execution and task/prediction measurement are separate.
"""
import argparse
import copy
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
from uuid import uuid4

from reasoner_benchmark_formats import validate_scenario, validate_result

APP = Path(__file__).resolve().parents[1]
REPO = APP.parents[1]
LAUNCHER = REPO / 'scripts/run-omegaclaw.py'


# Example: scenario/results remain inspectable after failed or timed-out children exit.
def _write_json(path, value):
    path.write_text(json.dumps(value, indent=2, allow_nan=False) + '\n', encoding='utf-8')


# Example: inherited live task configuration must not select the user's active frame.
def _environment(directory):
    memory, output = directory / 'memory', directory / 'output'
    memory.mkdir()
    output.mkdir()
    history = directory / 'runtime/repos/OmegaClaw-Core/memory/history.metta'
    history.parent.mkdir(parents=True)
    history.touch()
    environment = os.environ.copy()
    environment.pop('OMEGACLAW_HOST_CONFIG', None)
    environment.update(PYTHONUNBUFFERED='1', CHROMA_DB_PATH=str(memory / 'chroma'),
        OMEGACLAW_HISTORY_PATH=str(history), OMEGACLAW_BENCHMARK_MEMORY=str(memory),
        OMEGACLAW_BENCHMARK_OUTPUT=str(output), OMEGACLAW_LIVE_OUTPUT=str(output),
        OMEGACLAW_BENCHMARK_SCENARIO=str(directory / 'scenario.json'),
        OMEGACLAW_BENCHMARK_RUN_ID=directory.name)
    return environment


# Example: SWI is a launcher descendant; timeout must stop the entire process group.
def _execute(command, directory, environment, timeout):
    with (directory / 'stdout.log').open('w') as stdout, (directory / 'stderr.log').open('w') as stderr:
        try:
            with subprocess.Popen(command, cwd=directory, env=environment,
                    stdin=subprocess.DEVNULL, stdout=stdout, stderr=stderr,
                    start_new_session=True) as process:
                timed_out = False
                try:
                    code = process.wait(timeout=timeout)
                except subprocess.TimeoutExpired:
                    timed_out = True
                finally:
                    # Reap run-owned workers even if the launcher has already exited.
                    try:
                        os.killpg(process.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                    code = process.wait()
                if timed_out:
                    return 'timed_out', 'Comparison exceeded max_elapsed_ms', code
            if code:
                return 'failed', f'Common launcher exited with code {code}', code
        except OSError as error:
            stderr.write(str(error) + '\n')
            return 'unavailable', str(error), None
    for name in ('stdout.log', 'stderr.log'):
        with (directory / name).open(errors='replace') as stream:
            for line in stream:
                if '❌' in line or line.lstrip().startswith(('ERROR:', 'Traceback (most recent call last):', '(Error ')):
                    return 'failed', f'Interpreter/assertion error; see {name}', code
    return 'completed', None, code


# Example: run_comparison(scenario, trusted_entry) allocates a fresh process and paths each time.
def run_comparison(scenario, entry, *, output=None, workspace=REPO.parent):
    scenario = copy.deepcopy(validate_scenario(scenario))
    if output is not None:
        output = Path(output).resolve()
        output.mkdir(parents=True, exist_ok=True)
    directory = Path(tempfile.mkdtemp(prefix='reasoner-' + uuid4().hex + '-', dir=output)).resolve()
    environment = _environment(directory)
    _write_json(directory / 'scenario.json', scenario)
    command = [sys.executable, str(LAUNCHER), str(Path(entry).resolve()),
               '--workspace', str(Path(workspace).resolve()), '--runtime-dir', str(directory / 'runtime'),
               '--report', str(directory / 'imports.json')]
    started = time.monotonic()
    status, error, code = _execute(command, directory, environment,
                                  scenario['resource_limits']['max_elapsed_ms'] / 1000)
    result = validate_result(dict(schema_version=1, run_id=directory.name, scenario=scenario,
        status=status, error=error, elapsed_ms=int((time.monotonic() - started) * 1000),
        trace_references=[], measurements={}))
    _write_json(directory / 'execution.json', dict(command=command, returncode=code,
        runtime_dir=str(directory / 'runtime'), memory_dir=environment['OMEGACLAW_BENCHMARK_MEMORY'],
        output_dir=environment['OMEGACLAW_BENCHMARK_OUTPUT']))
    _write_json(directory / 'result.json', result)
    return result, directory


# Example: repeated scenario paths still produce independent runs and separate failure records.
def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('scenarios', nargs='+', type=Path)
    parser.add_argument('--entry', required=True, type=Path, help='Trusted executable MeTTa scenario driver')
    parser.add_argument('--workspace', type=Path, default=REPO.parent)
    parser.add_argument('--output', type=Path, help='Parent for retained temporary run directories')
    args = parser.parse_args(argv)
    args.output = (args.output.resolve() if args.output else
                   Path(tempfile.mkdtemp(prefix='reasoner-comparisons-')).resolve())
    args.output.mkdir(parents=True, exist_ok=True)
    input_errors = args.output / ('input-errors-' + uuid4().hex + '.json')
    failed = False
    rejected = []
    for path in args.scenarios:
        try:
            scenario = validate_scenario(json.loads(path.read_text()))
        except (OSError, ValueError, TypeError) as error:
            print(f'{path}: invalid scenario: {error}', file=sys.stderr)
            rejected.append(dict(input=str(path.resolve()), error=str(error)))
            _write_json(input_errors, rejected)
            failed = True
            continue
        result, directory = run_comparison(scenario, args.entry, output=args.output, workspace=args.workspace)
        print(f'{result["status"]}: {directory / "result.json"}', flush=True)
        failed = failed or result['status'] != 'completed'
    return int(failed)


if __name__ == '__main__':
    sys.exit(main())
