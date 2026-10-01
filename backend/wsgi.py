import os

from app import create_app, get_container
from app.workers import AdviserWorker, CacheWarmer

app = create_app()

if __name__ == "__main__":
    # With the debug reloader the app is built twice; only the reloaded child
    # (WERKZEUG_RUN_MAIN=true) runs background threads so work isn't duplicated.
    if not app.debug or os.environ.get("WERKZEUG_RUN_MAIN") == "true":
        container = get_container(app)
        CacheWarmer(app, container.board, container.uow).start()
        if app.config["ADVISER_WORKER"]:
            AdviserWorker(app, container.adviser, container.uow).start()
    app.run(debug=app.debug, port=5000, threaded=True)
