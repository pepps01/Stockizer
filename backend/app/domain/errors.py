"""Domain exceptions. Services raise these; the HTTP layer maps each class to a
status code in one place (see app/api/base.py), so no service knows about HTTP."""


class DomainError(Exception):
    status_code = 400

    def __init__(self, message: str):
        super().__init__(message)
        self.message = message


class ValidationError(DomainError):
    status_code = 400


class NotFoundError(DomainError):
    status_code = 404


class ConflictError(DomainError):
    status_code = 409


class AuthenticationError(DomainError):
    status_code = 401


class ForbiddenError(DomainError):
    status_code = 403


class UnprocessableError(DomainError):
    status_code = 422
