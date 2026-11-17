#!/usr/bin/env bash
# Production start: bring the schema up to date, make sure the catalog, the
# demo account and the first admin exist, then serve.
set -euo pipefail
export FLASK_APP=wsgi.py
python -m flask db upgrade
python -m flask seed --demo-user
python -m flask ensure-admin
exec gunicorn -c gunicorn.conf.py wsgi:app
