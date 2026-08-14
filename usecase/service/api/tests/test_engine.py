import json
import unittest

from usecase.service.api.engine import EngineError, _extract_marked_json


class ExtractMarkedJsonTests(unittest.TestCase):
    def test_extracts_multiline_json_and_answer(self):
        expected = {
            "selected_action": "act_respond",
            "answer": "first line\nsecond line with {braces}",
        }
        output = (
            "engine diagnostics\n"
            "@@QWESTOR_RESULT@@"
            f"{json.dumps(expected, indent=2)}\n"
            "trailing diagnostics"
        )

        self.assertEqual(
            _extract_marked_json(output, "@@QWESTOR_RESULT@@"),
            expected,
        )

    def test_uses_final_marker(self):
        output = (
            '@@QWESTOR_RESULT@@{"answer": "old"}\n'
            '@@QWESTOR_RESULT@@{"answer": "new"}'
        )

        self.assertEqual(
            _extract_marked_json(output, "@@QWESTOR_RESULT@@"),
            {"answer": "new"},
        )

    def test_rejects_missing_marker(self):
        with self.assertRaises(EngineError):
            _extract_marked_json("engine output without a result", "@@QWESTOR_RESULT@@")


if __name__ == "__main__":
    unittest.main()
