"""Who is calling: the client's IP address, user agent and platform, read by
the HTTP layer and handed to services as a plain value object."""

from dataclasses import dataclass

CLIENT_PLATFORMS = ("web", "android", "ios", "other")


@dataclass(frozen=True)
class ClientInfo:
    ip: str | None = None
    user_agent: str | None = None
    platform: str = "other"

    @staticmethod
    def platform_from(header: str | None, user_agent: str | None) -> str:
        """The platform the app declared (X-Client-Platform), else a guess from
        the user agent: browsers send "Mozilla/", the Flutter app "Dart/"."""
        declared = (header or "").strip().lower()
        if declared in CLIENT_PLATFORMS:
            return declared
        agent = user_agent or ""
        if agent.startswith("Mozilla/"):
            return "web"
        return "other"
