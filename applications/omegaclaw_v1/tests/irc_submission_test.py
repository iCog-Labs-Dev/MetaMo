"""Submission observations and UTF-8 framing; no network or real sleeps."""
import importlib.util
import os
from pathlib import Path
import unittest
from unittest.mock import Mock, patch

APP = Path(__file__).resolve().parents[1]
CORE = Path(os.environ.get('OMEGACLAW_CORE_TEST_ROOT', APP.parents[2] / 'repos/OmegaClaw-Core'))
DESTINATION = 'irc:irc.example.org:6667:#room'


class IrcSubmissionTests(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location('irc_submission', CORE / 'channels/irc.py')
        self.irc = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.irc)
        sleeper = patch.object(self.irc.time, 'sleep')
        self.sleep = sleeper.start()
        self.addCleanup(sleeper.stop)
        self.sock = self.connect()

    def connect(self, channel='#room'):
        with patch.object(self.irc.threading, 'Thread'):
            self.irc.start_irc(channel, 'IRC.Example.org', 6667, auth_secret='')
        sock = Mock()
        self.assertTrue(self.irc._install_connection(sock, 'IRC.Example.org', 6667,
                                                      channel, self.irc._run_id))
        self.assertTrue(self.irc._mark_registered(sock, self.irc._run_id))
        return sock

    def observation(self, status, reason, completed=0, total=1, destination=DESTINATION):
        return (f'(SendObservation "{destination}" '
                f'(TransportSubmission {status} {reason} {completed} {total}))')

    def test_success_is_submission_and_duplicate_is_not_another_submission(self):
        self.assertEqual(self.irc.send_message('hello'), self.observation('Submitted', 'Complete', 1))
        self.sock.sendall.assert_called_once_with(b'PRIVMSG #room :hello\r\n')
        self.assertEqual(self.irc.send_message('hello'), self.observation('NotSubmitted', 'SuppressedDuplicate'))
        self.assertEqual(self.sock.sendall.call_count, 1)

    def test_disconnected_missing_socket_and_unregistered_never_submit(self):
        for field, value in (('_connected', False), ('_running', False), ('_sock', None)):
            with self.subTest(field=field), patch.object(self.irc, field, value):
                self.assertEqual(self.irc.send_message('hello'),
                                 self.observation('NotSubmitted', 'Disconnected'))
                self.assertIsNone(self.irc._last_submission)
        self.sock.sendall.assert_not_called()
        # A later explicit call after a definite non-submission is not suppressed.
        self.assertEqual(self.irc.send_message('hello'), self.observation('Submitted', 'Complete', 1))

    def test_first_sendall_exception_is_uncertain_even_with_no_completed_chunks(self):
        self.sock.sendall.side_effect = OSError('private exception detail')
        result = self.irc.send_message('hello\nsecond')
        self.assertEqual(result, self.observation('Uncertain', 'WriteUncertain', 0, 2))
        self.assertNotIn('private', result)
        self.assertIsNone(self.irc._last_submission)
        self.sock.sendall.assert_called_once()

    def test_partial_submission_stops_without_retry_or_remaining_chunks(self):
        self.sock.sendall.side_effect = [None, OSError('partial write'), None]
        self.assertEqual(self.irc.send_message('one\ntwo\nthree'),
                         self.observation('Uncertain', 'WriteUncertain', 1, 3))
        self.assertEqual(self.sock.sendall.call_count, 2)
        self.assertIsNone(self.irc._last_submission)

    def test_exception_after_write_is_not_reported_as_definite_non_submission(self):
        self.sleep.side_effect = RuntimeError('interrupted after write')
        self.assertEqual(self.irc.send_message('one\ntwo'),
                         self.observation('Uncertain', 'SubmissionInterrupted', 1, 2))
        self.sock.sendall.assert_called_once()
        self.assertIsNone(self.irc._last_submission)

    def test_pacing_failure_after_final_write_does_not_erase_observed_submission(self):
        self.sleep.side_effect = RuntimeError('pacing interrupted')
        self.assertEqual(self.irc.send_message('one'),
                         self.observation('Submitted', 'Complete', 1, 1))
        self.sock.sendall.assert_called_once()
        self.assertIsNotNone(self.irc._last_submission)

    def test_multibyte_wire_bounds_and_content_preservation(self):
        for text in ('x' * 1200, '界' * 1200, '🙂' * 1200, ('A界🙂 ' * 240)):
            with self.subTest(text=text[:8]):
                self.sock.sendall.reset_mock()
                result = self.irc.send_message(text)
                packets = [call.args[0] for call in self.sock.sendall.call_args_list]
                self.assertEqual(result, self.observation('Submitted', 'Complete', len(packets), len(packets)))
                chunks = []
                for packet in packets:
                    self.assertLessEqual(len(packet), 512)
                    self.assertTrue(packet.startswith(b'PRIVMSG #room :'))
                    self.assertTrue(packet.endswith(b'\r\n'))
                    body = packet[len(b'PRIVMSG #room :'):-2]
                    self.assertNotIn(b'\r', body)
                    self.assertNotIn(b'\n', body)
                    chunks.append(body.decode('utf-8'))
                self.assertEqual(''.join(chunks), text)

    def test_wire_limit_includes_long_recipient_and_crlf(self):
        channel = '#' + 'c' * 49
        self.sock = self.connect(channel)
        budget = 512 - len(f'PRIVMSG {channel} :\r\n'.encode())
        self.irc.send_message('x' * (budget + 1))
        self.assertEqual([len(call.args[0]) for call in self.sock.sendall.call_args_list],
                         [512, 512 - budget + 1])

    def test_newlines_are_message_boundaries_not_protocol_commands(self):
        text = 'one\\nJOIN #other\nPRIVMSG #other :inert\ttext'
        self.assertEqual(self.irc.send_message(text), self.observation('Submitted', 'Complete', 3, 3))
        self.assertEqual([call.args[0] for call in self.sock.sendall.call_args_list],
                         [b'PRIVMSG #room :one\r\n', b'PRIVMSG #room :JOIN #other\r\n',
                          b'PRIVMSG #room :PRIVMSG #other :inert\ttext\r\n'])

    def test_all_input_is_validated_before_first_effect(self):
        for text in ('', ' \n\t', None, ['hello'], 'okay\ninvalid\r', 'okay\n\x00',
                     'okay\n\x01ACTION hi\x01', 'okay\n\x7f', 'okay\n\ud800'):
            with self.subTest(text=text):
                self.assertEqual(self.irc.send_message(text),
                                 self.observation('NotSubmitted', 'InvalidText', 0, 0))
        self.sock.sendall.assert_not_called()
        self.assertIsNone(self.irc._last_submission)

    def test_destination_injection_cannot_reach_socket(self):
        for channel in ('#one,#two', '#one\r\nJOIN #two', '#one two', '#one:two', '#é'):
            with self.subTest(channel=channel), patch.object(self.irc, '_channel', channel):
                self.assertEqual(self.irc.send_message('hello'),
                                 '(SendObservation () (TransportSubmission NotSubmitted InvalidDestination 0 0))')
        self.sock.sendall.assert_not_called()

    def test_unconfigured_route_returns_explicit_unknown_destination(self):
        with patch.object(self.irc, '_server', None), patch.object(self.irc, '_sock', None):
            self.assertEqual(self.irc.send_message('hello'),
                             '(SendObservation () (TransportSubmission NotSubmitted InvalidDestination 0 0))')
        self.sock.sendall.assert_not_called()

    def test_failed_new_text_does_not_replace_confirmed_duplicate_marker(self):
        self.irc.send_message('first')
        previous = self.irc._last_submission
        self.sock.sendall.side_effect = OSError('unknown write')
        self.assertEqual(self.irc.send_message('second'),
                         self.observation('Uncertain', 'WriteUncertain', 0, 1))
        self.assertEqual(self.irc._last_submission, previous)
        self.assertEqual(self.sock.sendall.call_count, 2)

    def test_duplicate_marker_is_connection_and_destination_scoped(self):
        self.irc.send_message('hello')
        second = self.connect()
        self.assertEqual(self.irc.send_message('hello'), self.observation('Submitted', 'Complete', 1))
        second.sendall.assert_called_once()
        third = self.connect('#other')
        self.assertEqual(self.irc.send_message('hello'), self.observation('Submitted', 'Complete', 1,
                                                                          destination='irc:irc.example.org:6667:#other'))
        third.sendall.assert_called_once_with(b'PRIVMSG #other :hello\r\n')


if __name__ == '__main__':
    unittest.main()
