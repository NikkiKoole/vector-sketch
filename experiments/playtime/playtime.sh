#!/bin/bash
# Helper script for managing the playtime LÖVE app
# Usage: ./playtime.sh [start|stop|restart|status|log|errors]

LOVE="/Applications/love114.app/Contents/MacOS/love"
DIR="$(cd "$(dirname "$0")" && pwd)"
PORT=8001
LOGFILE="$DIR/.playtime.log"

is_running() {
    curl -s --connect-timeout 1 localhost:$PORT/ping >/dev/null 2>&1
}

get_love_pid() {
    lsof -ti:$PORT 2>/dev/null
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
            get_love_pid | xargs kill 2>/dev/null
            sleep 1
        fi
        echo "stopped"
    else
        # Maybe a zombie holding the port
        local pid=$(get_love_pid)
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
    local pid=$(get_love_pid)
    if [ -n "$pid" ]; then
        kill $pid 2>/dev/null
        sleep 1
    fi

    # Start LÖVE with output captured to log file
    # Note: macOS buffers stdout/stderr from .app bundles until process exit,
    # so errors won't appear in the log until the process is killed.
    > "$LOGFILE"  # truncate log
    "$LOVE" "$DIR" --bridge >"$LOGFILE" 2>&1 &
    disown

    # Wait for bridge to come up
    for i in $(seq 1 10); do
        sleep 0.5
        if is_running; then
            echo "started (port $PORT)"
            return 0
        fi
    done

    # Bridge didn't respond. Two possibilities:
    # 1) App errored (showing blue error screen) — need to kill to flush stderr
    # 2) App is fine but waiting for start screen click
    #
    # Strategy: kill the process to flush stderr, check for errors.
    # If no error, restart it for the user.
    local lovepid=$(pgrep -f "love114" 2>/dev/null)
    if [ -n "$lovepid" ]; then
        kill "$lovepid" 2>/dev/null
        sleep 0.5
    fi

    # Check if log has error content
    if grep -q "^Error:" "$LOGFILE" 2>/dev/null; then
        echo "FAILED — error on startup:"
        echo ""
        grep -A 30 "^Error:" "$LOGFILE"
        return 1
    fi

    # No error — restart for the user
    "$LOVE" "$DIR" --bridge >>"$LOGFILE" 2>&1 &
    disown
    echo "started but bridge not responding yet"
}

do_log() {
    if [ -f "$LOGFILE" ]; then
        cat "$LOGFILE"
    else
        echo "no log file yet"
    fi
}

do_errors() {
    # Check bridge errors endpoint first (for runtime errors)
    if is_running; then
        curl -s "localhost:$PORT/errors" 2>/dev/null
        echo ""
    fi
    # Also show any startup errors from log
    if [ -f "$LOGFILE" ] && grep -q "Error:" "$LOGFILE" 2>/dev/null; then
        echo "Startup errors in log:"
        cat "$LOGFILE"
    fi
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
    log)     do_log ;;
    errors)  do_errors ;;
    *)       echo "Usage: $0 [start|stop|restart|status|log|errors]" ;;
esac
