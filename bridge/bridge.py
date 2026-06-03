#!/usr/bin/env python3
"""
hermes-bridge — WebSocket proxy for the Hermes iOS companion app.

Architecture:
    iPhone  →  ngrok tunnel  →  127.0.0.1:9120 (this bridge)  →  127.0.0.1:9119 (Hermes)

The bridge lives on localhost so ngrok has no 403 interstitial.
It auto-fetches the Hermes session token from the running dashboard,
so no manual token management is needed.

Usage:
    python3 bridge.py                        # default ports
    python3 bridge.py --port 9120 --hermes-port 9119
"""

import asyncio
import logging
import re
import sys
import urllib.parse
import urllib.request
from argparse import ArgumentParser

# ── Dependency bootstrap ─────────────────────────────────────────────────────
try:
    import websockets
    import websockets.server
except ImportError:
    import subprocess
    print("Installing websockets...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "websockets>=12"])
    import websockets
    import websockets.server

LOG = logging.getLogger("hermes-bridge")

# ── Token discovery ──────────────────────────────────────────────────────────

def fetch_token(hermes_base: str) -> str | None:
    """Extract __HERMES_SESSION_TOKEN__ injected into the Hermes dashboard HTML."""
    try:
        req = urllib.request.Request(
            f"{hermes_base}/",
            headers={"User-Agent": "hermes-bridge/1.0"},
        )
        with urllib.request.urlopen(req, timeout=5) as resp:
            html = resp.read().decode("utf-8", errors="ignore")

        # Matches both:  __HERMES_SESSION_TOKEN__ = "abc"
        #           and: __HERMES_SESSION_TOKEN__:"abc"
        m = re.search(
            r'__HERMES_SESSION_TOKEN__["\']?\s*[:=]\s*["\']([^"\']+)["\']',
            html,
        )
        if m:
            return m.group(1)
        LOG.warning("Token not found in Hermes HTML — is the dashboard running?")
    except Exception as exc:
        LOG.error("Cannot reach Hermes at %s: %s", hermes_base, exc)
    return None


# ── Per-connection bridge ────────────────────────────────────────────────────

async def bridge_connection(client_ws, hermes_base: str) -> None:
    """Proxy one iOS client ↔ Hermes WebSocket session."""
    peer = getattr(getattr(client_ws, "remote_address", None), "__str__", lambda: "?")()

    token = fetch_token(hermes_base)
    if not token:
        LOG.error("No Hermes token — closing client %s", peer)
        await client_ws.close(1011, "Hermes not reachable")
        return

    hermes_port = urllib.parse.urlparse(hermes_base).port or 9119
    hermes_url = (
        f"ws://127.0.0.1:{hermes_port}/api/ws"
        f"?token={urllib.parse.quote(token, safe='')}"
    )

    LOG.info("+ client %s", peer)

    try:
        async with websockets.connect(hermes_url) as hermes_ws:

            async def pump(src, dst, tag: str) -> None:
                try:
                    async for msg in src:
                        await dst.send(msg)
                except websockets.ConnectionClosed:
                    pass
                except Exception as exc:
                    LOG.debug("%s pump error: %s", tag, exc)

            # Run both directions concurrently; stop when either side closes.
            done, pending = await asyncio.wait(
                [
                    asyncio.ensure_future(pump(client_ws, hermes_ws, "c→h")),
                    asyncio.ensure_future(pump(hermes_ws, client_ws, "h→c")),
                ],
                return_when=asyncio.FIRST_COMPLETED,
            )
            for t in pending:
                t.cancel()

    except Exception as exc:
        LOG.warning("Bridge error for %s: %s", peer, exc)
    finally:
        LOG.info("- client %s", peer)


# ── Server ───────────────────────────────────────────────────────────────────

async def serve(listen_port: int, hermes_base: str) -> None:
    handler = lambda ws: bridge_connection(ws, hermes_base)

    async with websockets.serve(handler, "127.0.0.1", listen_port):
        LOG.info("━" * 52)
        LOG.info("  hermes-bridge running on 127.0.0.1:%d", listen_port)
        LOG.info("  Hermes: %s", hermes_base)
        LOG.info("━" * 52)
        LOG.info("  Next: ngrok http %d", listen_port)
        LOG.info("  Then connect the iOS app to the ngrok URL")
        LOG.info("  Port: 443  |  WSS: ON")
        LOG.info("━" * 52)
        await asyncio.Future()  # run forever


def main() -> None:
    ap = ArgumentParser(description="Hermes WebSocket bridge for iOS companion app")
    ap.add_argument("--port", type=int, default=9120,
                    help="Port to listen on (default: 9120)")
    ap.add_argument("--hermes-port", type=int, default=9119,
                    help="Hermes dashboard port (default: 9119)")
    args = ap.parse_args()

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s  %(message)s",
        datefmt="%H:%M:%S",
    )

    hermes_base = f"http://127.0.0.1:{args.hermes_port}"

    LOG.info("Checking Hermes at %s ...", hermes_base)
    token = fetch_token(hermes_base)
    if not token:
        LOG.error("Start Hermes first:  hermes dashboard")
        sys.exit(1)

    LOG.info("✓ Hermes token found (%s...)", token[:8])

    try:
        asyncio.run(serve(args.port, hermes_base))
    except KeyboardInterrupt:
        LOG.info("Stopped.")


if __name__ == "__main__":
    main()
