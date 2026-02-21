#!/bin/bash
# Helper script for managing the playtime LÖVE app
# Usage: ./playtime.sh [start|stop|restart|status]

LOVE="/Applications/love114.app/Contents/MacOS/love"
DIR="$(cd "$(dirname "$0")" && pwd)"
PORT=8001

is_running() {
    curl -s --connect-timeout 1 localhost:$PORT/ping >/dev/null 2>&1
}

do_status() {
    if is_running; then
        echo "running (port $PORT)"
        curl -s localhost:$PORT/ping 2>/dev/null
        echo ""
    else
        echo "not running"
    fi
}

do_stop() {
    if is_running; then
        curl -s -X POST localhost:$PORT/quit >/dev/null 2>&1
        sleep 1
        # If still running, force kill
        if is_running; then
            lsof -ti:$PORT | xargs kill 2>/dev/null
            sleep 1
        fi
        echo "stopped"
    else
        # Maybe a zombie holding the port
        local pid=$(lsof -ti:$PORT 2>/dev/null)
        if [ -n "$pid" ]; then
            kill $pid 2>/dev/null
            sleep 1
            echo "killed stale process $pid"
        else
            echo "not running"
        fi
    fi
}

do_start() {
    if is_running; then
        echo "already running (port $PORT)"
        return 0
    fi

    # Clean up stale port holder
    local pid=$(lsof -ti:$PORT 2>/dev/null)
    if [ -n "$pid" ]; then
        kill $pid 2>/dev/null
        sleep 1
    fi

    "$LOVE" "$DIR" &
    disown

    # Wait for bridge to come up
    for i in $(seq 1 10); do
        sleep 0.5
        if is_running; then
            echo "started (port $PORT)"
            return 0
        fi
    done
    echo "started but bridge not responding yet"
}

do_restart() {
    do_stop
    do_start
}

case "${1:-status}" in
    start)   do_start ;;
    stop)    do_stop ;;
    restart) do_restart ;;
    status)  do_status ;;
    *)       echo "Usage: $0 [start|stop|restart|status]" ;;
esac
