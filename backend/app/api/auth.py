from flask import Blueprint, jsonify, request
from flask_jwt_extended import get_jwt_identity, jwt_required

from app.container import get_container
from app.services.auth_service import (
    EmailAlreadyRegisteredError,
    EmailNotVerifiedError,
    InvalidCredentialsError,
    InvalidOrExpiredTokenError,
)

bp = Blueprint("auth", __name__, url_prefix="/api/auth")


@bp.post("/register")
def register():
    data = request.get_json(silent=True) or {}
    required = ("first_name", "last_name", "email", "password")
    missing = [field for field in required if not data.get(field)]
    if missing:
        return jsonify(error=f"Missing required field(s): {', '.join(missing)}"), 400

    if len(data["password"]) < 8:
        return jsonify(error="Password must be at least 8 characters long"), 400

    try:
        user = get_container().auth_service.register(
            first_name=data["first_name"],
            last_name=data["last_name"],
            email=data["email"],
            password=data["password"],
        )
    except EmailAlreadyRegisteredError:
        return jsonify(error="An account with this email already exists"), 409

    return jsonify(user=user), 201


@bp.get("/verify-email")
def verify_email():
    token = request.args.get("token")
    if not token:
        return jsonify(error="Missing token"), 400

    try:
        user = get_container().auth_service.verify_email(token)
    except InvalidOrExpiredTokenError:
        return jsonify(error="Invalid or expired verification token"), 400

    return jsonify(user=user)


@bp.post("/login")
def login():
    data = request.get_json(silent=True) or {}
    if not data.get("email") or not data.get("password"):
        return jsonify(error="Email and password are required"), 400

    try:
        result = get_container().auth_service.login(email=data["email"], password=data["password"])
    except InvalidCredentialsError:
        return jsonify(error="Invalid email or password"), 401
    except EmailNotVerifiedError:
        return jsonify(error="Please verify your email before logging in"), 403

    return jsonify(result)


@bp.get("/me")
@jwt_required()
def get_me():
    user = get_container().auth_service.get_profile(int(get_jwt_identity()))
    if user is None:
        return jsonify(error="User not found"), 404
    return jsonify(user=user)


@bp.put("/me")
@jwt_required()
def update_me():
    data = request.get_json(silent=True) or {}
    user = get_container().auth_service.update_profile(
        int(get_jwt_identity()),
        first_name=data.get("first_name"),
        last_name=data.get("last_name"),
    )
    if user is None:
        return jsonify(error="User not found"), 404
    return jsonify(user=user)
