"""Host config rejects ambiguous authority and derives command requirements."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

APP = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("host_dispatch_config", APP / "host_dispatch_config.py")
config = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config)


class HostDispatchConfigTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="host-config-unit-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.file = self.root / 'input "quoted".txt'
        self.file.write_text("data", encoding="utf-8")
        self.value = json.loads((APP / "host_dispatch.example.json").read_text())
        self.value["allowed_files"] = [str(self.file)]
        self.value["commands"][0]["arguments"] = [str(self.file)]
        for name in ("global", "frame"):
            self.value[name]["permissions"] = ["files.read", "files.read:" + str(self.file), "frames.read"]

    def test_explicit_completion_criteria(self):
        self.assertIn('Disabled', config.completion_policy(self.value))
        local = dict(self.value, destination={'channel': 'local', 'recipient': 'stdout'})
        self.assertEqual(config.completion_policy(dict(local, completion_criterion='LocalAccepted')),
                         '(CompletionPolicy LocalAccepted "local:stdout")')
        for criterion in (None, True, [], 'Success', 'TransportSubmission'):
            with self.subTest(criterion=criterion), self.assertRaises(config.ConfigError):
                config.build_config(dict(local, completion_criterion=criterion))
        with self.assertRaises(config.ConfigError):
            config.build_config(dict(self.value, completion_criterion='LocalAccepted'))
        irc = dict(local, destination=dict(channel='irc', server='irc.example.org',
                                          port=6667, recipient='#room'))
        for criterion in ('TransportSubmission', 'RecipientAcknowledged'):
            self.assertIn(criterion, config.completion_policy(dict(irc, completion_criterion=criterion)))

    def test_destination_derives_exact_requirements(self):
        destination = {"channel": "local", "recipient": "stdout"}
        self.assertEqual(config.destination_metadata(destination),
                         ["HostDestination", ["channel", "local"],
                          ["recipient", "stdout"],
                          ["permissions", ["channels.send", "channels.send:local:stdout"]],
                          ["egress", ["local:stdout"]]])
        self.assertEqual(config.encode(config.destination_metadata(destination)),
                         '(HostDestination (channel "local") (recipient "stdout") '
                         '(permissions ("channels.send" "channels.send:local:stdout")) '
                         '(egress ("local:stdout")))')

    def test_destination_does_not_change_read_bindings_or_grant_policy(self):
        original = copy.deepcopy(self.value)
        with_destination = dict(self.value, destination={"channel": "local", "recipient": "stdout"})
        self.assertEqual(config.build_config(with_destination), config.build_config(original))
        self.assertEqual(self.value, original)
        with self.assertRaises(config.ConfigError):
            config.build_config(dict(self.value,
                                     commands=[{"skill": "send", "arguments": ["hello"]}]))

    def test_irc_destination_normalization_and_identity(self):
        destination = dict(channel="irc", recipient="Room", server="IRC.Example.org", port=6667)
        expected = ['HostDestination', ['channel', 'irc'], ['recipient', '#Room'],
                    ['server', 'irc.example.org'], ['port', 6667],
                    ['permissions', ['channels.send', 'channels.send:irc:irc.example.org:6667:#Room']],
                    ['egress', ['irc:irc.example.org:6667:#Room']]]
        self.assertEqual(config.destination_metadata(destination), expected)
        self.assertEqual(config.destination_metadata(dict(destination, recipient='#Room',
                                                          server='irc.example.org')), expected)
        self.assertEqual(destination['recipient'], 'Room')
        for change in ({'server': 'other.example.org'}, {'port': 6697},
                       {'recipient': '#room'}, {'recipient': '##Room'}):
            with self.subTest(change=change):
                self.assertNotEqual(config.destination_metadata(dict(destination, **change))[-1], expected[-1])
        self.assertEqual(dict(config.destination_metadata(dict(destination, server='127.0.0.1'))[1:])
                         ['server'], '127.0.0.1')

    def test_irc_bindings_preserve_arguments_candidates_and_cost_without_grants(self):
        destination = dict(channel='irc', recipient='#room', server='irc.example.org', port=6667)
        for candidate in ('respond', 'ask-clarification'):
            command = dict(skill='send', arguments=['Observed "text"\nnext line'], candidate=candidate)
            row = config.binding(command, 'frame-1', [], destination)
            self.assertEqual(row[1], ['send', command['arguments'][0]])
            self.assertEqual(row[2][-1], candidate)
            self.assertEqual(dict(row[3][1:]), {
                'candidate': candidate, 'target': 'frame-1', 'skill': 'send',
                'permissions': ['channels.send', 'channels.send:irc:irc.example.org:6667:#room'],
                'egress': ['irc:irc.example.org:6667:#room'],
                'costs': [['ResourceCost', 'commands', 'units', 1]]})
            value = dict(self.value, destination=destination, commands=[command])
            original = copy.deepcopy(value)
            encoded = config.build_config(value)
            self.assertIn(config.encode(row[1]), encoded)
            for scope_name in ('global', 'frame'):
                self.assertEqual(value[scope_name], original[scope_name])
            self.assertEqual(value, original)
        self.assertEqual(config.build_config(dict(self.value, destination=destination)),
                         config.build_config(self.value))

    def test_invalid_irc_destination_never_reaches_installer(self):
        valid = dict(channel='irc', recipient='#room', server='irc.example.org', port=6667)
        invalid = [{k: v for k, v in valid.items() if k != missing} for missing in valid]
        for field, values in {
            'server': ['irc://host', 'host:6667', '*.example.org', 'user@host',
                       'host.', '-host', 'host..org', 'h ost', 'h\nQUIT', 'h\x7f',
                       'éxample.org', 'a' * 64 + '.org', '999.1.1.1', '127.00.0.1',
                       '::1', None, True],
            'recipient': ['#', 'nick:target', '#a,#b', '#a b', '#a\r\nQUIT',
                          '#a\x00', '#a\x7f', '#a\t', '#*', '#é', '#a/b', '#a;b',
                          '#' + 'x' * 50, None, True],
            'port': [0, 65536, -1, True, None, '6667', 6667.0],
        }.items():
            invalid.extend(dict(valid, **{field: value}) for value in values)
        for field in ('permissions', 'egress', 'costs', 'token'):
            invalid.append(dict(valid, **{field: []}))
        path = self.root / 'irc-invalid.json'
        janus = Mock()
        for destination in invalid:
            path.write_text(json.dumps(dict(self.value, destination=destination)))
            with self.subTest(destination=destination), patch.dict('sys.modules', {'janus': janus}), \
                    self.assertRaises(config.ConfigError):
                config.provision(str(path))
        janus.query_once.assert_not_called()

    def test_irc_derived_identifier_bounds(self):
        destination = dict(channel='irc', recipient='#' + 'r' * 49, port=65535,
                           server='a' * 63 + '.' + 'b' * 63 + '.' + 'c' * 53)
        metadata = dict(config.destination_metadata(destination)[1:])
        self.assertEqual(len(metadata['permissions'][1]), 256)
        with self.assertRaises(config.ConfigError):
            config.destination_metadata(dict(destination, server=destination['server'] + 'c'))
        for port in (1, 65535):
            self.assertEqual(dict(config.destination_metadata(dict(destination, port=port))[1:])['port'], port)

    def test_invalid_irc_startup_preserves_previous_config(self):
        path = self.root / 'irc-startup.json'
        destination = dict(channel='irc', recipient='#room', server='irc.example.org', port=6667)
        path.write_text(json.dumps(dict(self.value, destination=destination)))
        config.configure_startup(str(path))
        retained = config._startup_config
        with patch.object(config, '_startup_installed', True):
            path.write_text(json.dumps(dict(self.value, destination=dict(destination, port=True))))
            with self.assertRaises(config.ConfigError):
                config.configure_startup(str(path))
            self.assertIs(config._startup_config, retained)
            self.assertTrue(config._startup_installed)

    def test_send_derives_respond_requirements_without_grants(self):
        destination = {"channel": "local", "recipient": "stdout"}
        command = {"skill": "send", "arguments": ['Observed "content"\nnext line']}
        row = config.binding(command, "frame-1", [], destination)
        self.assertEqual(row[1], ["send", command["arguments"][0]])
        self.assertEqual(row[2], ["AdmissionRequest", "propose-candidate", "current-frame", "respond"])
        operation = dict(row[3][1:])
        self.assertEqual(operation, {
            "candidate": "respond", "target": "frame-1", "skill": "send",
            "permissions": ["channels.send", "channels.send:local:stdout"],
            "egress": ["local:stdout"], "costs": [["ResourceCost", "commands", "units", 1]]})
        value = dict(self.value, destination=destination, commands=[command])
        before = copy.deepcopy(value)
        self.assertIn('(skill "send")', config.build_config(value))
        self.assertEqual(value, before)  # Neither policy scope is granted send.

    def test_send_argument_bounds_and_no_authority_overrides(self):
        destination = {"channel": "local", "recipient": "stdout"}
        for arguments in ([], ["one", "two"], [None], [True], [["shell", "pwd"]],
                          [""], [" \n\t"], ["x" * 1201], ["text\x00"], ["text\r"]):
            with self.subTest(arguments=arguments), self.assertRaises(config.ConfigError):
                config.binding({"skill": "send", "arguments": arguments}, "frame-1", [], destination)
        self.assertEqual(config.binding({"skill": "send", "arguments": ["x" * 1200]},
                                        "frame-1", [], destination)[1][1], "x" * 1200)
        for field in ("candidate", "recipient", "permissions", "egress", "costs"):
            command = {"skill": "send", "arguments": ["hello"], field: []}
            with self.subTest(field=field), self.assertRaises(config.ConfigError):
                config.binding(command, "frame-1", [], destination)

    def test_explicit_catalog_candidates_preserve_requirements(self):
        destination = {"channel": "local", "recipient": "stdout"}
        for command in self.value["commands"] + [{"skill": "send", "arguments": ["Which file?"]}]:
            default = config.binding(command, "frame-1", [str(self.file)], destination)
            candidate = str(default[2][-1])
            self.assertEqual(config.binding(dict(command, candidate=candidate), "frame-1",
                                            [str(self.file)], destination), default)
        clarification = dict(command, candidate="ask-clarification")
        row = config.binding(clarification, "frame-1", [], destination)
        self.assertEqual(row[2][-1], "ask-clarification")
        self.assertEqual(dict(row[3][1:])["candidate"], "ask-clarification")
        self.assertEqual(row[1], default[1])
        self.assertEqual(row[3][2:], default[3][2:])
        value = dict(self.value, destination=destination, commands=[clarification])
        before = copy.deepcopy(value)
        self.assertIn('(candidate ask-clarification)', config.build_config(value))
        self.assertEqual(value, before)

    def test_unknown_candidate_handler_mappings_cannot_reach_installer(self):
        path = self.root / "candidate.json"
        destination = {"channel": "local", "recipient": "stdout"}
        janus = Mock()
        for command in self.value["commands"] + [{"skill": "send", "arguments": ["Which file?"]}]:
            invalid = [None, True, 1, [], {}, "", "unknown", '(send "injected")']
            invalid += (["execute-skill", "search-knowledge"] if command["skill"] == "send"
                        else ["respond", "ask-clarification"])
            for candidate in invalid:
                value = dict(self.value, destination=destination,
                             commands=[dict(command, candidate=candidate)])
                path.write_text(json.dumps(value))
                with self.subTest(command=command, candidate=candidate), \
                        patch.dict('sys.modules', {'janus': janus}), \
                        self.assertRaises(config.ConfigError):
                    config.provision(str(path))
        janus.query_once.assert_not_called()

    def test_duplicate_command_across_candidates_is_rejected(self):
        command = {"skill": "send", "arguments": ["Which file?"]}
        value = dict(self.value, destination={"channel": "local", "recipient": "stdout"},
                     commands=[command, dict(command, candidate="ask-clarification")])
        with self.assertRaisesRegex(config.ConfigError, "duplicate command binding"):
            config.build_config(value)

    def test_destination_rejects_missing_unknown_and_injected_fields(self):
        invalid = [None, [], "local:stdout", {}, {"channel": "local"},
                   {"recipient": "stdout"},
                   {"channel": "irc", "recipient": "#room"},
                   {"channel": "local", "recipient": "other"}]
        for field in ("channel", "recipient"):
            for value in ("", " ", "*", "stdout\n", "x" * 257, True, 1, [], {},
                          '(send "injected")'):
                row = {"channel": "local", "recipient": "stdout"}
                row[field] = value
                invalid.append(row)
        for field in ("permissions", "egress", "costs", "server", "token"):
            invalid.append(dict(channel="local", recipient="stdout", **{field: []}))
        for destination in invalid:
            with self.subTest(destination=destination), self.assertRaises(config.ConfigError):
                config.build_config(dict(self.value, destination=destination))

    def test_invalid_destination_cannot_reach_policy_installer(self):
        path = self.root / "destination.json"
        janus = Mock()
        for destination in (None, {}, {"channel": "local", "recipient": "other"}):
            path.write_text(json.dumps(dict(self.value, destination=destination)))
            with patch.dict('sys.modules', {'janus': janus}):
                with self.subTest(destination=destination), self.assertRaises(config.ConfigError):
                    config.provision(str(path))
        janus.query_once.assert_not_called()

    def test_startup_retains_valid_destination_after_invalid_reconfiguration(self):
        path = self.root / "destination.json"
        value = dict(self.value, destination={"channel": "local", "recipient": "stdout"})
        path.write_text(json.dumps(value))
        config.configure_startup(str(path))
        retained = config._startup_config
        self.assertEqual(retained["destination"], value["destination"])
        with patch.object(config, '_startup_installed', True):
            path.write_text(json.dumps(dict(value, destination={})))
            with self.assertRaises(config.ConfigError):
                config.configure_startup(str(path))
            self.assertIs(config._startup_config, retained)
            self.assertTrue(config._startup_installed)

    def test_duplicate_destination_fields_rejected_from_json(self):
        path = self.root / "destination.json"
        path.write_text('{"destination":{"channel":"local","recipient":"stdout",'
                        '"recipient":"other"}}')
        with self.assertRaises(config.ConfigError):
            config.read_config(path)

    def test_startup_loads_once_and_validates_before_replacement(self):
        path = self.root / "startup.json"
        path.write_text(json.dumps(dict(self.value, frame_id="current-frame")))
        self.assertEqual(config.configure_startup(str(path)), 1)
        retained = config._startup_config
        path.write_text('{"invalid":true}')
        self.assertEqual(config._startup_config, retained)
        with self.assertRaises(config.ConfigError):
            config.configure_startup(str(path))
        self.assertIs(config._startup_config, retained)

    def test_startup_environment_is_explicit_and_optional(self):
        path = self.root / "startup.json"
        path.write_text(json.dumps(self.value))
        with patch.dict('os.environ', {'OMEGACLAW_HOST_CONFIG': str(path)}):
            self.assertEqual(config.configure_startup(), 1)
            self.assertEqual(config._startup_config['frame_id'], self.value['frame_id'])
        with patch.dict('os.environ', {}, clear=True):
            self.assertEqual(config.configure_startup(), 1)
            self.assertIsNone(config._startup_config)

    def test_derive_exact_file_permissions_and_command_cost(self):
        row = config.binding(self.value["commands"][0], "frame-1", [str(self.file)])
        self.assertEqual(row[1], ["read-file", str(self.file)])
        self.assertEqual(row[2], ["AdmissionRequest", "propose-candidate", "current-frame", "execute-skill"])
        operation = dict(row[3][1:])
        self.assertEqual(operation["target"], "frame-1")
        self.assertEqual(operation["permissions"], ["files.read", "files.read:" + str(self.file)])
        self.assertEqual(operation["egress"], [])
        self.assertEqual(operation["costs"], [["ResourceCost", "commands", "units", 1]])
        self.assertIn(json.dumps(str(self.file)), config.build_config(self.value))

    def test_frame_inspection_has_independent_requirements(self):
        row = config.binding(self.value["commands"][1], "frame-1", [])
        self.assertEqual(row[1], ["show-current-frame"])
        self.assertEqual(dict(row[3][1:])["permissions"], ["frames.read"])
        self.assertEqual(dict(row[3][1:])["candidate"], "search-knowledge")

    def test_no_implicit_fields_or_unknown_versions(self):
        for field in self.value:
            value = copy.deepcopy(self.value)
            del value[field]
            with self.subTest(field=field), self.assertRaises(config.ConfigError):
                config.build_config(value)
        for version in (True, 0, 2, "1"):
            value = dict(self.value, version=version)
            with self.subTest(version=version), self.assertRaises(config.ConfigError):
                config.build_config(value)

    def test_command_cannot_supply_its_own_requirements(self):
        for key in ("candidate", "target", "permissions", "egress", "costs"):
            value = copy.deepcopy(self.value)
            value["commands"][0][key] = []
            with self.subTest(key=key), self.assertRaises(config.ConfigError):
                config.build_config(value)

    def test_unknown_skill_wrong_arity_and_nested_arguments(self):
        for command in (
            {"skill": "shell", "arguments": ["pwd"]},
            {"skill": "read-file", "arguments": []},
            {"skill": "read-file", "arguments": [str(self.file), "extra"]},
            {"skill": "read-file", "arguments": [["shell", "pwd"]]},
            {"skill": "show-current-frame", "arguments": ["other-frame"]},
        ):
            with self.subTest(command=command), self.assertRaises(config.ConfigError):
                config.build_config(dict(self.value, commands=[command]))

    def test_paths_require_explicit_canonical_regular_file(self):
        alias = self.root / "alias.txt"
        alias.symlink_to(self.file)
        for path in ("relative.txt", str(alias), str(self.root), str(self.root / ".." / self.root.name / self.file.name)):
            value = copy.deepcopy(self.value)
            value["allowed_files"] = [path]
            value["commands"][0]["arguments"] = [path]
            with self.subTest(path=path), self.assertRaises(config.ConfigError):
                config.build_config(value)
        other = self.root / "other.txt"
        other.write_text("other", encoding="utf-8")
        value = copy.deepcopy(self.value)
        value["commands"][0]["arguments"] = [str(other)]
        with self.assertRaises(config.ConfigError):
            config.build_config(value)

    def test_constraints_and_budget_validation(self):
        for amount in (-1, True, 1.5, float("inf"), float("nan"), "10", 9007199254740992):
            value = copy.deepcopy(self.value)
            value["frame"]["budgets"][0]["available"] = amount
            with self.subTest(amount=amount), self.assertRaises(config.ConfigError):
                config.build_config(value)
        for constraint in (["Unknown", "x"], ["MaxCost", "commands", "units", -1], ["DenySkill"]):
            value = copy.deepcopy(self.value)
            value["global"]["constraints"] = [constraint]
            with self.subTest(constraint=constraint), self.assertRaises(config.ConfigError):
                config.build_config(value)

    def test_duplicates_rejected(self):
        for field in ("commands", "allowed_files"):
            value = copy.deepcopy(self.value)
            value[field].append(value[field][0])
            with self.subTest(field=field), self.assertRaises(config.ConfigError):
                config.build_config(value)
        for field in ("skills", "permissions", "budgets"):
            value = copy.deepcopy(self.value)
            value["frame"][field].append(value["frame"][field][0])
            with self.subTest(field=field), self.assertRaises(config.ConfigError):
                config.build_config(value)

    def test_explicit_empty_grants_and_empty_bindings_stay_empty(self):
        value = copy.deepcopy(self.value)
        value["commands"] = []
        value["global"]["permissions"] = []
        value["frame"]["skills"] = []
        result = config.build_config(value)
        self.assertIn("(permissions ())", result)
        self.assertIn("(skills ())", result)
        self.assertTrue(result.endswith(" ())"))

    def test_collection_and_json_bounds(self):
        value = copy.deepcopy(self.value)
        value["commands"] = [value["commands"][0]] * 129
        with self.assertRaises(config.ConfigError):
            config.build_config(value)
        path = self.root / "config.json"
        path.write_text('{"version": 1, "version": 2}', encoding="utf-8")
        with self.assertRaises(config.ConfigError):
            config.read_config(path)
        path.write_text(" " * 65537, encoding="utf-8")
        with self.assertRaises(config.ConfigError):
            config.read_config(path)
        with self.assertRaises(config.ConfigError):
            config.read_config("relative.json")


if __name__ == "__main__":
    unittest.main()
