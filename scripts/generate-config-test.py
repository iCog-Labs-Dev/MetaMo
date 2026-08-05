#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("generate-config.py")


def load_generator_module():
    spec = importlib.util.spec_from_file_location("generate_config", SCRIPT_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"could not load {SCRIPT_PATH}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


generator = load_generator_module()


class GenerateConfigTest(unittest.TestCase):
    def test_example_registry_generates_core_and_openpsi_config(self):
        raw = generator.parse_yaml_subset(generator.EXAMPLE_REGISTRY)
        config = generator.validate_registry(raw)
        outputs = generator.build_outputs(
            config=config,
            target="all",
            source=Path("registry/metamo.yaml"),
            core_output=Path("core/config.metta"),
            openpsi_output=Path("openpsi/config.metta"),
        )

        core = outputs[Path("core/config.metta")]
        openpsi = outputs[Path("openpsi/config.metta")]

        self.assertIn("(= (C_CONTRACT) 0.9)", core)
        self.assertIn("(MetaMoAppraisalModule openPsiAppraisal)", core)
        self.assertIn("(= (NUM_GOALS) 8)", openpsi)
        self.assertIn("(GoalIndex gSoc 7)", openpsi)
        self.assertIn("(= (OPENPSI_SAFETY_GOAL_IDX) (0 2 6))", openpsi)
        self.assertIn("(= (parallelMerge $stateA $stateB $coherenceCorrection)", openpsi)

    def test_group_indices_are_range_checked(self):
        raw = generator.parse_yaml_subset(
            """\
openpsi:
  indices:
    GoalIndex: [gInd]
  groups:
    OPENPSI_SAFETY_GOAL_IDX: [2]
"""
        )

        with self.assertRaisesRegex(generator.ConfigError, "outside GoalIndex range"):
            generator.validate_registry(raw)

    def test_unknown_keys_are_rejected(self):
        raw = generator.parse_yaml_subset(
            """\
core:
  constants:
    EPSILON: 0.05
  unexpected: value
"""
        )

        with self.assertRaisesRegex(generator.ConfigError, "unknown key"):
            generator.validate_registry(raw)


if __name__ == "__main__":
    unittest.main()
