"""Host config rejects ambiguous authority and derives command requirements."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

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
