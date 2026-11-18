"""Returning freed memory to the operating system.

CPython frees objects into glibc's allocator, which often keeps the pages
(especially across many threads), so a process that briefly needed a lot of
memory stays big. After heavy work we collect garbage and ask glibc to trim.
"""

import ctypes
import ctypes.util
import gc
import logging
import sys

logger = logging.getLogger(__name__)
_libc = None


def release_memory() -> None:
    """Collects garbage, then (on Linux) returns free heap pages to the OS."""
    global _libc
    gc.collect()
    if not sys.platform.startswith("linux"):
        return
    try:
        if _libc is None:
            _libc = ctypes.CDLL(ctypes.util.find_library("c") or "libc.so.6")
        _libc.malloc_trim(0)
    except Exception:  # musl or an unusual libc: nothing to trim
        logger.debug("malloc_trim unavailable", exc_info=True)
