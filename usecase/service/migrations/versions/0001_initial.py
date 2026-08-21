from alembic import op

revision = "0001_initial"
down_revision = None

def upgrade():
    op.execute("""
    CREATE TABLE sessions (
        session_id     TEXT PRIMARY KEY,
        goals          JSONB NOT NULL,
        mods           JSONB NOT NULL,
        anti_goals     JSONB NOT NULL,
        state_version  INTEGER NOT NULL DEFAULT 0,
        status         TEXT NOT NULL DEFAULT 'active',
        config_version TEXT NOT NULL DEFAULT 'v1',
        created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
        updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
        expires_at     TIMESTAMPTZ
    );

    CREATE TABLE cycle_decisions (
        id              BIGSERIAL PRIMARY KEY,
        session_id      TEXT NOT NULL REFERENCES sessions(session_id),
        state_version   INTEGER,
        query           TEXT,
        selected_action TEXT,
        answer          TEXT,
        action_scores   JSONB,
        context         JSONB,
        stimulus        JSONB,
        created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE TABLE idempotency_keys (
        id               BIGSERIAL PRIMARY KEY,
        session_id       TEXT NOT NULL,
        idempotency_key  TEXT NOT NULL,
        request_hash     TEXT NOT NULL,
        status           TEXT NOT NULL DEFAULT 'pending',
        response         JSONB,
        created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
        UNIQUE (session_id, idempotency_key)
    );

    CREATE INDEX ix_cycle_decisions_session ON cycle_decisions(session_id);
    """)

def downgrade():
    op.execute("DROP TABLE idempotency_keys; DROP TABLE cycle_decisions; DROP TABLE sessions;")