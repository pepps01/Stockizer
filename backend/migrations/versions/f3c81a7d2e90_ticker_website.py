"""ticker website for company logos

Revision ID: f3c81a7d2e90
Revises: e6b3c18d4a52
Create Date: 2026-11-17 15:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'f3c81a7d2e90'
down_revision = 'e6b3c18d4a52'
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table('tickers') as batch_op:
        batch_op.add_column(sa.Column('website', sa.String(length=200), nullable=True))


def downgrade():
    with op.batch_alter_table('tickers') as batch_op:
        batch_op.drop_column('website')
