"""Choosing a port to serve on.

This is the part of the desktop build's ``bmskb.desktop`` that a server still
needs. The rest of that module drove a native window through pywebview, which
this build deliberately does not have: there is no screen to put a window on,
and requiring a GUI toolkit would stop the board running on a headless box or in
a container.

The folder picker goes with it. On the desktop build the settings page can open a
native directory dialog; here it cannot, so ``browse_available`` reports False
and the page falls back to a plain text box. That is the honest answer rather
than a dialog that would open on the server's screen, where nobody is looking.
"""

from __future__ import annotations

import socket


def find_port(host: str, wanted: int, walk: bool = True, attempts: int = 25) -> int | None:
    """A port that actually binds.

    Port 5000 is a popular default and is often already taken -- by another copy
    of this board, or by anything else. Left alone that surfaces as a stack trace
    at startup, so the board looks for the next free port instead.

    A port named explicitly on the command line is never walked away from: if
    someone asked for 5057, silently serving 5058 would be worse than failing.
    That matters more here than on a desktop, because a server's port is written
    into a bookmark, a reverse proxy config, or a firewall rule.
    """
    bind_host = "" if host in ("0.0.0.0", "::") else host
    for offset in range(attempts if walk else 1):
        candidate = wanted + offset
        if candidate > 65535:
            break
        probe = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            # Deliberately no SO_REUSEADDR: on Windows it lets two sockets share
            # a port, which would make this check answer "free" for a port that
            # is anything but.
            probe.bind((bind_host, candidate))
        except OSError:
            continue
        else:
            return candidate
        finally:
            probe.close()
    return None


def browse_available() -> bool:
    """Whether a folder picker can be shown. Never, on a server."""
    return False


def browse_for_folder(title: str) -> str:
    """Present for API compatibility with the desktop build. Always empty."""
    return ""
