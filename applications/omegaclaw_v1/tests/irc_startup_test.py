"""IRC startup profile validation without sockets, providers or policy mutation."""
import copy
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from contextlib import redirect_stdout
from unittest.mock import Mock, patch

APP = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('host_dispatch_config', APP / 'host_dispatch_config.py')
host = importlib.util.module_from_spec(spec)
spec.loader.exec_module(host)


class IrcStartupTests(unittest.TestCase):
    def setUp(self):
        self.config = json.loads((APP / 'host_dispatch.irc.example.json').read_text())
        self.route = dict(server='IRC.Example.org', port=6667, recipient='#room', connected=False)
        host._startup_config = None
        host._startup_installed = False
        host._startup_checked = False

    def check(self):
        return host.startup_channel_diagnostics(self.config, 'irc', self.route)

    def test_example_builds_both_candidates_without_side_effects(self):
        original = copy.deepcopy(self.config)
        encoded = host.build_config(self.config)
        self.assertIn('(candidate respond)', encoded)
        self.assertIn('(candidate ask-clarification)', encoded)
        self.assertEqual(self.check(), [])
        self.assertEqual(self.config, original)

    def test_normalized_route_can_be_disconnected_at_startup(self):
        self.config['destination'].update(server='IRC.Example.org', recipient='room')
        self.assertEqual(self.check(), [])

    def test_mismatched_endpoint_channel_or_port_fails_without_echoing_values(self):
        for change in (dict(server='secret.example.org'), dict(port=6697), dict(recipient='#secret')):
            with self.subTest(change=change):
                route = dict(self.route, **change)
                with self.assertRaisesRegex(host.ConfigError, 'StartupIrcDestinationMismatch') as caught:
                    host.startup_channel_diagnostics(self.config, 'irc', route)
                self.assertNotIn('secret', str(caught.exception))

    def test_channel_mismatch(self):
        for channel in ('local', 'telegram', None):
            with self.subTest(channel=channel), self.assertRaisesRegex(host.ConfigError, 'StartupChannelMismatch'):
                host.startup_channel_diagnostics(self.config, channel)

    def test_missing_or_invalid_transport_has_fixed_diagnostic(self):
        for route in (None, {}, dict(self.route, server='credential@host'), dict(self.route, port=True)):
            with self.subTest(route=route), self.assertRaisesRegex(host.ConfigError, 'StartupIrcRouteUnavailable') as caught:
                host.startup_channel_diagnostics(self.config, 'irc', route)
            self.assertNotIn('credential@host', str(caught.exception))

    def test_missing_config_and_read_only_are_diagnostic_not_denial(self):
        self.assertIn('MissingReplyPolicy', host.startup_channel_diagnostics(None, 'irc')[0])
        self.assertEqual(host.startup_channel_diagnostics(None, 'local'), [])
        self.config.pop('destination')
        self.config['commands'] = []
        original = copy.deepcopy(self.config)
        self.assertIn('MissingReplyDestination', self.check()[0])
        self.assertEqual(self.config, original)

    def test_missing_each_grant_in_either_scope_is_identified_without_granting(self):
        for scope in ('global', 'frame'):
            for field, grant in (('skills', 'send'), ('permissions', 'channels.send'),
                                  ('permissions', 'channels.send:irc:irc.example.org:6667:#room'),
                                  ('egress', 'irc:irc.example.org:6667:#room')):
                config = copy.deepcopy(self.config)
                config[scope][field].remove(grant)
                original = copy.deepcopy(config)
                diagnostic = host.startup_channel_diagnostics(config, 'irc', self.route)
                self.assertEqual(len(diagnostic), 1)
                self.assertIn(scope + ' scope', diagnostic[0])
                self.assertEqual(config, original)

    def test_clarification_alone_does_not_count_as_reply_binding(self):
        self.config['commands'] = self.config['commands'][1:]
        self.assertIn('MissingReplyBinding', self.check()[0])
        self.config['commands'] = []  # Trusted preparation can bind later.
        self.assertIn('trusted prepared reply', self.check()[0])

    def test_denials_and_budgets_remain_the_final_gates_authority(self):
        self.config['global']['constraints'].append(['DenySkill', 'send'])
        self.config['frame']['budgets'][0]['status'] = 'Closed'
        original = copy.deepcopy(self.config)
        host.build_config(self.config)
        self.check()
        self.assertEqual(self.config, original)

    def test_missing_config_diagnosed_once_at_first_frame_without_installing(self):
        janus = Mock()
        janus.query_once.side_effect = [dict(truth=True, Frame=[], Channel='irc', Symbolic=0),
                                       dict(truth=True, Frame='frame', Channel='irc', Symbolic=0)]
        with patch.dict('sys.modules', {'janus': janus}), redirect_stdout(io.StringIO()) as output:
            host.provision_startup()
            self.assertEqual(output.getvalue(), '')
            host.provision_startup()
            host.provision_startup()
        self.assertEqual(output.getvalue().count('MissingReplyPolicy'), 1)
        self.assertEqual(janus.query_once.call_count, 2)
        self.assertFalse(host._startup_installed)

    def test_channel_mismatch_prevents_installer_and_can_be_corrected(self):
        host._startup_config = self.config
        janus = Mock()
        janus.query_once.return_value = dict(truth=True, Frame='frame', Channel='local', Symbolic=0)
        with patch.dict('sys.modules', {'janus': janus}), self.assertRaisesRegex(host.ConfigError, 'StartupChannelMismatch'):
            host.provision_startup()
        self.assertEqual(janus.query_once.call_count, 1)
        self.assertFalse(host._startup_installed)
        self.assertFalse(host._startup_checked)

    def test_configuration_reset_and_invalid_replacement(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'host.json'
            path.write_text(json.dumps(self.config))
            host._startup_checked = True
            host.configure_startup(str(path))
            self.assertFalse(host._startup_checked)
            saved = host._startup_config
            host._startup_checked = True
            self.config['destination']['port'] = 'credential'
            path.write_text(json.dumps(self.config))
            with self.assertRaises(host.ConfigError):
                host.configure_startup(str(path))
            self.assertIs(host._startup_config, saved)
            self.assertTrue(host._startup_checked)


if __name__ == '__main__':
    unittest.main()
