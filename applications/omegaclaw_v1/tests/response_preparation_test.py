"""Bounded host preparation; no providers, channels or dispatch are invoked."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import sys
import types
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import host_operations as host
import host_dispatch_config as config


def read_outcome(cycle=1, text='observed file content'):
    command = ['read-file', '/allowed/input.txt']
    return ['OperationOutcome',
            ['OperationDecision', ['OperationContext', 'session', cycle, 'frame'],
             'execute-skill', command, ['DispatchTicket', f'ticket-{cycle}']],
            ['attempted-command', command.copy()], 'Success',
            ['DispatchResult', 'Executed', 'Feasible', text]]


class ResponsePreparationTests(unittest.TestCase):
    def setUp(self):
        self.context = ['OperationContext', 'session', 3, 'frame']
        self.observations = [read_outcome()]
        self.llm = types.SimpleNamespace(PROMPT_DELIMITER=':-:-:-:',
                                        callProvider=Mock(return_value='{"text":"File content summary."}'))
        self.janus = Mock()
        self.channel = Mock()
        patches = patch.dict(sys.modules, {'lib_llm_ext': self.llm, 'janus': self.janus,
                                          'local_channel': self.channel, 'irc': self.channel})
        patches.start()
        self.addCleanup(patches.stop)
        # Preparation must not provision a binding or use the dispatch ledger.
        installer = patch.object(config, 'provision', side_effect=AssertionError('unexpected install'))
        installer.start()
        self.addCleanup(installer.stop)

    def tearDown(self):
        self.assertEqual(self.janus.mock_calls, [])
        self.assertEqual(self.channel.mock_calls, [])

    def prepare(self, observations=None, request='What does the file contain?'):
        return host.prepare_response('ASICloud', request, self.context,
                                     self.observations if observations is None else observations)

    def test_uses_existing_provider_and_exact_observed_content(self):
        self.observations.append(read_outcome(2, 'second file\n"quoted" content'))
        before = copy.deepcopy((self.context, self.observations))
        self.assertEqual(self.prepare(), '(ResponsePrepared "File content summary.")')
        args, kwargs = self.llm.callProvider.call_args
        self.assertEqual(args[0], 'ASICloud')
        self.assertEqual(kwargs, {'max_tokens': 1024})
        system, payload = args[1].split(self.llm.PROMPT_DELIMITER, 1)
        self.assertIn('Do not invent', system)
        value = json.loads(payload)
        self.assertEqual(value['observations'], [
            {'path': '/allowed/input.txt', 'content': 'observed file content'},
            {'path': '/allowed/input.txt', 'content': 'second file\n"quoted" content'}])
        self.assertEqual((self.context, self.observations), before)

    def test_no_observations_and_bad_requests_skip_provider(self):
        for rows in ([], None, {}, 'summary', [read_outcome()] * 17):
            with self.subTest(rows=rows):
                self.assertEqual(host.prepare_response('ASICloud', 'Question', self.context, rows),
                                 '(ResponseNoAction InvalidInput)')
        for request in ('', '  ', 'x' * 1201, None, [], 'bad\x00'):
            self.assertEqual(self.prepare(request=request), '(ResponseNoAction InvalidInput)')
        self.llm.callProvider.assert_not_called()

    def test_rejects_unusable_or_uncorrelated_observations(self):
        variants = []
        for status in ('Failure', 'Blocked', 'Unobserved'):
            row = read_outcome()
            row[3] = status
            variants.append(row)
        for index, value in ((1, 'other-session'), (2, 4), (2, True), (2, 0), (3, 'other-frame')):
            row = read_outcome()
            row[1][1][index] = value
            variants.append(row)
        for path, value in (((1, 2), 'respond'), ((1, 3, 0), 'send'),
                            ((1, 4, 0), 'DispatchUnavailable'),
                            ((2, 1), ['read-file', '/different.txt']),
                            ((4, 1), 'Blocked'), ((4, 2), 'OtherReason'),
                            ((4, 3), ['Error', 'read-file', 'FileUnavailable'])):
            row = read_outcome()
            target = row
            for index in path[:-1]:
                target = target[index]
            target[path[-1]] = value
            variants.append(row)
        variants.extend([[], {}, 'raw model evidence'])
        for row in variants:
            with self.subTest(row=row):
                self.assertEqual(self.prepare([row]), '(ResponseNoAction InvalidInput)')
        self.llm.callProvider.assert_not_called()

    def test_duplicate_observation_is_not_additional_evidence(self):
        self.assertEqual(self.prepare([read_outcome(), read_outcome()]),
                         '(ResponseNoAction InvalidInput)')
        self.llm.callProvider.assert_not_called()

    def test_invalid_context_and_provider_skip_call(self):
        for context in ([], ['OperationContext', 'session', True, 'frame'],
                        ['OperationContext', '', 1, 'frame']):
            self.assertEqual(host.prepare_response('ASICloud', 'Question', context, self.observations),
                             '(ResponseNoAction InvalidInput)')
        self.assertEqual(host.prepare_response('', 'Question', self.context, self.observations),
                         '(ResponseNoAction InvalidInput)')
        self.llm.callProvider.assert_not_called()

    def test_evidence_bounds_reject_without_truncation(self):
        self.assertEqual(self.prepare([read_outcome(text='x' * 8193)]),
                         '(ResponseNoAction InvalidInput)')
        self.context[2] = 4
        self.assertEqual(self.prepare([read_outcome(i, 'x' * 8192) for i in range(1, 5)]),
                         '(ResponseNoAction InputTooLarge)')
        self.assertEqual(self.prepare([read_outcome(text='界' * 8192)]),
                         '(ResponsePrepared "File content summary.")')
        self.assertEqual(self.llm.callProvider.call_count, 1)

    def test_empty_file_is_valid_observed_content(self):
        self.assertEqual(self.prepare([read_outcome(text='')]),
                         '(ResponsePrepared "File content summary.")')

    def test_explicit_no_action(self):
        self.llm.callProvider.return_value = '{"no_action":true}'
        self.assertEqual(self.prepare(), '(ResponseNoAction InsufficientEvidence)')

    def test_bad_provider_outputs_do_not_prepare_text(self):
        for raw in ('', '()', 'plain prose', '```json\n{"text":"hello"}\n```',
                    '{"text":"hello","text":"other"}', '{"text":"hello","command":"send"}',
                    '{"text":"hello","no_action":true}', '{"no_action":1}',
                    '{"no_action":false}', '[]', 'null', '{"text":null}',
                    '{"text":NaN}', '{"text":[]}', '{"text":"  "}',
                    '{"text":"bad\\u0000"}', '{"text":"\\ud800"}', json.dumps({'text': 'x' * 1201}),
                    json.dumps({'text': 'x'}) + ' ' * 8192, None):
            with self.subTest(raw=raw):
                self.llm.callProvider.return_value = raw
                self.assertEqual(self.prepare(), '(ResponseNoAction InvalidResponse)')

    def test_output_is_escaped_text_and_matches_send_limits(self):
        for text in ('x' * 1200, 'Observed "quotes"\nsecond line\tend', '(send "inert text")'):
            self.llm.callProvider.return_value = json.dumps({'text': text})
            self.assertEqual(self.prepare(), config.encode(config.record('ResponsePrepared', text)))
            config.binding({'skill': 'send', 'arguments': [text]}, 'frame', [],
                           {'channel': 'local', 'recipient': 'stdout'})

    def test_provider_failure_has_no_retry_or_exception_leak(self):
        self.llm.callProvider.side_effect = RuntimeError('secret credential detail')
        self.assertEqual(self.prepare(), '(ResponseNoAction ProviderUnavailable)')
        self.llm.callProvider.assert_called_once()

    def test_existing_asicloud_registry_with_mock_transport(self):
        source = Path(__file__).resolve().parents[4] / 'repos/OmegaClaw-Core/lib_llm_ext.py'
        spec = importlib.util.spec_from_file_location('response_provider_test', source)
        llm = importlib.util.module_from_spec(spec)
        with patch('dotenv.load_dotenv'):
            spec.loader.exec_module(llm)
        client = Mock()
        client.chat.completions.create.return_value = types.SimpleNamespace(choices=[
            types.SimpleNamespace(message=types.SimpleNamespace(content='{"text":"Observed summary"}'))])
        with patch.dict(sys.modules, {'lib_llm_ext': llm}), \
                patch.dict(os.environ, {'ASI_API_KEY': 'test-only'}, clear=True), \
                patch.object(llm.openai, 'OpenAI', return_value=client):
            self.assertEqual(self.prepare(), '(ResponsePrepared "Observed summary")')
        client.chat.completions.create.assert_called_once()
        request = client.chat.completions.create.call_args.kwargs
        self.assertEqual(request['model'], 'minimax/minimax-m3')
        self.assertEqual(request['max_tokens'], 1024)
        self.assertEqual(json.loads(request['messages'][1]['content'])['observations'][0]['content'],
                         'observed file content')


class ResponseQueueTests(unittest.TestCase):
    def setUp(self):
        self.janus = Mock()
        self.janus.query_once.return_value = {
            'truth': True, 'Context': ['OperationContext', 'session', 2, 'frame'],
            'Owner': '("session" "frame" NoCommitment "task")'}
        self.provider = Mock()
        self.destination = {'channel': 'local', 'recipient': 'stdout'}
        self.observations = [read_outcome()]
        host._pending_response = None
        modules = patch.dict(sys.modules, {'janus': self.janus, 'lib_llm_ext': self.provider})
        modules.start()
        self.addCleanup(modules.stop)
        self.addCleanup(setattr, host, '_pending_response', None)

    def queue(self):
        return host.queue_response_preparation('ASICloud', 'Summarize', self.observations, self.destination)

    def test_queue_copies_trusted_inputs_without_calling_provider(self):
        self.assertEqual(self.queue(), '(ResponsePreparationQueued)')
        self.observations[0][4][3] = 'later mutation'
        self.destination['channel'] = 'irc'
        self.assertEqual(host._pending_response[2][0][4][3], 'observed file content')
        self.assertEqual(host._pending_response[3]['channel'], 'local')
        self.assertEqual(self.provider.mock_calls, [])

    def test_invalid_queue_clears_pending_input(self):
        self.queue()
        self.destination['channel'] = 'irc'
        self.assertEqual(self.queue(), '(ResponseNoAction InvalidInput)')
        self.assertIsNone(host._pending_response)
        self.assertEqual(self.provider.mock_calls, [])

    def test_missing_session_or_wrong_evidence_is_not_queued(self):
        self.janus.query_once.return_value = {'truth': False}
        self.assertEqual(self.queue(), '(ResponseNoAction MissingSession)')
        self.janus.query_once.return_value = {
            'truth': True, 'Context': ['OperationContext', 'other-session', 2, 'frame'], 'Owner': '()'}
        self.assertEqual(self.queue(), '(ResponseNoAction InvalidInput)')
        self.assertIsNone(host._pending_response)
        self.assertEqual(self.provider.mock_calls, [])

    def test_required_reads_must_all_have_successful_observations(self):
        def queue(paths):
            return host.queue_response_preparation('ASICloud', 'Summarize', self.observations,
                                                   self.destination, required_reads=paths)
        self.assertEqual(queue(['/allowed/input.txt']), '(ResponsePreparationQueued)')
        self.assertTrue(host._pending_response[-2])
        self.assertEqual(queue(['/allowed/input.txt', '/missing']),
                         '(ResponseNoAction MissingRequiredReads)')
        self.assertIsNone(host._pending_response)
        for paths in ([], 'path', ['/x'] * 2, ['/x'] * 17, [None], ['']):
            with self.subTest(paths=paths):
                self.assertEqual(queue(paths), '(ResponseNoAction InvalidInput)')
                self.assertIsNone(host._pending_response)
        self.assertEqual(self.provider.mock_calls, [])

    def test_required_reads_can_span_multiple_admitted_cycles(self):
        second = read_outcome(2)
        second[1][3][1] = '/second'
        second[2][1][1] = '/second'
        self.observations.append(second)
        self.assertEqual(host.queue_response_preparation('ASICloud', 'Summarize', self.observations,
            self.destination, required_reads=['/allowed/input.txt', '/second']),
            '(ResponsePreparationQueued)')
        self.assertEqual(self.provider.mock_calls, [])

    def test_answer_identity_ignores_order_duplicates_and_provider_wording(self):
        evidence = [{'path': '/a', 'content': 'A'}, {'path': '/b', 'content': 'B'}]
        key = host._answer_key('owner', 'request', evidence, self.destination)
        self.assertEqual(key, host._answer_key('owner', 'request',
            list(reversed(evidence)) + evidence[:1], self.destination))
        for owner, request, rows, destination in (
                ('new-task-or-input', 'request', evidence, self.destination),
                ('owner', 'new request', evidence, self.destination),
                ('owner', 'request', [{'path': '/a', 'content': 'changed'}], self.destination),
                ('owner', 'request', evidence, {'channel': 'local', 'recipient': 'other'})):
            self.assertNotEqual(key, host._answer_key(owner, request, rows, destination))


if __name__ == '__main__':
    unittest.main()
