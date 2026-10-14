"""Real IRC routing lifecycle and locks, with sockets/threads at ingress doubled."""
import importlib.util
import os
from pathlib import Path
import sys
import threading
import unittest
from unittest.mock import Mock, patch

APP = Path(__file__).resolve().parents[1]
CORE = Path(os.environ.get('OMEGACLAW_CORE_TEST_ROOT', APP.parents[2] / 'repos/OmegaClaw-Core'))
sys.path.insert(0, str(APP))
import host_operations


class IrcRoutingTests(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location('irc', CORE / 'channels/irc.py')
        self.irc = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.irc)
        modules = patch.dict(sys.modules, {'irc': self.irc})
        modules.start()
        self.addCleanup(modules.stop)
        sleeper = patch.object(self.irc.time, 'sleep')
        sleeper.start()
        self.addCleanup(sleeper.stop)

    def connect(self, server='IRC.Example.org', port=6667, channel='room'):
        with patch.object(self.irc.threading, 'Thread'):
            self.irc.start_irc(channel, server, port, auth_secret='')
        sock = Mock()
        self.assertTrue(self.irc._install_connection(sock, server, port, self.irc._channel, self.irc._run_id))
        self.assertTrue(self.irc._mark_registered(sock, self.irc._run_id))
        return sock

    def test_authoritative_normalized_route_and_reconnect_identity(self):
        first = self.connect()
        before = self.irc.route_snapshot()
        self.assertEqual(host_operations.irc_route_snapshot(),
                         f'(IrcRoute "irc:irc.example.org:6667:#room" {before["generation"]} Ready)')
        old_run = self.irc._run_id
        second = self.connect()
        after = self.irc.route_snapshot()
        self.assertGreater(after['generation'], before['generation'])
        self.assertFalse(self.irc._mark_registered(first, old_run))
        self.assertFalse(self.irc._install_connection(first, 'old', 6667, '#old', old_run))
        self.irc._disconnect_connection(first)
        self.assertEqual(self.irc.route_snapshot(), after)
        self.irc.send_message('hello')
        first.sendall.assert_not_called()
        second.sendall.assert_called_once_with(b'PRIVMSG #room :hello\r\n')

    def test_start_stop_and_disconnect_publish_unavailability(self):
        sock = self.connect()
        self.irc.stop_irc()
        self.assertIn('Unavailable)', host_operations.irc_route_snapshot())
        self.irc.send_message('no route')
        sock.sendall.assert_not_called()
        self.assertFalse(self.irc._mark_registered(sock, self.irc._run_id))
        sock = self.connect()
        self.irc._disconnect_connection(sock)
        self.assertFalse(self.irc.route_snapshot()['connected'])
        with patch.object(self.irc.threading, 'Thread'):
            self.irc.start_irc('room')
        self.assertFalse(self.irc.route_snapshot()['connected'])

    def test_transport_guard_serializes_stop_until_send_finishes(self):
        sock = self.connect()
        attempting, stopped = threading.Event(), threading.Event()

        def stop():
            attempting.set()
            self.irc.stop_irc()
            stopped.set()

        host_operations.acquire_irc_route()
        worker = threading.Thread(target=stop)
        try:
            worker.start()
            self.assertTrue(attempting.wait(1))
            self.assertFalse(stopped.wait(0.05))
            self.irc.send_message('checked destination')
            sock.sendall.assert_called_once_with(b'PRIVMSG #room :checked destination\r\n')
            self.assertFalse(stopped.is_set())
        finally:
            host_operations.release_irc_route()
            worker.join(2)
        self.assertFalse(worker.is_alive())
        self.assertTrue(stopped.is_set())

    def test_protocol_messages_from_old_socket_cannot_use_new_connection(self):
        first = self.connect()
        second = self.connect(server='other.example.org', port=6697, channel='other')
        self.irc._send('PRIVMSG #room :stale', first)
        second.sendall.assert_not_called()
        self.assertIn('irc:other.example.org:6697:#other', host_operations.irc_route_snapshot())

    def test_receiver_registration_ingress_and_disconnect_use_owned_socket(self):
        self.irc._running = True
        self.irc._run_id = 7
        sock = Mock()
        sock.recv.side_effect = [b':server 001 bot :ok\r\nPING :test\r\n'
                                 b':user!u PRIVMSG #room :hello\r\n', b'']
        with patch.object(self.irc.socket, 'create_connection', return_value=sock):
            self.irc._irc_loop('#room', 'irc.example.org', 6667, 'bot', 7)
        self.assertEqual([call.args[0] for call in sock.sendall.call_args_list],
                         [b'NICK bot\r\n', b'USER bot 0 * :bot\r\n',
                          b'JOIN #room\r\n', b'PONG :test\r\n'])
        self.assertEqual(self.irc.getLastMessage(), 'user: hello')
        self.assertFalse(self.irc.route_snapshot()['connected'])
        sock.close.assert_called_once()

    def test_receiver_exception_clears_published_connection(self):
        self.irc._running = True
        sock = Mock()
        sock.sendall.side_effect = OSError('broken socket')
        with patch.object(self.irc.socket, 'create_connection', return_value=sock):
            with self.assertRaises(OSError):
                self.irc._irc_loop('#room', 'irc.example.org', 6667, 'bot', self.irc._run_id)
        self.assertIsNone(self.irc._sock)
        self.assertFalse(self.irc.route_snapshot()['connected'])
        sock.close.assert_called_once()

    def test_missing_old_or_malformed_transport_is_not_ready(self):
        with patch.dict(sys.modules, {'irc': None}):
            self.assertEqual(host_operations.irc_route_snapshot(), '(IrcRouteUnavailable)')
            with self.assertRaises(RuntimeError):
                host_operations.acquire_irc_route()
        with patch.dict(sys.modules, {'irc': object()}):
            self.assertEqual(host_operations.irc_route_snapshot(), '(IrcRouteUnavailable)')
        self.connect()
        valid = self.irc.route_snapshot()
        for change in ({'server': 'host\r\nQUIT'}, {'recipient': '#one,#two'},
                       {'port': True}, {'generation': True}, {'connected': 'yes'}):
            with self.subTest(change=change), patch.object(self.irc, 'route_snapshot',
                                                          return_value=dict(valid, **change)):
                self.assertEqual(host_operations.irc_route_snapshot(), '(IrcRouteUnavailable)')


if __name__ == '__main__':
    unittest.main()
