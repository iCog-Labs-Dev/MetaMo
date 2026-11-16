"""Explicit live runtime diagnostics invoked through the normal Janus launcher.

Set OMEGACLAW_LIVE_OUTPUT to an existing isolated artifact directory. Import this
module from a MeTTa entry and call runtime, embedding, memory, or provider. Only
provider makes LLM requests; inputs are fixed synthetic text, never workspace data.
"""
import importlib
from importlib import metadata
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path(os.environ["OMEGACLAW_LIVE_OUTPUT"]).resolve()
sys.path.insert(0, str(ROOT / 'repos/OmegaClaw-Core'))


def runtime():
    versions = {}
    for name in ('numpy', 'openai', 'chromadb', 'torch', 'transformers', 'sentence-transformers', 'python-dotenv', 'uagents', 'ddgs'):
        try:
            versions[name] = metadata.version(name)
        except metadata.PackageNotFoundError:
            versions[name] = 'missing'
    imports = {}
    for name in ('lib_llm_ext', 'chromadb', 'sentence_transformers', 'requests', 'websocket', 'uagents', 'ddgs'):
        try:
            importlib.import_module(name)
            imports[name] = 'ok'
        except Exception as error:
            imports[name] = type(error).__name__
    report = {'python': sys.version, 'versions': versions, 'imports': imports,
              'asi_key_present': bool(os.environ.get('ASI_API_KEY')),
              'gateway_override_present': bool(os.environ.get('GATEWAY_URL'))}
    (OUTPUT / 'runtime.json').write_text(json.dumps(report, indent=2))
    print(json.dumps(report, indent=2))
    return 1


def provider():
    import lib_llm_ext as llm
    model = llm._get_provider('ASICloud')
    model._client = model._create_client().with_options(timeout=30, max_retries=0)
    report = {'provider': 'ASICloud', 'model': model._model_name}
    try:
        report['confirmation'] = llm.executionConfirmationScore('ASICloud', 'Yes, go ahead and read that file.', 'Read the approved local test file.')
        report['semantics'] = llm.extractSemantics('ASICloud', 'Please read the approved local test file.')
        report['passed'] = report['confirmation'] > .75 and 'execution-request' in report['semantics']
    except Exception as error:
        report['error_type'] = type(error).__name__
        report['passed'] = False
    (OUTPUT / 'provider.json').write_text(json.dumps(report, indent=2))
    print(json.dumps(report, indent=2))
    return int(report['passed'])


def embedding():
    import lib_llm_ext as llm
    report = {}
    try:
        llm.initLocalEmbedding()
        vector = llm.useLocalEmbedding('OmegaClaw isolated integration check')
        report = {'passed': bool(vector), 'dimensions': len(vector)}
    except Exception as error:
        report = {'passed': False, 'error_type': type(error).__name__, 'message': str(error)[:1200]}
    (OUTPUT / 'embedding.json').write_text(json.dumps(report, indent=2))
    print(json.dumps(report, indent=2))
    return int(report['passed'])


def memory():
    os.environ['CHROMA_DB_PATH'] = str((OUTPUT / 'memory-check').resolve())
    sys.path.insert(0, str(ROOT / 'repos/petta_lib_chromadb'))
    sys.path.insert(0, str(ROOT / 'repos/OmegaClaw-Core/src'))
    import lib_llm_ext as llm
    llm.initLocalEmbedding()
    import lib_chromadb as memory
    import frame_relation
    payload = 'MOTIVOS_STATE_V1 time:2026-09-24 G:((goal progress 0.4)) AG:() M:((modulator urgency 0.2)) S:()'
    vector = llm.useLocalEmbedding(payload)
    item = memory.remember(payload, vector, '2026-09-24')
    rows = memory.query(vector, 1)
    parsed = llm.parseMotivosState(rows)
    frame_relation._get_collection('Local')
    same_path = (memory.CLIENT.get_settings().persist_directory ==
                 frame_relation._chroma_client.get_settings().persist_directory)
    report = {'passed': rows == [['2026-09-24', payload]] and '(goal progress 0.4)' in parsed and same_path,
              'shared_store_path': same_path, 'dimensions': len(vector), 'parsed': parsed,
              'memory_id': item}
    (OUTPUT / 'memory.json').write_text(json.dumps(report, indent=2))
    print(json.dumps(report, indent=2))
    return int(report['passed'])
