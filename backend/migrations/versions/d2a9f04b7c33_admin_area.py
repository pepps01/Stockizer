"""admin area: user roles and status, admin audit log

Revision ID: d2a9f04b7c33
Revises: c7d41e9a2f10
Create Date: 2026-11-09 21:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'd2a9f04b7c33'
down_revision = 'c7d41e9a2f10'
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.add_column(sa.Column('is_admin', sa.Boolean(), nullable=False, server_default=sa.false()))
        batch_op.add_column(sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.true()))

    op.create_table(
        'admin_actions',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('admin_id', sa.String(length=36), nullable=False),
        sa.Column('action', sa.String(length=40), nullable=False),
        sa.Column('target_type', sa.String(length=20), nullable=False),
        sa.Column('target_id', sa.String(length=64), nullable=False),
        sa.Column('detail', sa.JSON(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['admin_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id'),
    )
    with op.batch_alter_table('admin_actions', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_admin_actions_admin_id'), ['admin_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_admin_actions_created_at'), ['created_at'], unique=False)


def downgrade():
    with op.batch_alter_table('admin_actions', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_admin_actions_created_at'))
        batch_op.drop_index(batch_op.f('ix_admin_actions_admin_id'))
    op.drop_table('admin_actions')

    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.drop_column('is_active')
        batch_op.drop_column('is_admin')
