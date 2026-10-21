#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "jsonschema==4.26.0",
#     "PyYAML==6.0.3",
# ]
# ///
"""Generate CTB daily-candle descriptors and validate Bitol YAML or JSON."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch
from uuid import uuid7

import jsonschema
import yaml
from referencing import Registry

SCHEMAS = {
    "DataContract": (
        "v3.2.0",
        "odcs-v3.2.0.schema",
        "edb41f33ec46e84780e99872ab2bd67f074959d2bf3e9c9fc54e61f8982b0d93",
    ),
    "DataProduct": (
        "v1.1.0",
        "odps-v1.1.0.schema",
        "b7eae1af15b3c6b18e5dffaa2119212acb38ec73286933c76d16c8712e0d90d1",
    ),
}
VALUE_FIELDS = ("open", "high", "low", "close", "volume")
KEY_FIELDS = ("market", "day_start")
REQUIRED_FIELDS = (
    *KEY_FIELDS,
    "observed_candles",
    "missing_minutes",
    "quality",
    "freshness",
)
RUNTIME_QUERY = """
import json
from typing import get_args
from ctb_bitvavo import curated
print(json.dumps({
    "source": curated.__file__,
    "types": {name: str(dtype) for name, dtype in curated.DAILY_SCHEMA.items()},
    "outcomes": {name: list(get_args(curated.CuratedArtifact.model_fields[name].annotation))
                 for name in ("quality", "freshness")},
}))
"""


class UniqueKeysLoader(yaml.SafeLoader):
    """Reject duplicate keys instead of silently keeping the final value."""

    def construct_mapping(self, node, deep=False):
        self.flatten_mapping(node)
        mapping = {}
        for key_node, value_node in node.value:
            key = self.construct_object(key_node, deep=deep)
            if not isinstance(key, str) or key in mapping:
                raise ValueError("Descriptor mappings require unique string keys")
            mapping[key] = self.construct_object(value_node, deep=deep)
        return mapping


UniqueKeysLoader.add_constructor(
    "tag:yaml.org,2002:timestamp", UniqueKeysLoader.construct_scalar
)


def load_document(path: Path) -> dict:
    document = yaml.load(path.read_text(encoding="utf-8"), Loader=UniqueKeysLoader)
    if not isinstance(document, dict):
        raise ValueError(f"{path}: expected one descriptor object")
    return document


def load_validators() -> dict:
    result = {}
    for kind, (_, filename, checksum) in SCHEMAS.items():
        path = Path(__file__).resolve().parent.parent / "assets/schemas" / filename
        content = path.read_bytes()
        if hashlib.sha256(content).hexdigest() != checksum:
            raise ValueError(f"Bundled schema checksum mismatch: {filename}")
        schema = json.loads(content)
        jsonschema.Draft202012Validator.check_schema(schema)
        result[kind] = jsonschema.Draft202012Validator(
            schema, registry=Registry(), format_checker=jsonschema.FormatChecker()
        )
    return result


def runtime_schema(root: Path) -> dict:
    root = root.resolve()
    if not (root / "dagster-runtime").is_dir():
        raise ValueError("--ctb-root must contain dagster-runtime/ and ctb-bitvavo/")
    python = root / "ctb-bitvavo/.venv/bin/python"
    environment = {
        key: value
        for key, value in os.environ.items()
        if key not in {"PYTHONPATH", "PYTHONHOME", "VIRTUAL_ENV"}
    }
    result = subprocess.run(
        [str(python), "-I", "-c", RUNTIME_QUERY],
        cwd=root,
        env=environment,
        text=True,
        capture_output=True,
        timeout=30,
    )
    if result.returncode:
        raise ValueError(
            "Cannot import CTB DAILY_SCHEMA; synchronize ctb-bitvavo's environment"
        )
    runtime = json.loads(result.stdout)
    expected_source = root / "ctb-bitvavo/src/ctb_bitvavo/curated.py"
    source = runtime.get("source")
    if (
        not isinstance(source, str)
        or Path(source).resolve() != expected_source.resolve()
    ):
        raise ValueError(
            "CTB environment imports another checkout; synchronize ctb-bitvavo's environment"
        )
    types = runtime["types"]
    for name in VALUE_FIELDS:
        if types.get(name) != "Decimal(precision=38, scale=18)":
            raise ValueError(f"Runtime {name} no longer has Decimal(38,18)")
    if types.get("day_start") != "Datetime(time_unit='ms', time_zone='UTC')":
        raise ValueError("Runtime day_start no longer has UTC millisecond precision")
    for name in REQUIRED_FIELDS:
        if name not in types:
            raise ValueError(f"Runtime schema is missing {name}")
    return runtime


def runtime_properties(runtime: dict) -> list[dict]:
    properties = []
    for name, physical in runtime["types"].items():
        prop = {
            "name": name,
            "physicalType": physical,
            "required": name in REQUIRED_FIELDS,
        }
        if physical == "String":
            prop["logicalType"] = "string"
        elif physical == "Int64":
            prop["logicalType"] = "integer"
            prop["logicalTypeOptions"] = {"format": "i64"}
        elif re.fullmatch(r"Decimal\(precision=\d+, scale=\d+\)", physical):
            prop["logicalType"] = "number"
            prop["description"] = (
                "Exact decimal; retain the physical precision and scale."
            )
        elif physical == "Datetime(time_unit='ms', time_zone='UTC')":
            prop["logicalType"] = "timestamp"
            prop["logicalTypeOptions"] = {
                "timezone": True,
                "defaultTimezone": "Etc/UTC",
            }
        else:
            raise ValueError(
                f"Unsupported runtime type for {name}; review its ODCS mapping"
            )
        if name in KEY_FIELDS:
            prop.update(primaryKey=True, primaryKeyPosition=KEY_FIELDS.index(name) + 1)
        if name in runtime["outcomes"]:
            prop["enum"] = [{"value": value} for value in runtime["outcomes"][name]]
        properties.append(prop)
    return properties


def generate(
    runtime: dict, contract_id: str, product_id: str, version: str, owner: str
) -> list[dict]:
    if not owner.strip() or not version.strip():
        raise ValueError("Owner and descriptor version must be nonempty")
    contract = {
        "apiVersion": "v3.2.0",
        "kind": "DataContract",
        "id": contract_id,
        "version": version,
        "name": "CTB public daily candles",
        "status": "draft",
        "team": {"name": owner},
        "description": {
            "purpose": "Public daily candle summaries.",
            "limitations": "Sparse observations do not prove zero trading or complete coverage. "
            "Empty days have null OHLCV. Quality, availability and freshness are distinct.",
        },
        "schema": [
            {
                "name": "daily_candles",
                "logicalType": "object",
                "dataGranularityDescription": "One row per market and closed UTC day.",
                "properties": runtime_properties(runtime),
            }
        ],
    }
    product = {
        "apiVersion": "v1.1.0",
        "kind": "DataProduct",
        "id": product_id,
        "version": version,
        "name": "CTB public daily candles",
        "status": "draft",
        "team": {"name": owner},
        "description": {"purpose": "Public daily candle summaries."},
        "outputPorts": [
            {
                "name": "daily_candles",
                "version": version,
                "contractId": contract_id,
                "customProperties": [{"property": "contractVersion", "value": version}],
            }
        ],
    }
    return [contract, product]


def validate(
    documents: list[dict], validators: dict, runtime: dict | None = None
) -> None:
    contracts = {}
    for document in documents:
        kind = document.get("kind")
        if not isinstance(kind, str) or kind not in SCHEMAS:
            raise ValueError("Descriptor kind must be DataContract or DataProduct")
        if document.get("apiVersion") != SCHEMAS[kind][0]:
            raise ValueError(f"{kind} requires apiVersion {SCHEMAS[kind][0]}")
        error = next(validators[kind].iter_errors(document), None)
        if error:
            location = "/".join(map(str, error.absolute_path)) or "/"
            raise ValueError(
                f"{kind}: {error.validator} validation failed at {location}"
            )
        if kind == "DataContract":
            identity = (document["id"], document["version"])
            if identity in contracts:
                raise ValueError("Duplicate contract identity and version")
            contracts[identity] = document
    for product in (d for d in documents if d["kind"] == "DataProduct"):
        if not product.get("outputPorts"):
            raise ValueError("DataProduct must expose at least one output port")
        for port in [*product.get("inputPorts", []), *product["outputPorts"]]:
            versions = [
                p["value"]
                for p in port.get("customProperties", [])
                if p["property"] == "contractVersion"
            ]
            if len(versions) > 1:
                raise ValueError("Port has duplicate contractVersion metadata")
            candidates = [
                c
                for (identity, version), c in contracts.items()
                if identity == port.get("contractId")
                and (not versions or version == versions[0])
            ]
            if len(candidates) != 1:
                raise ValueError(
                    "Port contract reference is missing, unresolved or ambiguous"
                )
            for dependency in port.get("inputContracts", []):
                if (dependency["id"], dependency["version"]) not in contracts:
                    raise ValueError("Output port has an unresolved input contract")
    if runtime is not None:
        expected = runtime_properties(runtime)
        found = False
        for contract in contracts.values():
            for obj in contract.get("schema", []):
                if obj["name"] != "daily_candles":
                    continue
                found = True
                props = obj.get("properties", [])
                actual = {p["name"]: p for p in props}
                if len(actual) != len(props) or set(actual) != {
                    p["name"] for p in expected
                }:
                    raise ValueError("Daily-candle fields differ from DAILY_SCHEMA")
                for prop in expected:
                    for key in (
                        "physicalType",
                        "logicalType",
                        "logicalTypeOptions",
                        "required",
                        "primaryKey",
                        "primaryKeyPosition",
                        "enum",
                    ):
                        default = (
                            False
                            if key in {"required", "primaryKey"}
                            else -1
                            if key == "primaryKeyPosition"
                            else None
                        )
                        value = actual[prop["name"]].get(key, default)
                        expected_value = prop.get(key, default)
                        if (
                            key == "enum"
                            and value is not None
                            and expected_value is not None
                        ):
                            value = {entry["value"] for entry in value}
                            expected_value = {
                                entry["value"] for entry in expected_value
                            }
                        if value != expected_value:
                            raise ValueError(
                                f"Daily-candle {prop['name']}.{key} differs from runtime policy"
                            )
        if not found:
            raise ValueError(
                "Runtime comparison requires a daily_candles schema object"
            )


def write_pair(
    directory: Path, documents: list[dict], *, dry_run: bool = False
) -> list[Path]:
    paths = [
        directory / "daily-candles.odcs.yaml",
        directory / "daily-candles.odps.yaml",
    ]
    if any(path.exists() for path in paths):
        raise ValueError(
            "Output descriptors already exist; edit and validate them instead"
        )
    if dry_run:
        return paths
    directory.mkdir(parents=True, exist_ok=True)
    created = []
    try:
        for path, document in zip(paths, documents, strict=True):
            with path.open("x", encoding="utf-8") as stream:
                created.append(path)
                yaml.safe_dump(document, stream, sort_keys=False, allow_unicode=True)
    except OSError:
        for path in created:
            path.unlink(missing_ok=True)
        raise
    return paths


def unit_test() -> None:
    runtime = {
        "types": {
            "market": "String",
            "day_start": "Datetime(time_unit='ms', time_zone='UTC')",
            **{name: "Decimal(precision=38, scale=18)" for name in VALUE_FIELDS},
            "observed_candles": "Int64",
            "missing_minutes": "Int64",
            "quality": "String",
            "freshness": "String",
        },
        "outcomes": {
            "quality": ["valid", "degraded"],
            "freshness": ["current", "stale"],
        },
    }
    validators = load_validators()
    pair = generate(runtime, str(uuid7()), str(uuid7()), "1.0.0", "test-owner")
    validate(pair, validators, runtime)
    properties = {prop["name"]: prop for prop in pair[0]["schema"][0]["properties"]}
    for name in ("open", "high", "low", "close", "volume"):
        assert properties[name]["logicalType"] == "number", name
        assert properties[name]["physicalType"] == "Decimal(precision=38, scale=18)", (
            name
        )
        assert properties[name]["required"] is False, name
    assert properties["day_start"]["logicalType"] == "timestamp"
    assert (
        properties["day_start"]["physicalType"]
        == "Datetime(time_unit='ms', time_zone='UTC')"
    )
    assert properties["day_start"]["logicalTypeOptions"] == {
        "timezone": True,
        "defaultTimezone": "Etc/UTC",
    }
    for name, position in (("market", 1), ("day_start", 2)):
        assert properties[name]["primaryKey"] is True
        assert properties[name]["primaryKeyPosition"] == position
        assert properties[name]["required"] is True
    for name in ("observed_candles", "missing_minutes"):
        assert properties[name]["logicalType"] == "integer"
        assert properties[name]["logicalTypeOptions"] == {"format": "i64"}
        assert properties[name]["required"] is True
    assert properties["quality"]["enum"] == [{"value": "valid"}, {"value": "degraded"}]
    assert properties["freshness"]["enum"] == [{"value": "current"}, {"value": "stale"}]
    mutations = [
        lambda docs: docs[1]["outputPorts"][0].update(contractId="unknown"),
        lambda docs: docs[1].update(
            inputPorts=[{"name": "upstream", "contractId": "unknown"}]
        ),
        lambda docs: docs[0]["schema"][0]["properties"][2].update(
            physicalType="Decimal(precision=38, scale=9)"
        ),
        lambda docs: docs[0]["schema"][0]["properties"][1].update(
            physicalType="Datetime(time_unit='ms', time_zone=None)"
        ),
        lambda docs: docs[0]["schema"][0]["properties"][2].update(required=True),
        lambda docs: docs[0].update(apiVersion="v3.1.0"),
        lambda docs: docs[0].pop("id"),
    ]
    for mutate in mutations:
        invalid = copy.deepcopy(pair)
        mutate(invalid)
        try:
            validate(invalid, validators, runtime)
        except ValueError:
            pass
        else:
            raise AssertionError("Invalid descriptor accepted")
    retained = copy.deepcopy(pair[0])
    retained["version"] = "0.9.0"
    validate([retained, *pair], validators, runtime)
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        (root / "dagster-runtime").mkdir()
        expected_source = root / "ctb-bitvavo/src/ctb_bitvavo/curated.py"
        imported = {**runtime, "source": str(expected_source)}
        completed = subprocess.CompletedProcess([], 0, stdout=json.dumps(imported))
        with patch.object(subprocess, "run", return_value=completed):
            assert runtime_schema(root)["types"] == runtime["types"]
        for source in (None, str(root / "other-checkout/curated.py")):
            imported["source"] = source
            completed = subprocess.CompletedProcess([], 0, stdout=json.dumps(imported))
            with patch.object(subprocess, "run", return_value=completed):
                try:
                    runtime_schema(root)
                except ValueError:
                    pass
                else:
                    raise AssertionError("Missing or wrong checkout source accepted")
        for timestamp in ("2026-10-07T12:00:00Z", "'2026-10-07T12:00:00Z'"):
            descriptor = root / "timestamp.yaml"
            descriptor.write_text(
                yaml.safe_dump(pair[0]) + f"contractCreatedTs: {timestamp}\n",
                encoding="utf-8",
            )
            loaded = load_document(descriptor)
            assert loaded["contractCreatedTs"] == "2026-10-07T12:00:00Z"
            validate([loaded], validators)
        write_pair(root / "dry-run", pair, dry_run=True)
        assert not (root / "dry-run").exists()
        paths = write_pair(root, pair)
        validate([load_document(path) for path in paths], validators, runtime)
        original = [path.read_bytes() for path in paths]
        try:
            write_pair(root, pair)
        except ValueError:
            pass
        else:
            raise AssertionError("Existing descriptors overwritten")
        assert [path.read_bytes() for path in paths] == original
        duplicate = root / "duplicate.yaml"
        duplicate.write_text(
            "kind: DataContract\nkind: DataProduct\n", encoding="utf-8"
        )
        try:
            load_document(duplicate)
        except ValueError:
            pass
        else:
            raise AssertionError("Duplicate YAML keys accepted")
    print("Generation, validation, retained versions and file-safety checks passed.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    check = commands.add_parser(
        "check", help="Check bundled schemas and optional CTB environment"
    )
    check.add_argument("--ctb-root", type=Path)
    commands.add_parser(
        "unit-test", help="Run isolated generation and validation checks"
    )
    generator = commands.add_parser(
        "generate", help="Create draft daily-candle ODCS and ODPS files"
    )
    generator.add_argument("--ctb-root", type=Path, required=True)
    generator.add_argument("--output-dir", type=Path, required=True)
    generator.add_argument("--owner", required=True)
    generator.add_argument("--version", default="1.0.0")
    generator.add_argument("--contract-id")
    generator.add_argument("--product-id")
    generator.add_argument(
        "--dry-run", action="store_true", help="Print validated drafts without writing"
    )
    validator = commands.add_parser(
        "validate", help="Validate descriptors and resolve local contract references"
    )
    validator.add_argument("files", nargs="+", type=Path)
    validator.add_argument(
        "--ctb-root", type=Path, help="Also compare daily-candle contracts to runtime"
    )
    args = parser.parse_args()
    try:
        if args.command == "unit-test":
            unit_test()
            return 0
        validators = load_validators()
        runtime = runtime_schema(args.ctb_root) if args.ctb_root else None
        if args.command == "check":
            print("ok")
        elif args.command == "generate":
            documents = generate(
                runtime,
                args.contract_id or str(uuid7()),
                args.product_id or str(uuid7()),
                args.version,
                args.owner,
            )
            validate(documents, validators, runtime)
            paths = write_pair(args.output_dir, documents, dry_run=args.dry_run)
            if args.dry_run:
                print(
                    yaml.safe_dump_all(documents, sort_keys=False, allow_unicode=True),
                    end="",
                )
            else:
                for path in paths:
                    print(path)
        else:
            validate([load_document(path) for path in args.files], validators, runtime)
            print(
                f"Validated {len(args.files)} descriptors"
                + (" and CTB runtime agreement." if runtime else ".")
            )
    except (
        ValueError,
        OSError,
        yaml.YAMLError,
        jsonschema.SchemaError,
        subprocess.SubprocessError,
    ) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
