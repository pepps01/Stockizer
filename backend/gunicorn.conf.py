"""Production server (Render and similar). One worker process: quotes, rate
limits and the Adviser loop live in memory, so they must not be split across
processes. Threads serve concurrent requests and the /ws sockets."""

import os

bind = f"0.0.0.0:{os.environ.get('PORT', '5000')}"
workers = 1
worker_class = "gthread"
threads = int(os.environ.get("GUNICORN_THREADS", "32"))
timeout = 300  # Selector and Optimizer runs download history on first use
graceful_timeout = 30
accesslog = "-"
errorlog = "-"
forwarded_allow_ips = "*"


def post_worker_init(worker):
    from wsgi import start_workers

    start_workers()
