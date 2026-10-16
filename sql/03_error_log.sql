CREATE TABLE IF NOT EXISTS error_log (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  workflow_name text,
  workflow_id text,
  execution_id text,
  node_name text,
  error_message text,
  raw jsonb
);
CREATE INDEX IF NOT EXISTS error_log_occurred_idx ON error_log (occurred_at DESC);
