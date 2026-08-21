import os
from sqlalchemy import create_engine
"""
Database engine configuration.

Creates a SQLAlchemy engine using the database connection URL
provided through environment variables and enables connection health
checks.
"""

engine = create_engine(os.environ.get("DATABASE_URL"), pool_pre_ping=True)