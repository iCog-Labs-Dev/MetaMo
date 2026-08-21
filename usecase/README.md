# Usecase Guide

This folder contains the current Qwestor-style integration over MetaMo.
The implementation already works with the existing main-loop, usecase/main-loop.metta.

## Current Implementation

The runtime path is:

1. Parse the user query in `context_parser.py`.
2. Project the Qwestor state into a MetaMo motivation state.
3. Convert the parsed context into a `Stimulus`.
4. Build the subsystem state list.
5. Run `runMetaMoCycleDefault` with `defaultMetaMoBimonad`.
6. Print the Qwestor decision report in the terminal.


## Subsystem Options

The current usecase is configured for a single subsystem, which is the simplest
and recommended path for the existing pipeline.

If you want genuinely distinct motivational subsystems, step 4 in
[`main-loop.metta`](main-loop.metta) can be expanded to provide two different
`subsystemState` entries, for example `qwestor` and `ethics`, with different
motivation states.

That means you have two supported options:

- Single subsystem: keep one `subsystemState` and use the current default path.
- Two distinct subsystems: supply two different subsystem states and let the
  MetaMo cycle run consensus across them.

The current implementation uses `defaultMetaMoBimonad` from the main registry
and default dynamics, so no special wiring is needed in the loop itself.

## Terminal Result

The decision report is printed by `printQwestorResult`, so the terminal shows
the selected action, candidate list, stimulus values, and the next motivation
state after the cycle completes.

## API Service

The Qwestor usecase now includes a FastAPI service for creating and retrieving
sessions, running a single reasoning cycle, and deleting sessions. PostgreSQL
stores session state and cycle decisions, Redis provides caching and per-session
locking, and Alembic manages the database schema. Docker Compose runs the API
and its supporting services together.

## Environment Setup

For the usecase folder, define the following variables:

```env
GEMINI_API_KEY=your_api_key_here
GEMINI_MODEL=your_model_name_here
POSTGRES_DB=your_postgres_db
POSTGRES_USER=your_postgres_user
POSTGRES_PASSWORD=your_postgres_password
DATABASE_URL=postgresql+psycopg2://metamo:your_postgres_password@postgres:5432/metamo
REDIS_URL=redis://redis:6379/0
```


## Run and Test the API

From the repository root, apply the migration and start the service:

```bash
docker compose build
docker compose run --rm migrate
docker compose up api
```

Open Swagger UI at [http://localhost:8000/docs](http://localhost:8000/docs).
Create a session with `POST /v1/sessions`, then use its `session_id` and
`state_version` with `POST /v1/sessions/{session_id}/cycles`. The cycle endpoint
also requires a unique `Idempotency-Key` header. Use
`GET /v1/sessions/{session_id}` to verify the updated session state.

To inspect the persisted data in DBeaver, create a PostgreSQL connection to
`localhost:5432` using the database, username, and password from `.env`. The
`sessions`, `cycle_decisions`, and `idempotency_keys` tables are under the
`public` schema.

## References

- [`main-loop.metta`](main-loop.metta)
- [`config.metta`](config.metta)
- [`adapters/stimulus_adapter.metta`](adapters/stimulus_adapter.metta)
- [`utils.metta`](utils.metta)
