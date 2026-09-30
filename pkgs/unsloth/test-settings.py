"""Run with: python pkgs/unsloth/test-settings.py"""

import json
import sqlite3
from pathlib import Path

sql = Path(__file__).with_name("settings.sql").read_text()
connection = sqlite3.connect(":memory:")
try:
    connection.executescript(sql)
    expected = {
        "systemone_enabled": True,
        "systemone_model": "laya-multilingual",
        "systemone_device": "cpu",
        "keyless_api_access_scope": "inference",
        "keyless_api_access_tools": False,
    }
    actual = {
        key: json.loads(value)
        for key, value in connection.execute("SELECT key, value_json FROM app_settings")
    }
    assert actual == expected, actual
    connection.execute(
        "UPDATE app_settings SET value_json = ? WHERE key = ?",
        ('"off"', "keyless_api_access_scope"),
    )
    connection.executescript(sql)
    assert connection.execute("SELECT COUNT(*) FROM app_settings").fetchone()[0] == 5
    assert (
        connection.execute(
            "SELECT value_json FROM app_settings WHERE key = ?",
            ("keyless_api_access_scope",),
        ).fetchone()[0]
        == '"off"'
    )
finally:
    connection.close()

print("Unsloth defaults verified; repeated initialization preserves UI settings.")
