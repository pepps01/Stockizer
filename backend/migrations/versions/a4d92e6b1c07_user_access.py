"""user ip addresses: signup / last ip and an access log

Revision ID: a4d92e6b1c07
Revises: f3c81a7d2e90
Create Date: 2026-11-17 16:30:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'a4d92e6b1c07'
down_revision = 'f3c81a7d2e90'
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table('users') as batch_op:
        batch_op.add_column(sa.Column('signup_ip', sa.String(length=45), nullable=True))
        batch_op.add_column(sa.Column('last_ip', sa.String(length=45), nullable=True))
        batch_op.add_column(sa.Column('last_seen_at', sa.DateTime(), nullable=True))
    op.create_table(
        'user_access',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('user_id', sa.String(length=36), nullable=False),
        sa.Column('event', sa.Enum('register', 'login', 'resume', name='access_event'), nullable=False),
        sa.Column('ip', sa.String(length=45), nullable=True),
        sa.Column('platform', sa.String(length=16), nullable=False),
        sa.Column('user_agent', sa.String(length=255), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id'),
    )
    with op.batch_alter_table('user_access') as batch_op:
        batch_op.create_index('ix_user_access_user_id', ['user_id'])
        batch_op.create_index('ix_user_access_created_at', ['created_at'])


def downgrade():
    op.drop_table('user_access')
    with op.batch_alter_table('users') as batch_op:
        batch_op.drop_column('last_seen_at')
        batch_op.drop_column('last_ip')
        batch_op.drop_column('signup_ip')
