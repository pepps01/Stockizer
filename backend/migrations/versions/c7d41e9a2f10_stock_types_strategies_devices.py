"""selector stock types, optimizer strategies, push device tokens

Revision ID: c7d41e9a2f10
Revises: b12fc6abfc32
Create Date: 2026-11-09 20:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'c7d41e9a2f10'
down_revision = 'b12fc6abfc32'
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table('selector_runs', schema=None) as batch_op:
        batch_op.add_column(sa.Column('stock_type', sa.String(length=16), nullable=False, server_default='equity'))

    with op.batch_alter_table('optimizer_runs', schema=None) as batch_op:
        batch_op.add_column(sa.Column('strategy', sa.String(length=32), nullable=False, server_default='algebraic'))

    op.create_table(
        'device_tokens',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('user_id', sa.String(length=36), nullable=False),
        sa.Column('token', sa.String(length=512), nullable=False),
        sa.Column('platform', sa.String(length=16), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('last_seen_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('token'),
    )
    with op.batch_alter_table('device_tokens', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_device_tokens_user_id'), ['user_id'], unique=False)


def downgrade():
    with op.batch_alter_table('device_tokens', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_device_tokens_user_id'))
    op.drop_table('device_tokens')

    with op.batch_alter_table('optimizer_runs', schema=None) as batch_op:
        batch_op.drop_column('strategy')

    with op.batch_alter_table('selector_runs', schema=None) as batch_op:
        batch_op.drop_column('stock_type')
