from flask import Blueprint, jsonify

from app.container import get_container

bp = Blueprint("adviser", __name__, url_prefix="/api/adviser")


@bp.get("/<symbol>/signal")
def get_signal(symbol):
    result = get_container().adviser.get_signal(symbol=symbol)
    return jsonify(result)
