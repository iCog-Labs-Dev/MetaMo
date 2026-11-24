"""Portable copies of retained benchmark artifacts; no execution or outcome substitution."""
import json
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

from reasoner_benchmark_formats import validate_result


# Example: retain complete trace rows before an interrupted final write.
def read_trace(directory):
    path = directory / 'output/trajectory.jsonl'
    if not path.is_file():
        return [], 'MissingTrace'
    rows = []
    for line in path.read_text().splitlines():
        try:
            row = json.loads(line)
            if not isinstance(row, dict) or 'cycle' not in row or 'split' not in row:
                return rows, 'InvalidTraceRow'
            rows.append(row)
        except ValueError:
            return rows, 'TruncatedTrace'
    return rows, None


# Example: scoring uses the valid prefix without treating a missing suffix as failed predictions.
def read_trajectory(directory):
    return read_trace(directory)[0]


# Example: two observed cycles of four produce explicit missing cycles [3, 4].
def trace_status(result, directory):
    rows, error = read_trace(directory)
    expected = result.get('scenario', {}).get('resource_limits', {}).get('max_cycles')
    observed = {row['cycle'] for row in rows}
    missing = sorted(set(range(1, expected + 1)) - observed) if expected is not None else None
    state = 'missing' if error == 'MissingTrace' else 'partial' if error or missing else 'complete'
    return dict(state=state, error=error, expected_cycles=expected, observed_cycles=len(observed), missing_cycles=missing,
                cycle_references=[row['cycle_ref'] for row in rows if row.get('cycle_ref')])


# Example: missing reasoner evidence differs from a valid artifact containing zero proposals.
def reasoner_status(directory):
    path = directory / 'output/reasoner-evidence.json'
    if not path.is_file():
        return 'missing'
    try:
        value = json.loads(path.read_text())
        required = {'cycles', 'admissions', 'receipts', 'selections', 'comparator_routes'}
        return 'available' if isinstance(value, dict) and required <= value.keys() else 'incomplete'
    except (OSError, ValueError):
        return 'unreadable'


# Example: failed-run evidence coverage remains separate from the numerical outcome rates.
def evidence_status(result, directory):
    trace, reasoner = trace_status(result, directory), reasoner_status(directory)
    return dict(trajectory=trace, reasoner=reasoner,
                export_window_complete=trace['state'] == 'complete' and reasoner == 'available')


# Example: copy diagnostics and identities, without exporting private runtime/memory working directories.
def artifact_paths(directory):
    roots = ('scenario.json', 'result.json', 'execution.json', 'imports.json', 'stdout.log', 'stderr.log')
    paths = [directory / name for name in roots if (directory / name).is_file()]
    paths += sorted((directory / 'output').glob('*.json'))
    paths += sorted((directory / 'output').glob('*.jsonl'))
    return paths


# Example: a truncated result remains an indexed run with its raw artifact preserved.
def read_result(directory):
    path = directory / 'result.json'
    if not path.is_file():
        return None, 'MissingResult'
    try:
        return validate_result(json.loads(path.read_text())), None
    except (OSError, ValueError, KeyError, TypeError) as error:
        return None, 'UnreadableResult: ' + str(error)


# Example: CLI discovery includes interrupted runs with a scenario but no completed result file.
def discover_runs(output):
    results, directories = [], {}
    for directory in sorted(output.iterdir()):
        if not directory.is_dir() or not any((directory / name).is_file() for name in ('scenario.json', 'result.json')):
            continue
        result, error = read_result(directory)
        directories[result['run_id'] if result else directory.name] = directory
        if not error:
            results.append(result)
    return results, directories


# Example: each indexed trace retains its own decisions, outcomes and original cycle references.
def run_index(results, directories):
    by_id = {result['run_id']: result for result in results}
    return [run_record(by_id.get(identity), directory) for identity, directory in sorted(directories.items())]


# Example: missing metadata is explicit and never becomes a successful or refuted task outcome.
def run_record(result, directory):
    _, error = read_result(directory)
    metadata = result or {}
    return dict(run_id=metadata.get('run_id', directory.name), status=metadata.get('status'), metadata_error=error,
                directory=directory.name, result=directory.name + '/result.json' if (directory / 'result.json').is_file() else None,
                trace=directory.name + '/output/trajectory.jsonl', evidence_at_export=evidence_status(metadata, directory),
                artifacts=[directory.name + '/' + str(path.relative_to(directory)) for path in artifact_paths(directory)])


# Example: archive bytes preserve divergent receipts exactly; no path or outcome inside them is rewritten.
def write_archive(output, directories):
    path = output / 'benchmark-export.zip'
    with ZipFile(path, 'w', compression=ZIP_DEFLATED) as archive:
        archive.write(output / 'summary.json', 'summary.json')
        for directory in directories.values():
            for artifact in artifact_paths(directory):
                archive.write(artifact, directory.name + '/' + str(artifact.relative_to(directory)))
        for errors in sorted(output.glob('input-errors-*.json')):
            archive.write(errors, errors.name)
    return path
