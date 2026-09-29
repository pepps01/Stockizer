from flask import Blueprint, jsonify, request

from app.container import get_container

bp = Blueprint("optimizer", __name__, url_prefix="/api/optimizer")


@bp.post("/run")
def run_optimizer():
    data = request.get_json(silent=True) or {}
    symbol = data.get("symbol")
    if not symbol:
        return jsonify(error="symbol is required"), 400

    result = get_container().optimizer.optimize(
        symbol=symbol,
        historical_period=data.get("historical_period", "1y"),
        param_bounds=data.get("param_bounds"),
    )
    return jsonify(result)
