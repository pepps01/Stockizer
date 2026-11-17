import os

from app import create_app, get_container
from app.workers import AdviserWorker, CacheWarmer

app = create_app()


def start_workers(flask_app=app) -> None:
    """Background threads: the market cache warmer and (unless disabled) the
    Adviser loop. Run them in exactly one process per database."""
    container = get_container(flask_app)
    CacheWarmer(flask_app, container.board, container.uow).start()
    if flask_app.config["ADVISER_WORKER"]:
        AdviserWorker(flask_app, container.adviser, container.uow).start()


if __name__ == "__main__":
    # With the debug reloader the app is built twice; only the reloaded child
    # (WERKZEUG_RUN_MAIN=true) runs background threads so work isn't duplicated.
    if not app.debug or os.environ.get("WERKZEUG_RUN_MAIN") == "true":
        start_workers()
    app.run(debug=app.debug, port=5000, threaded=True)
