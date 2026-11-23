"""Launch isolated comparisons through the common launcher; retain every run.

Trusted MeTTa scenarios use normal runtime APIs; task/prediction grading remains separate.
"""
import argparse
import copy
import hashlib
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
import reasoner_benchmark_matrix as matrix
import reasoner_benchmark_metrics as metrics

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
def run_comparison(scenario, entry=None, *, output=None, workspace=REPO.parent):
    scenario = copy.deepcopy(validate_scenario(scenario))
    if output is not None:
        output = Path(output).resolve()
        output.mkdir(parents=True, exist_ok=True)
    directory = Path(tempfile.mkdtemp(prefix='reasoner-' + uuid4().hex + '-', dir=output)).resolve()
    environment = _environment(directory)
    if scenario['configuration']['seed'] is not None:
        environment['PYTHONHASHSEED'] = str(scenario['configuration']['seed'])
    _write_json(directory / 'scenario.json', scenario)
    generated = entry is None
    try:
        if generated:
            entry = matrix.write_entry(scenario, directory)
        setup_error = None
    except (OSError, ValueError) as error:
        setup_error = str(error)
    command = [sys.executable, str(LAUNCHER), str(Path(entry).resolve()) if entry else '',
               '--workspace', str(Path(workspace).resolve()), '--runtime-dir', str(directory / 'runtime'),
               '--report', str(directory / 'imports.json')]
    if generated:
        command.append('reasoner=' + scenario['adapter']['id'])
    started = time.monotonic()
    if setup_error:
        status, error, code = 'unavailable', setup_error, None
        (directory / 'stdout.log').touch()
        (directory / 'stderr.log').write_text(setup_error)
    else:
        status, error, code = _execute(command, directory, environment,
                                      scenario['resource_limits']['max_elapsed_ms'] / 1000)
    result = validate_result(dict(schema_version=1, run_id=directory.name, scenario=scenario,
        status=status, error=error, elapsed_ms=int((time.monotonic() - started) * 1000),
        trace_references=[], measurements={}))
    if generated:
        _retain_runtime_report(result, directory, workspace)
        validate_result(result)
    _write_json(directory / 'execution.json', dict(command=command, returncode=code,
        runtime_dir=str(directory / 'runtime'), memory_dir=environment['OMEGACLAW_BENCHMARK_MEMORY'],
        output_dir=environment['OMEGACLAW_BENCHMARK_OUTPUT']))
    _write_json(directory / 'result.json', result)
    return result, directory


# Example: timeout-truncated reports retain failure status and any complete observed evidence.
def _retain_runtime_report(result, directory, workspace=REPO.parent):
    audit = _read_runtime_report(directory)
    _retain_source_audit(audit, directory, workspace)
    result['runtime_configuration'] = audit
    _retain_trajectory_references(result, directory)
    _check_runtime_configuration(result, audit)
    result['measurements'] = metrics.measure(result, directory)


# Example: an interrupted JSON write is an incomplete report, never a completed episode.
def _read_runtime_report(directory):
    report = directory / 'output/runtime-configuration.json'
    try:
        audit = json.loads(report.read_text()) if report.is_file() else {}
        return audit if isinstance(audit, dict) else {}
    except (OSError, ValueError):
        return {}


# Example: retain actual loaded-file hashes even when another runtime report is incomplete.
def _retain_source_audit(audit, directory, workspace):
    try:
        imports = directory / 'imports.json'
        sources = {row['resolved'] for row in json.loads(imports.read_text())} if imports.is_file() else set()
        audit['source_sha256'] = {source: hashlib.sha256(Path(source).read_bytes()).hexdigest()
                                  for source in sources if Path(source).is_file()}
    except (OSError, ValueError, KeyError, TypeError) as error:
        audit['source_report_error'] = str(error)
    audit['observed_source_versions'] = _source_versions(Path(workspace))


# Example: metrics cannot turn a rejected influence configuration into a successful run.
def _check_runtime_configuration(result, audit):
    if result['status'] != 'completed' or _configuration_matches(result['scenario'], audit):
        return
    error = 'Runtime did not confirm the requested configuration and completed episode; see logs'
    if result['scenario']['configuration']['influence_cap'] > 0:
        error += '; positive influence requires retained predictive evidence'
    result.update(status='failed', error=error)


# Example: partial failed runs retain complete cycle identities before a truncated final row.
def _retain_trajectory_references(result, directory):
    trajectory = directory / 'output/trajectory.jsonl'
    if not trajectory.is_file():
        return
    with trajectory.open() as stream:
        for line in stream:
            try:
                row = json.loads(line)
                result['trace_references'].append(dict(artifact='output/trajectory.jsonl',
                    stage='Selection', identity=row['cycle_ref'], cycle_ref=row['cycle_ref']))
            except (ValueError, KeyError, TypeError):
                break


# Example: record actual checkout revisions alongside declared versions and loaded-file hashes.
def _source_versions(workspace):
    versions = {}
    for name, path in (('v1', REPO), ('core', workspace / 'repos/OmegaClaw-Core'), ('petta', workspace)):
        try:
            process = subprocess.run(['git', '-C', str(path), 'rev-parse', 'HEAD'],
                capture_output=True, text=True, timeout=5)
            versions[name] = process.stdout.strip() if process.returncode == 0 else None
        except (OSError, subprocess.TimeoutExpired):
            versions[name] = None
    return versions


# Example: a rejected configuration cannot be reported as an advisory comparison.
def _configuration_matches(scenario, audit):
    controls = {key: scenario['configuration'][key] for key in ('collection', 'influence', 'assessment', 'learning')}
    setting = audit.get('influence_setting', [])
    cap_matches = not controls['influence'] or (len(setting) == 4 and setting[2]
        and setting[2][3] == scenario['configuration']['influence_cap'])
    return (audit.get('complete') is True and audit.get('selection') == scenario['adapter']['id']
            and cap_matches
            and (not controls['collection'] or audit.get('intake_cycles', 0) > 0)
            and audit.get('effective_controls') == controls
            and audit.get('engine_version') == scenario['adapter']['engine_version']
            and (scenario['adapter']['id'] == 'disabled' or
                 audit.get('configuration_version') == scenario['adapter']['configuration_version']))


# Example: all variants retain identical task inputs, policies and resource allowances.
def run_matrix(scenario, variants=None, *, output=None, workspace=REPO.parent):
    variants = matrix.builtin_variants(scenario) if variants is None else variants
    comparisons = []
    if not isinstance(variants, list) or not variants:
        raise ValueError('matrix must be a nonempty list of adapter/configuration variants')
    for variant in variants:
        if not isinstance(variant, dict) or set(variant) != {'adapter', 'configuration'}:
            raise ValueError('each matrix variant must contain adapter and configuration')
        comparison = copy.deepcopy(scenario)
        comparison.update(adapter=copy.deepcopy(variant['adapter']), configuration=copy.deepcopy(variant['configuration']))
        comparisons.append(validate_scenario(comparison))
    runs = [run_comparison(comparison, output=output, workspace=workspace) for comparison in comparisons]
    metrics.write_report([result for result, _ in runs], output or runs[0][1])
    return runs


# Example: repeated scenario paths still produce independent runs and separate failure records.
def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('scenarios', nargs='+', type=Path)
    parser.add_argument('--entry', type=Path, help='Trusted executable driver; omit for the matched runtime matrix')
    parser.add_argument('--matrix', type=Path, help='JSON list of adapter/configuration variants, including optional registration modules')
    parser.add_argument('--workspace', type=Path, default=REPO.parent)
    parser.add_argument('--output', type=Path, help='Parent for retained temporary run directories')
    args = parser.parse_args(argv)
    if args.entry and args.matrix:
        parser.error('--entry smoke runs cannot also select --matrix')
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
        try:
            if args.entry:
                runs = [run_comparison(scenario, args.entry, output=args.output, workspace=args.workspace)]
            else:
                variants = json.loads(args.matrix.read_text()) if args.matrix else None
                runs = run_matrix(scenario, variants, output=args.output, workspace=args.workspace)
        except (OSError, ValueError, TypeError) as error:
            print(f'{path}: invalid matrix: {error}', file=sys.stderr)
            rejected.append(dict(input=str(path.resolve()), error=str(error)))
            _write_json(input_errors, rejected)
            failed = True
            continue
        for result, directory in runs:
            print(f'{result["status"]}: {directory / "result.json"}', flush=True)
            failed = failed or result['status'] != 'completed'
    metrics.summarize_directory(args.output)
    print(f'Summary: {args.output / "summary.json"}', flush=True)
    return int(failed)


if __name__ == '__main__':
    sys.exit(main())
