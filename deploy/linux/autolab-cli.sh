#!/usr/bin/env bash
set -euo pipefail
# Injected by server-setup/scripts/04-services.sh (compose project directory).
AUTOLAB_APP_DIR='__AUTOLAB_APP_DIR__'
svc=autolab
if [[ "${1:-}" == node ]] || [[ "${1:-}" == client ]]; then
    svc=autolab-node
    shift
fi
case "${1:-}" in
    start)   sudo systemctl start "$svc" ;;
    stop)    sudo systemctl stop "$svc" ;;
    restart)
        sudo systemctl restart "$svc"
        if [[ "$svc" == autolab ]]; then
            # Force a fresh node registration after main stack restart.
            # This avoids waiting for any node-side retry/backoff window.
            sudo systemctl restart autolab-node || true
        fi
        ;;
    status)  sudo systemctl status "$svc" ;;
    logs)
        tail="${AUTOLAB_LOG_TAIL:-500}"
        boot="${AUTOLAB_JOURNAL_BOOTSTRAP:-120}"
        if [[ "$svc" == autolab ]]; then
            cd "$AUTOLAB_APP_DIR" || exit 1
            echo "---- journal: last $boot lines (systemd, git pull, docker build/compose driver) ----"
            sudo journalctl -u autolab -n "$boot" --no-pager --no-hostname || true
            if docker compose ps --status running -q 2>/dev/null | grep -q .; then
                echo "---- docker compose logs -f (containers; tail $tail) ----"
                exec docker compose logs -f --tail "$tail"
            else
                echo "---- no running compose services; following journal (Ctrl+C to stop) ----"
                exec sudo journalctl -u autolab -f --no-hostname -n "$boot"
            fi
        else
            echo "---- journal: last $boot lines (systemd, git pull, docker build, container driver) ----"
            sudo journalctl -u autolab-node -n "$boot" --no-pager --no-hostname || true
            if docker inspect -f '{{.State.Running}}' autolab-node 2>/dev/null | grep -qx true; then
                echo "---- docker logs -f autolab-node (tail $tail) ----"
                exec docker logs -f --tail "$tail" autolab-node
            else
                echo "---- container autolab-node not running; following journal ----"
                exec sudo journalctl -u autolab-node -f --no-hostname -n "$boot"
            fi
        fi
        ;;
    journal)
        lines="${AUTOLAB_JOURNAL_LINES:-200}"
        exec sudo journalctl -u "$svc" -f --no-hostname -n "$lines"
        ;;
    *)
        echo "Usage: autolab {start|stop|restart|status|logs|journal}"
        echo "       autolab node {start|stop|restart|status|logs|journal}"
        echo "       (alias: autolab client … — same as node)"
        echo ""
        echo "  (default)  Main Autolab Docker stack (systemd unit: autolab)"
        echo "  node       Hardware push node (systemd unit: autolab-node)"
        echo ""
        echo "  start      Start the service"
        echo "  stop       Stop the service"
        echo "  restart    Restart the service"
        echo "  status     Show service status"
        echo "  logs       journal bootstrap then compose/docker follow (or journal -f if not up); \$AUTOLAB_LOG_TAIL \$AUTOLAB_JOURNAL_BOOTSTRAP"
        echo "  journal    systemd journal for the unit (tail=\$AUTOLAB_JOURNAL_LINES, default 200)"
        ;;
esac
