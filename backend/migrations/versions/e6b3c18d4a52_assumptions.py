"""investor assumptions: buy / hold / sell calls per ticker

Revision ID: e6b3c18d4a52
Revises: d2a9f04b7c33
Create Date: 2026-11-17 09:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'e6b3c18d4a52'
down_revision = 'd2a9f04b7c33'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'assumptions',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('user_id', sa.String(length=36), nullable=False),
        sa.Column('ticker_id', sa.String(length=36), nullable=False),
        sa.Column('stance', sa.Enum('buy', 'hold', 'sell', name='assumption_stance'), nullable=False),
        sa.Column('price', sa.Numeric(precision=18, scale=6), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['ticker_id'], ['tickers.id']),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'ticker_id', name='uq_assumption_user_ticker'),
    )
    with op.batch_alter_table('assumptions', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_assumptions_user_id'), ['user_id'], unique=False)


def downgrade():
    with op.batch_alter_table('assumptions', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_assumptions_user_id'))
    op.drop_table('assumptions')
