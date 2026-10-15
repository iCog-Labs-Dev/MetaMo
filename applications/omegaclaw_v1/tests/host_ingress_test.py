"""Explicit routing syntax; host-frame behavior is exercised through MeTTa."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location(
    'host_ingress', Path(__file__).resolve().parents[1] / 'host_ingress.py')
ingress = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ingress)


class HostIngressTests(unittest.TestCase):
    def test_explicit_followup(self):
        for message in ('follow-up: add examples', ' FOLLOW-UP: more detail ',
                        'follow-up: (send "quoted text")'):
            self.assertEqual(ingress.classify_message(message), 'FollowUp')

    def test_ambiguous_or_unrelated_is_not_followup(self):
        for message in ('yes', 'continue', 'read another file', 'cancel',
                        'This text mentions follow-up: but is not a marker'):
            self.assertEqual(ingress.classify_message(message), 'NewTask')

    def test_invalid_input(self):
        for message in ('', ' ', 'follow-up:', 'follow-up:   ', 'a' * 4097,
                        'follow-up: bad\x00input', '\ud800', None, [], 1):
            self.assertEqual(ingress.classify_message(message), 'InvalidInput')

    def test_invalid_input_does_not_enter_interpreter(self):
        for message in (None, '', '\ud800'):
            self.assertEqual(ingress.ingest(message), '(HostInput Held InvalidInput)')


if __name__ == '__main__':
    unittest.main()
