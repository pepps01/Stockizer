import hashlib
import os

from app.contracts.repositories import IArtifactRepository, IUnitOfWork
from app.contracts.services import IArtifactStore
from app.models import Artifact


class LocalArtifactStore(IArtifactStore):
    """Writes pipeline outputs (ticker files, parameter sets) under a local
    directory and records them through the artifact repository. An S3-backed
    store can replace it by implementing the same interface."""

    def __init__(self, root: str, artifacts: IArtifactRepository, uow: IUnitOfWork):
        self.root = root
        self._artifacts = artifacts
        self._uow = uow

    def save(self, *, owner_id: str, kind: str, filename: str, content: bytes, content_type: str) -> Artifact:
        artifact = Artifact(
            owner_id=owner_id,
            kind=kind,
            filename=filename,
            content_type=content_type,
            sha256=hashlib.sha256(content).hexdigest(),
            size_bytes=len(content),
            storage_key="",
        )
        self._artifacts.add(artifact)
        self._uow.flush()  # assigns the id used in the storage key
        artifact.storage_key = f"{owner_id}/{artifact.id}_{filename}"
        path = self.path(artifact)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as fh:
            fh.write(content)
        return artifact

    def path(self, artifact: Artifact) -> str:
        return os.path.join(self.root, *artifact.storage_key.split("/"))

    def get_owned(self, artifact_id: str, owner_id: str) -> Artifact | None:
        artifact = self._artifacts.get(artifact_id)
        return artifact if artifact is not None and artifact.owner_id == owner_id else None
