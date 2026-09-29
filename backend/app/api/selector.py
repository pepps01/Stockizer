from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required

from app.container import get_container
from app.models.user_action import VALID_ACTIONS

bp = Blueprint("selector", __name__, url_prefix="/api/selector")

VALID_STOCK_TYPES = ("growth", "value", "equity")


@bp.get("")
def run_selector():
    stock_type = request.args.get("type", "growth").lower()
    if stock_type not in VALID_STOCK_TYPES:
        return jsonify(error=f"type must be one of {VALID_STOCK_TYPES}"), 400

    top_n = request.args.get("top_n", default=10, type=int)
    results = get_container().selector.select(stock_type=stock_type, top_n=top_n)
    return jsonify(stock_type=stock_type, results=results)


@bp.post("/action")
@jwt_required()
def record_action():
    data = request.get_json(silent=True) or {}
    symbol = data.get("symbol")
    action = data.get("action")

    if not symbol or action not in VALID_ACTIONS:
        return jsonify(error=f"symbol is required and action must be one of {VALID_ACTIONS}"), 400

    entry = get_container().action_repository.add(
        user_id=int(get_jwt_identity()), symbol=symbol, action=action
    )
    return jsonify(action=entry.to_dict()), 201
