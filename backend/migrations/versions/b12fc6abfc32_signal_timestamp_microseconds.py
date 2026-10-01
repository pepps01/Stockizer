"""signal timestamp microseconds

Revision ID: b12fc6abfc32
Revises: a3880ae1884a
Create Date: 2026-09-29 22:37:45.913796

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import mysql


# revision identifiers, used by Alembic.
revision = 'b12fc6abfc32'
down_revision = 'a3880ae1884a'
branch_labels = None
depends_on = None


def upgrade():
    # Autogenerate doesn't see precision-only changes. MySQL DATETIME drops
    # fractional seconds, which let two signals share a timestamp.
    if op.get_bind().dialect.name == "mysql":
        op.alter_column("signals", "emitted_at", existing_type=mysql.DATETIME(), type_=mysql.DATETIME(fsp=6), existing_nullable=False)


def downgrade():
    if op.get_bind().dialect.name == "mysql":
        op.alter_column("signals", "emitted_at", existing_type=mysql.DATETIME(fsp=6), type_=mysql.DATETIME(), existing_nullable=False)
