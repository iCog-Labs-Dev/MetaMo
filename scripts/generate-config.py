#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import re
import sys
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Any


KNOWN_TOP_LEVEL_KEYS = {"schema_version", "core", "openpsi"}
CORE_KEYS = {"constants", "modules"}
OPENPSI_KEYS = {"indices", "constants", "groups"}
INDEX_DIMENSION_CONSTANTS = {
    "GoalIndex": "NUM_GOALS",
    "ModulatorIndex": "NUM_MODULATORS",
    "StimulusIndex": "NUM_STIMULUS",
}

SYMBOL_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_+\-*/<>=!?._:]*$")
INT_RE = re.compile(r"^[+-]?[0-9]+$")
FLOAT_RE = re.compile(
    r"^[+-]?(?:[0-9]+\.[0-9]*|[0-9]*\.[0-9]+|[0-9]+[eE][+-]?[0-9]+|"
    r"[0-9]*\.[0-9]+[eE][+-]?[0-9]+)$"
)


class ConfigError(ValueError):
    """Raised when the registry YAML cannot be rendered safely."""


@dataclass(frozen=True)
class CoreConfig:
    constants: Mapping[str, Any]
    modules: Mapping[str, str]


@dataclass(frozen=True)
class OpenPsiConfig:
    indices: Mapping[str, list[str]]
    constants: Mapping[str, Any]
    groups: Mapping[str, Any]


@dataclass(frozen=True)
class RegistryConfig:
    core: CoreConfig | None
    openpsi: OpenPsiConfig | None


@dataclass(frozen=True)
class YamlToken:
    lineno: int
    indent: int
    content: str


EXAMPLE_REGISTRY = """\
schema_version: 1

core:
  constants:
    C_CONTRACT: 0.9
    EPSILON: 0.05
    ETA_BOUNDARY: 0.1
    ALPHA_0: 0.1
    BETA_0: 0.15
    LAX_DISTRIBUTIVE_DELTA: 1e-3

  modules:
    MetaMoAppraisalModule: openPsiAppraisal
    MetaMoDecisionModule: magusDecision
    MetaMoDampingFn: defaultDamping
    MetaMoBoundaryFn: defaultBoundaryStabilize
    MetaMoProjectFn: defaultProject
    MetaMoContractiveFn: defaultContractiveCheck
    MetaMoSafeRegionFn: defaultSafeRegionCheck

openpsi:
  indices:
    GoalIndex:
      - gInd
      - gTrans
      - gHelp
      - gCurio
      - gNovel
      - gSelf
      - gEthic
      - gSoc

    ModulatorIndex:
      - valence
      - arousal
      - approach
      - resolution
      - threshold
      - securing

    StimulusIndex:
      - novelty
      - conduciveness
      - risk
      - effort

  constants:
    LAMBDA_IND: 0.5
    LAMBDA_TRANS: 0.5
    THETA_SAFE: 0.3
    G_MAX: 2.0

  groups:
    OPENPSI_GOAL_WEIGHT_IDX: 0
    OPENPSI_SAFETY_GOAL_IDX: [0, 2, 6]
    OPENPSI_EXPLORATORY_GOAL_IDX: [1, 3, 4, 5]
    OPENPSI_SOCIAL_GOAL_IDX: [7]
    OPENPSI_CAUTION_MOD_IDX: [4, 5]
    OPENPSI_EXPLORATORY_MOD_IDX: [1, 2]
    OPENPSI_SHARED_MOD_IDX: [0, 3]
"""


OPENPSI_TAIL = """\
;; OpenPSI convenience wrappers

;; Backward-compatible 4-arity stimulus constructor.
;; Example: (openPsiStimulus 0.2 0.8 0.1 0.2)
(= (openPsiStimulus $novelty $conduciveness $risk $effort)
    (stimulus ($novelty $conduciveness $risk $effort))
)

;; Validate motivation state shape against OpenPSI dimensions.
;; Example: (validateMotivationalStateShape myState)
(= (validateMotivationalStateShape $motivationState)
    (validateMotivationState $motivationState (NUM_GOALS) (NUM_MODULATORS))
)

;; Validate action state shape against OpenPSI goal count.
;; Example: (validateActionShape $actionState)
(= (validateActionShape $actionState)
    (validateActionState $actionState (NUM_GOALS))
)

;; OpenPSI parallel merge passes project-specific index categories.
;; Example: (parallelMerge stateA stateB 0.05)
(= (parallelMerge $stateA $stateB $coherenceCorrection)
    (motivation
        (eval (clipVector
            (parallelMergeGoals
                (motivationGoals $stateA) (motivationGoals $stateB) $coherenceCorrection
                (eval (OPENPSI_GOAL_WEIGHT_IDX))
                (eval (OPENPSI_SAFETY_GOAL_IDX))
                (eval (OPENPSI_EXPLORATORY_GOAL_IDX))
                (eval (OPENPSI_SOCIAL_GOAL_IDX))
            )
            0.0
            1.0
        ))
        (eval (clipVector
            (parallelMergeModulators
                (motivationModulators $stateA)
                (motivationModulators $stateB)
                (motivationGoals $stateA)
                (motivationGoals $stateB)
                $coherenceCorrection
                (eval (OPENPSI_GOAL_WEIGHT_IDX))
                (eval (OPENPSI_CAUTION_MOD_IDX))
                (eval (OPENPSI_EXPLORATORY_MOD_IDX))
                (eval (OPENPSI_SHARED_MOD_IDX))
            )
            0.0
            1.0
        ))
    )
)
"""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate MetaMo MeTTa config files from a YAML registry."
    )
    parser.add_argument(
        "registry",
        nargs="?",
        help="YAML registry path. Omit only when using --emit-example.",
    )
    parser.add_argument(
        "--target",
        choices=("all", "core", "openpsi"),
        default="all",
        help="Config target to generate.",
    )
    parser.add_argument(
        "--write",
        action="store_true",
        help="Write generated files to --output-root.",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Exit non-zero if generated files differ from files on disk.",
    )
    parser.add_argument(
        "--stdout",
        action="store_true",
        help="Print generated files to stdout. This is the default when neither --write nor --check is used.",
    )
    parser.add_argument(
        "--output-root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="Repository root for default output paths.",
    )
    parser.add_argument(
        "--core-output",
        default="core/config.metta",
        help="Core config output path relative to --output-root.",
    )
    parser.add_argument(
        "--openpsi-output",
        default="openpsi/config.metta",
        help="OpenPSI config output path relative to --output-root.",
    )
    parser.add_argument(
        "--emit-example",
        action="store_true",
        help="Print an example registry YAML and exit.",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Suppress write/check status messages.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if args.emit_example:
        print(EXAMPLE_REGISTRY, end="")
        return 0

    if not args.registry:
        print("generate-config.py: error: registry path is required", file=sys.stderr)
        return 2

    if args.write and args.check:
        print("generate-config.py: error: --write and --check are mutually exclusive", file=sys.stderr)
        return 2

    try:
        registry_path = Path(args.registry)
        raw_config = load_yaml_registry(registry_path)
        config = validate_registry(raw_config)
        outputs = build_outputs(
            config=config,
            target=args.target,
            source=registry_path,
            core_output=Path(args.core_output),
            openpsi_output=Path(args.openpsi_output),
        )
    except (ConfigError, OSError) as exc:
        print(f"generate-config.py: error: {exc}", file=sys.stderr)
        return 1

    if not args.write and not args.check:
        args.stdout = True

    status = 0
    if args.check:
        status = check_outputs(args.output_root, outputs, quiet=args.quiet)

    if args.write:
        write_outputs(args.output_root, outputs, quiet=args.quiet)

    if args.stdout:
        print_outputs(outputs)

    return status


def load_yaml_registry(path: Path) -> Any:
    text = path.read_text(encoding="utf-8")
    try:
        import yaml  # type: ignore[import-not-found]
    except ModuleNotFoundError:
        return parse_yaml_subset(text)

    loaded = yaml.safe_load(text)
    return {} if loaded is None else loaded


def parse_yaml_subset(text: str) -> Any:
    tokens = tokenize_yaml_subset(text)
    if not tokens:
        return {}

    value, index = parse_yaml_block(tokens, 0, tokens[0].indent)
    if index != len(tokens):
        token = tokens[index]
        raise ConfigError(f"line {token.lineno}: unexpected YAML content")
    return value


def tokenize_yaml_subset(text: str) -> list[YamlToken]:
    tokens: list[YamlToken] = []
    for lineno, raw_line in enumerate(text.splitlines(), start=1):
        line = strip_yaml_comment(raw_line.expandtabs(2)).rstrip()
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip(" "))
        tokens.append(YamlToken(lineno=lineno, indent=indent, content=line.strip()))
    return tokens


def strip_yaml_comment(line: str) -> str:
    quote: str | None = None
    escaped = False
    for index, char in enumerate(line):
        if quote:
            if quote == '"' and char == "\\" and not escaped:
                escaped = True
                continue
            if char == quote and not escaped:
                quote = None
            escaped = False
            continue

        if char in {"'", '"'}:
            quote = char
        elif char == "#" and (index == 0 or line[index - 1].isspace()):
            return line[:index]
    return line


def parse_yaml_block(
    tokens: list[YamlToken],
    index: int,
    indent: int,
) -> tuple[Any, int]:
    if index >= len(tokens):
        return {}, index

    token = tokens[index]
    if token.indent != indent:
        raise ConfigError(
            f"line {token.lineno}: expected indentation {indent}, got {token.indent}"
        )

    if token.content.startswith("- "):
        return parse_yaml_sequence(tokens, index, indent)
    return parse_yaml_mapping(tokens, index, indent)


def parse_yaml_mapping(
    tokens: list[YamlToken],
    index: int,
    indent: int,
) -> tuple[dict[str, Any], int]:
    result: dict[str, Any] = {}

    while index < len(tokens):
        token = tokens[index]
        if token.indent < indent:
            break
        if token.indent > indent:
            raise ConfigError(f"line {token.lineno}: unexpected indentation")
        if token.content.startswith("- "):
            break

        key, raw_value = split_yaml_key_value(token.content, token.lineno)
        if key in result:
            raise ConfigError(f"line {token.lineno}: duplicate YAML key {key!r}")

        if raw_value == "":
            index += 1
            if index >= len(tokens) or tokens[index].indent <= indent:
                result[key] = {}
            else:
                result[key], index = parse_yaml_block(tokens, index, tokens[index].indent)
        else:
            result[key] = parse_yaml_scalar(raw_value, token.lineno)
            index += 1

    return result, index


def parse_yaml_sequence(
    tokens: list[YamlToken],
    index: int,
    indent: int,
) -> tuple[list[Any], int]:
    result: list[Any] = []

    while index < len(tokens):
        token = tokens[index]
        if token.indent < indent:
            break
        if token.indent > indent:
            raise ConfigError(f"line {token.lineno}: unexpected indentation")
        if not token.content.startswith("- "):
            break

        item_text = token.content[2:].strip()
        if item_text == "":
            index += 1
            if index >= len(tokens) or tokens[index].indent <= indent:
                result.append(None)
            else:
                item, index = parse_yaml_block(tokens, index, tokens[index].indent)
                result.append(item)
            continue

        key_value = try_split_yaml_key_value(item_text, token.lineno)
        if key_value is None:
            result.append(parse_yaml_scalar(item_text, token.lineno))
            index += 1
            continue

        key, raw_value = key_value
        item: dict[str, Any] = {}
        if raw_value == "":
            index += 1
            if index >= len(tokens) or tokens[index].indent <= indent:
                item[key] = {}
            else:
                item[key], index = parse_yaml_block(tokens, index, tokens[index].indent)
        else:
            item[key] = parse_yaml_scalar(raw_value, token.lineno)
            index += 1

        while index < len(tokens) and tokens[index].indent > indent:
            extra, index = parse_yaml_mapping(tokens, index, tokens[index].indent)
            item.update(extra)

        result.append(item)

    return result, index


def split_yaml_key_value(text: str, lineno: int) -> tuple[str, str]:
    key_value = try_split_yaml_key_value(text, lineno)
    if key_value is None:
        raise ConfigError(f"line {lineno}: expected YAML key/value pair")
    return key_value


def try_split_yaml_key_value(text: str, lineno: int) -> tuple[str, str] | None:
    quote: str | None = None
    escaped = False
    for index, char in enumerate(text):
        if quote:
            if quote == '"' and char == "\\" and not escaped:
                escaped = True
                continue
            if char == quote and not escaped:
                quote = None
            escaped = False
            continue

        if char in {"'", '"'}:
            quote = char
        elif char == ":":
            key = text[:index].strip()
            value = text[index + 1 :].strip()
            if not key:
                raise ConfigError(f"line {lineno}: empty YAML key")
            return parse_yaml_key(key, lineno), value

    return None


def parse_yaml_key(value: str, lineno: int) -> str:
    parsed = parse_yaml_scalar(value, lineno)
    if not isinstance(parsed, str):
        raise ConfigError(f"line {lineno}: YAML keys must be strings")
    return parsed


def parse_yaml_scalar(value: str, lineno: int) -> Any:
    if value == "":
        return ""

    if value.startswith("["):
        if not value.endswith("]"):
            raise ConfigError(f"line {lineno}: unterminated inline list")
        return [parse_yaml_scalar(part, lineno) for part in split_inline_items(value[1:-1], lineno)]

    if value.startswith("{"):
        if not value.endswith("}"):
            raise ConfigError(f"line {lineno}: unterminated inline mapping")
        result: dict[str, Any] = {}
        for part in split_inline_items(value[1:-1], lineno):
            key, raw_value = split_yaml_key_value(part, lineno)
            result[key] = parse_yaml_scalar(raw_value, lineno)
        return result

    if (value.startswith('"') and value.endswith('"')) or (
        value.startswith("'") and value.endswith("'")
    ):
        return parse_quoted_yaml_scalar(value, lineno)

    lower_value = value.lower()
    if lower_value in {"true", "false"}:
        return lower_value == "true"
    if lower_value in {"null", "~"}:
        return None
    if INT_RE.match(value):
        return int(value)
    if FLOAT_RE.match(value):
        return float(value)
    return value


def split_inline_items(value: str, lineno: int) -> list[str]:
    if not value.strip():
        return []

    parts: list[str] = []
    start = 0
    depth = 0
    quote: str | None = None
    escaped = False

    for index, char in enumerate(value):
        if quote:
            if quote == '"' and char == "\\" and not escaped:
                escaped = True
                continue
            if char == quote and not escaped:
                quote = None
            escaped = False
            continue

        if char in {"'", '"'}:
            quote = char
        elif char in "[{":
            depth += 1
        elif char in "]}":
            depth -= 1
            if depth < 0:
                raise ConfigError(f"line {lineno}: unbalanced inline collection")
        elif char == "," and depth == 0:
            parts.append(value[start:index].strip())
            start = index + 1

    if quote:
        raise ConfigError(f"line {lineno}: unterminated quoted scalar")
    if depth != 0:
        raise ConfigError(f"line {lineno}: unbalanced inline collection")

    parts.append(value[start:].strip())
    return parts


def parse_quoted_yaml_scalar(value: str, lineno: int) -> str:
    quote = value[0]
    if quote == "'":
        return value[1:-1].replace("''", "'")

    try:
        return json.loads(value)
    except json.JSONDecodeError as exc:
        raise ConfigError(f"line {lineno}: invalid quoted string: {exc}") from exc


def validate_registry(value: Any) -> RegistryConfig:
    root = require_mapping(value, "registry")
    unknown = set(root) - KNOWN_TOP_LEVEL_KEYS
    if unknown:
        raise ConfigError(f"registry: unknown top-level key(s): {format_keys(unknown)}")

    core = validate_core(root["core"]) if "core" in root else None
    openpsi = validate_openpsi(root["openpsi"]) if "openpsi" in root else None

    if core is None and openpsi is None:
        raise ConfigError("registry: expected at least one of 'core' or 'openpsi'")

    return RegistryConfig(core=core, openpsi=openpsi)


def validate_core(value: Any) -> CoreConfig:
    section = require_mapping(value, "core")
    unknown = set(section) - CORE_KEYS
    if unknown:
        raise ConfigError(f"core: unknown key(s): {format_keys(unknown)}")

    constants = require_mapping(section.get("constants", {}), "core.constants")
    modules = require_mapping(section.get("modules", {}), "core.modules")

    for name, constant_value in constants.items():
        validate_symbol(name, f"core.constants.{name}")
        validate_metta_expression(constant_value, f"core.constants.{name}")

    for predicate, symbol in modules.items():
        validate_symbol(predicate, f"core.modules.{predicate}")
        validate_symbol(symbol, f"core.modules.{predicate}")

    if not constants and not modules:
        raise ConfigError("core: expected at least one constant or module declaration")

    return CoreConfig(constants=constants, modules=modules)


def validate_openpsi(value: Any) -> OpenPsiConfig:
    section = require_mapping(value, "openpsi")
    unknown = set(section) - OPENPSI_KEYS
    if unknown:
        raise ConfigError(f"openpsi: unknown key(s): {format_keys(unknown)}")

    raw_indices = require_mapping(section.get("indices", {}), "openpsi.indices")
    constants = require_mapping(section.get("constants", {}), "openpsi.constants")
    groups = require_mapping(section.get("groups", {}), "openpsi.groups")

    if not raw_indices:
        raise ConfigError("openpsi.indices: expected at least one index declaration")

    indices: dict[str, list[str]] = {}
    for index_name, symbols in raw_indices.items():
        validate_symbol(index_name, f"openpsi.indices.{index_name}")
        index_symbols = require_sequence(symbols, f"openpsi.indices.{index_name}")
        if not index_symbols:
            raise ConfigError(f"openpsi.indices.{index_name}: expected at least one symbol")

        seen: set[str] = set()
        normalized_symbols: list[str] = []
        for offset, symbol in enumerate(index_symbols):
            path = f"openpsi.indices.{index_name}[{offset}]"
            validate_symbol(symbol, path)
            if symbol in seen:
                raise ConfigError(f"{path}: duplicate symbol {symbol!r}")
            seen.add(symbol)
            normalized_symbols.append(symbol)

        indices[index_name] = normalized_symbols

    for name, constant_value in constants.items():
        validate_symbol(name, f"openpsi.constants.{name}")
        validate_metta_expression(constant_value, f"openpsi.constants.{name}")

    for name, group_value in groups.items():
        validate_symbol(name, f"openpsi.groups.{name}")
        validate_index_group(name, group_value, indices)

    return OpenPsiConfig(indices=indices, constants=constants, groups=groups)


def require_mapping(value: Any, path: str) -> Mapping[str, Any]:
    if not isinstance(value, Mapping):
        raise ConfigError(f"{path}: expected a mapping")
    for key in value:
        if not isinstance(key, str):
            raise ConfigError(f"{path}: expected string keys")
    return value


def require_sequence(value: Any, path: str) -> Sequence[Any]:
    if isinstance(value, (str, bytes)) or not isinstance(value, Sequence):
        raise ConfigError(f"{path}: expected a list")
    return value


def validate_symbol(value: Any, path: str) -> None:
    if not isinstance(value, str) or not SYMBOL_RE.match(value):
        raise ConfigError(f"{path}: expected a valid MeTTa symbol, got {value!r}")


def validate_metta_expression(value: Any, path: str) -> None:
    if value is None:
        return
    if isinstance(value, bool):
        return
    if isinstance(value, int):
        return
    if isinstance(value, float):
        if not math.isfinite(value):
            raise ConfigError(f"{path}: expected a finite number")
        return
    if isinstance(value, str):
        return
    if isinstance(value, Sequence) and not isinstance(value, (bytes, str)):
        for offset, item in enumerate(value):
            validate_metta_expression(item, f"{path}[{offset}]")
        return
    raise ConfigError(f"{path}: unsupported MeTTa expression value {value!r}")


def validate_index_group(name: str, value: Any, indices: Mapping[str, list[str]]) -> None:
    if isinstance(value, int) and not isinstance(value, bool):
        values = [value]
    else:
        raw_values = require_sequence(value, f"openpsi.groups.{name}")
        values = []
        for offset, item in enumerate(raw_values):
            if not isinstance(item, int) or isinstance(item, bool):
                raise ConfigError(f"openpsi.groups.{name}[{offset}]: expected an integer")
            values.append(item)

    index_name = infer_index_name_for_group(name, indices)
    if index_name is None:
        return

    upper_bound = len(indices[index_name])
    for item in values:
        if item < 0 or item >= upper_bound:
            raise ConfigError(
                f"openpsi.groups.{name}: index {item} is outside {index_name} range 0..{upper_bound - 1}"
            )


def infer_index_name_for_group(
    group_name: str,
    indices: Mapping[str, list[str]],
) -> str | None:
    if "GOAL" in group_name and "GoalIndex" in indices:
        return "GoalIndex"
    if "MOD" in group_name and "ModulatorIndex" in indices:
        return "ModulatorIndex"
    if "STIMULUS" in group_name and "StimulusIndex" in indices:
        return "StimulusIndex"
    return None


def build_outputs(
    config: RegistryConfig,
    target: str,
    source: Path,
    core_output: Path,
    openpsi_output: Path,
) -> dict[Path, str]:
    outputs: dict[Path, str] = {}

    if target in {"all", "core"}:
        if config.core is None:
            raise ConfigError("target 'core' requested but registry has no core section")
        outputs[core_output] = render_core_config(config.core, source)

    if target in {"all", "openpsi"}:
        if config.openpsi is None:
            raise ConfigError("target 'openpsi' requested but registry has no openpsi section")
        outputs[openpsi_output] = render_openpsi_config(config.openpsi, source)

    return outputs


def render_core_config(config: CoreConfig, source: Path) -> str:
    lines = generated_header(source)
    lines.extend(
        [
            ";; Core framework constants - not tied to any specific cognitive system",
            "",
        ]
    )

    for name, value in config.constants.items():
        lines.append(f"(= ({name}) {format_metta_expr(value)})")

    if config.constants and config.modules:
        lines.append("")

    if config.modules:
        lines.extend(
            [
                ";; MetaMo module declarations",
                ";; Each atom names a constructor or function symbol used by core/registry.metta.",
                "",
            ]
        )
        width = max(len(name) for name in config.modules)
        for predicate, symbol in config.modules.items():
            lines.append(f"({predicate.ljust(width)} {format_metta_expr(symbol)})")

    return "\n".join(lines).rstrip() + "\n"


def render_openpsi_config(config: OpenPsiConfig, source: Path) -> str:
    lines = generated_header(source)
    lines.extend([";; OpenPSI dimension configuration", ""])

    for index_name, dimension_name in INDEX_DIMENSION_CONSTANTS.items():
        if index_name in config.indices:
            lines.append(f"(= ({dimension_name}) {len(config.indices[index_name])})")

    lines.append("")

    for index_name, symbols in config.indices.items():
        lines.append(f";; {index_name} atoms")
        for offset, symbol in enumerate(symbols):
            lines.append(f"({index_name} {format_metta_expr(symbol)} {offset})")
        lines.append("")

    if config.constants:
        lines.append(";; OpenPSI behavioral constants")
        for name, value in config.constants.items():
            lines.append(f"(= ({name}) {format_metta_expr(value)})")
        lines.append("")

    if config.groups:
        lines.append(";; OpenPSI merge index categories")
        for name, value in config.groups.items():
            lines.append(f"(= ({name}) {format_metta_expr(value)})")
        lines.append("")

    lines.append(OPENPSI_TAIL.rstrip())
    return "\n".join(lines).rstrip() + "\n"


def generated_header(source: Path) -> list[str]:
    source_text = source.as_posix()
    return [
        ";; GENERATED FILE - do not edit by hand.",
        f";; Source: {source_text}",
        f";; Regenerate: python3 scripts/generate-config.py {source_text} --write",
        "",
    ]


def format_metta_expr(value: Any) -> str:
    if value is None:
        return "()"
    if isinstance(value, bool):
        return "True" if value else "False"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        if not math.isfinite(value):
            raise ConfigError(f"cannot render non-finite number {value!r}")
        if value.is_integer():
            return f"{value:.1f}"
        return format(value, ".15g")
    if isinstance(value, str):
        if SYMBOL_RE.match(value):
            return value
        return json.dumps(value)
    if isinstance(value, Sequence) and not isinstance(value, (bytes, str)):
        return "(" + " ".join(format_metta_expr(item) for item in value) + ")"
    raise ConfigError(f"cannot render value as MeTTa expression: {value!r}")


def write_outputs(output_root: Path, outputs: Mapping[Path, str], quiet: bool) -> None:
    for relative_path, content in outputs.items():
        output_path = output_root / relative_path
        output_path.parent.mkdir(parents=True, exist_ok=True)

        if output_path.exists() and output_path.read_text(encoding="utf-8") == content:
            if not quiet:
                print(f"unchanged {output_path}")
            continue

        output_path.write_text(content, encoding="utf-8")
        if not quiet:
            print(f"wrote {output_path}")


def check_outputs(output_root: Path, outputs: Mapping[Path, str], quiet: bool) -> int:
    stale: list[Path] = []
    for relative_path, content in outputs.items():
        output_path = output_root / relative_path
        if not output_path.exists() or output_path.read_text(encoding="utf-8") != content:
            stale.append(output_path)

    if stale:
        if not quiet:
            for output_path in stale:
                print(f"stale {output_path}", file=sys.stderr)
        return 1

    if not quiet:
        for relative_path in outputs:
            print(f"ok {output_root / relative_path}")
    return 0


def print_outputs(outputs: Mapping[Path, str]) -> None:
    multiple = len(outputs) > 1
    for offset, (path, content) in enumerate(outputs.items()):
        if multiple:
            if offset:
                print()
            print(f";; ----- {path.as_posix()} -----")
        print(content, end="")


def format_keys(keys: set[str]) -> str:
    return ", ".join(sorted(keys))


if __name__ == "__main__":
    raise SystemExit(main())
