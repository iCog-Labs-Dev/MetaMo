"""Explicit routing syntax; host-frame behavior is exercised through MeTTa."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location(
    'host_ingress', Path(__file__).resolve().parents[1] / 'host_ingress.py')
ingress = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ingress)


class HostIngressTests(unittest.TestCase):
    def test_explicit_correction_requires_exact_bounded_target(self):
        import json
        data = dict(session='s', commitment='c', plan='p', step='2', revision=0,
                    path='reports/report.txt')
        message = 'correction: ' + json.dumps(data)
        self.assertEqual(ingress.classify_message(message), 'Correction')
        self.assertEqual(ingress.parse_correction(message), data)
        for field, value in (('session', ''), ('step', 2), ('revision', True),
                             ('revision', -1), ('revision', 9007199254740992),
                             ('path', 'a' * 257), ('path', 'a\nb'), ('path', '\ud800')):
            with self.subTest(field=field, value=value):
                changed = dict(data, **{field: value})
                self.assertEqual(ingress.classify_message('correction: ' + json.dumps(changed)),
                                 'InvalidInput')
        for payload in ('{}', '[]', '"path"', '{',
                        json.dumps(dict(data, grant=True)),
                        json.dumps(data)[:-1] + ', "step":"2"}'):
            self.assertEqual(ingress.classify_message('correction: ' + payload), 'InvalidInput')
        self.assertEqual(ingress.classify_message('correction: reports/report.txt'), 'InvalidInput')

    def test_irc_envelope_preserves_body_and_sender(self):
        for body in ('hello', 'follow-up: more: detail', 'https://example.org',
                     'write a note: hello', '(send "quoted text")', '  hello  '):
            self.assertEqual(ingress.normalize_transport('Nahom: ' + body, 'irc'),
                             ('Nahom', body, ''))

    def test_other_channels_preserve_colons_and_batch_text(self):
        for channel in ('local', 'telegram', 'slack', 'mattermost'):
            for body in ('Nahom: hello', 'follow-up: more', 'A: one | B: two'):
                self.assertEqual(ingress.normalize_transport(body, channel), ('', body, ''))

    def test_irc_batches_are_held_atomically(self):
        for raw in ('Nahom: hello | Nahom: follow-up: more',
                    'Nahom: hello | Other: cancel: stop',
                    'Nahom: explain a | b'):
            self.assertEqual(ingress.ingest_transport(raw, 'irc'),
                             '(HostInput Held AmbiguousIrcBatch)')

    def test_malformed_irc_never_enters_interpreter(self):
        for raw in ('hello', ': hello', 'bad nick: hello', 'Nahom: hi\nOther: bye',
                    'Nahom: hi\rbye'):
            self.assertEqual(ingress.ingest_transport(raw, 'irc'),
                             '(HostInput Held InvalidIrcEnvelope)')
        for raw in ('Nahom: ', 'Nahom: follow-up: ', 'Nahom: \ud800', 'a' * 4097):
            self.assertEqual(ingress.ingest_transport(raw, 'irc'),
                             '(HostInput Held InvalidInput)')

    def test_explicit_replace(self):
        for message in ('replace: summarize B', ' REPLACE: changed task ',
                        'replace: (send "not executable")'):
            self.assertEqual(ingress.classify_message(message), 'Replace')

    def test_explicit_cancel(self):
        for message in ('cancel: no longer needed', ' CANCEL: changed plans ',
                        'cancel: (send "not executable")'):
            self.assertEqual(ingress.classify_message(message), 'Cancel')

    def test_explicit_followup(self):
        for message in ('follow-up: add examples', ' FOLLOW-UP: more detail ',
                        'follow-up: (send "quoted text")'):
            self.assertEqual(ingress.classify_message(message), 'FollowUp')

    def test_ambiguous_or_unrelated_is_not_followup(self):
        for message in ('yes', 'continue', 'read another file', 'cancel', 'replace',
                        'This text mentions follow-up: but is not a marker'):
            self.assertEqual(ingress.classify_message(message), 'NewTask')

    def test_invalid_input(self):
        for message in ('', ' ', 'follow-up:', 'follow-up:   ', 'cancel:',
                        'cancel:   ', 'replace:', 'replace:   ', 'a' * 4097,
                        'follow-up: bad\x00input', '\ud800', None, [], 1):
            self.assertEqual(ingress.classify_message(message), 'InvalidInput')

    def test_invalid_input_does_not_enter_interpreter(self):
        for message in (None, '', '\ud800'):
            self.assertEqual(ingress.ingest(message), '(HostInput Held InvalidInput)')


if __name__ == '__main__':
    unittest.main()
