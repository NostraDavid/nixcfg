-- Unsloth's internal app_settings schema; check compatibility when updating.
CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT NOT NULL PRIMARY KEY,
  value_json TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- Seed fresh installations without overwriting choices made in the UI.
INSERT INTO app_settings (key, value_json, updated_at) VALUES
  ('systemone_enabled', 'true', datetime('now')),
  ('systemone_model', '"laya-multilingual"', datetime('now')),
  ('systemone_device', '"cpu"', datetime('now')),
  ('keyless_api_access_scope', '"inference"', datetime('now')),
  ('keyless_api_access_tools', 'false', datetime('now'))
ON CONFLICT(key) DO NOTHING;
