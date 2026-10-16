-- InboxOps schema. Run against the 'inboxops' database.

-- =====================================================================
-- agent_runs: one row per email processed
-- =====================================================================
CREATE TABLE agent_runs (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    message_id       TEXT NOT NULL UNIQUE,
    status           TEXT NOT NULL DEFAULT 'started' CHECK (status IN (
                         'started', 'classified', 'needs_review', 'awaiting_approval',
                         'approved', 'rejected', 'expired', 'executing',
                         'executed', 'failed', 'rolled_back')),
    sender_email     TEXT NOT NULL,
    subject          TEXT NOT NULL DEFAULT '',
    received_at      TIMESTAMPTZ,
    category         TEXT CHECK (category IN (
                         'new_inquiry', 'quote_request', 'vendor_invoice',
                         'support_request', 'meeting_request', 'other')),
    confidence       NUMERIC(3,2) CHECK (confidence BETWEEN 0 AND 1),
    language         TEXT,
    reason           TEXT,
    extracted_data   JSONB,
    proposed_action  JSONB,
    odoo_records     JSONB NOT NULL DEFAULT '[]'::jsonb,
    error_message    TEXT,
    input_tokens     INTEGER NOT NULL DEFAULT 0,
    output_tokens    INTEGER NOT NULL DEFAULT 0,
    cost_usd         NUMERIC(10,6) NOT NULL DEFAULT 0,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at      TIMESTAMPTZ
);

CREATE INDEX idx_agent_runs_status     ON agent_runs (status);
CREATE INDEX idx_agent_runs_created_at ON agent_runs (created_at);

-- =====================================================================
-- approvals: one row per approval request sent to the human
-- =====================================================================
CREATE TABLE approvals (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    run_id        BIGINT NOT NULL REFERENCES agent_runs (id),
    token_hash    TEXT UNIQUE,
    approver      TEXT,
    state         TEXT NOT NULL DEFAULT 'pending' CHECK (state IN (
                      'pending', 'approved', 'rejected', 'expired')),
    final_action  JSONB,
    sent_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at    TIMESTAMPTZ NOT NULL,
    decided_at    TIMESTAMPTZ
);

CREATE INDEX idx_approvals_run_id ON approvals (run_id);
CREATE INDEX idx_approvals_pending_expiry ON approvals (expires_at) WHERE state = 'pending';

-- =====================================================================
-- eval_results: one row per test email per evaluation batch
-- =====================================================================
CREATE TABLE eval_results (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    batch               TEXT NOT NULL,
    case_id             TEXT NOT NULL,
    model               TEXT NOT NULL,
    is_adversarial      BOOLEAN NOT NULL DEFAULT false,
    expected_category   TEXT NOT NULL CHECK (expected_category IN (
                            'new_inquiry', 'quote_request', 'vendor_invoice',
                            'support_request', 'meeting_request', 'other')),
    predicted_category  TEXT CHECK (predicted_category IN (
                            'new_inquiry', 'quote_request', 'vendor_invoice',
                            'support_request', 'meeting_request', 'other')),
    category_correct    BOOLEAN,
    extracted_fields    JSONB,
    field_scores        JSONB,
    schema_valid        BOOLEAN,
    retries             INTEGER NOT NULL DEFAULT 0,
    safe_handling       BOOLEAN,
    latency_ms          INTEGER,
    input_tokens        INTEGER NOT NULL DEFAULT 0,
    output_tokens       INTEGER NOT NULL DEFAULT 0,
    cost_usd            NUMERIC(10,6) NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (batch, case_id)
);