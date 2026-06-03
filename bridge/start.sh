#!/usr/bin/env bash
# start.sh — Start the Hermes iOS bridge + ngrok tunnel
#
# Usage:
#   ./start.sh              # bridge on 9120, ngrok on same port
#   ./start.sh 9121         # custom bridge port

set -e

BRIDGE_PORT="${1:-9120}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  hermes-bridge + ngrok"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Resolve Python — prefer Hermes's own venv, fall back to system
PYTHON=""
for candidate in \
    "$HOME/.hermes/venv/bin/python3" \
    "$HOME/.local/share/hermes/venv/bin/python3" \
    "$(command -v python3 2>/dev/null)" \
    "$(command -v python 2>/dev/null)"; do
    if [ -x "$candidate" ] 2>/dev/null; then
        PYTHON="$candidate"
        break
    fi
done

if [ -z "$PYTHON" ]; then
    echo "ERROR: Python not found"
    exit 1
fi

echo "Python: $PYTHON"

# Start bridge in background
"$PYTHON" "$SCRIPT_DIR/bridge.py" --port "$BRIDGE_PORT" &
BRIDGE_PID=$!

# Give it a moment to start
sleep 1

# Check bridge is up
if ! kill -0 "$BRIDGE_PID" 2>/dev/null; then
    echo "ERROR: Bridge failed to start. Is hermes dashboard running?"
    exit 1
fi

echo ""

# Start ngrok if available
if command -v ngrok &>/dev/null; then
    echo "Starting ngrok on port $BRIDGE_PORT ..."
    ngrok http "$BRIDGE_PORT"
else
    echo "ngrok not found. Install from https://ngrok.com/download"
    echo "Then run: ngrok http $BRIDGE_PORT"
    echo ""
    echo "Bridge is running on 127.0.0.1:$BRIDGE_PORT — waiting..."
    wait "$BRIDGE_PID"
fi

# Cleanup
kill "$BRIDGE_PID" 2>/dev/null || true
