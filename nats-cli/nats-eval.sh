#!/bin/bash

# Keep the eval loop alive when Ctrl+C is pressed.
trap '' SIGINT

if [ -z "$NATS_RLWRAP_ACTIVE" ] && command -v rlwrap >/dev/null 2>&1; then
    export NATS_RLWRAP_ACTIVE=1
    # No -S: we print the prompt ourselves so rlwrap won't inject it mid-output.
    exec rlwrap -a -pGreen -H /data/.nats_history "$0" "$@"
fi

echo "NATS CLI shell — connected to: ${NATS_URL}"
echo ""
echo "Commands are typed WITHOUT the 'nats' prefix. Examples:"
echo ""
echo "  pub <subject> <message>     Publish a message"
echo "  subscribe <subject>         Subscribe to a subject (Ctrl+C to stop)"
echo "  subscribe \">\"               Subscribe to all subjects"
echo "  stream ls                   List JetStream streams"
echo "  kv ls                       List Key-Value buckets"
echo "  rtt                         Round-trip time to server"
echo ""
echo "Type 'help' for full command list. Press Ctrl+C to stop a running command."
echo ""

run_nats() {
    local cmd="$1"
    local args

    # bash word-splitting via eval handles quoted args: pub topic "hello world" → 3 args
    if ! eval "args=($cmd)" 2>/dev/null; then
        echo "Error: invalid syntax (check unmatched quotes)"
        return 1
    fi

    # server/auth commands require a system account — not available on this server.
    case "${args[0]}" in
        server|auth)
            echo "Note: '${args[0]}' commands require a system account configured on the NATS server."
            echo "Use the monitoring dashboard at http://localhost:8000 for server stats."
            return 0
            ;;
    esac

    # Hint for commands that block until interrupted
    case "${args[0]}" in
        sub|subscribe|bench|reply)
            echo "(Blocking — press Ctrl+C to stop)"
            ;;
    esac

    # Run nats in a subshell with SIGINT reset to default.
    # This lets Ctrl+C interrupt the nats process without killing the eval loop.
    (trap - SIGINT; exec nats "${args[@]}")
    local rc=$?

    # Exit code 130 = killed by SIGINT (Ctrl+C)
    if [ $rc -eq 130 ]; then
        printf "\n(Stopped)\n"
    fi
}

while true; do
    printf "nats> "
    if ! read -r cmd; then
        break
    fi

    # Trim leading/trailing whitespace
    cmd="${cmd#"${cmd%%[![:space:]]*}"}"
    cmd="${cmd%"${cmd##*[![:space:]]}"}"

    [ -z "$cmd" ] && continue

    case "$cmd" in
        exit|quit)
            echo "Session kept alive. Close browser tab to disconnect."
            continue
            ;;
        clear|cls)
            printf '\033[2J\033[H'
            continue
            ;;
        help)
            nats help
            continue
            ;;
    esac

    run_nats "$cmd"

done
