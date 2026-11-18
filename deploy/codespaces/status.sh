#!/usr/bin/env bash
# Health, resources and logs of the OpenShorts containers in this Codespace.
#
#   bash deploy/codespaces/status.sh         containers, health, memory, disk
#   bash deploy/codespaces/status.sh logs    follow the backend log (Ctrl+C to leave);
#                                            the output also keeps the Codespace from idling out
#   bash deploy/codespaces/status.sh clean   remove build cache and unused images (keeps your files)
set -uo pipefail

cd "$(dirname "$0")/../.."
COMPOSE=(docker compose -f docker-compose.yml -f deploy/codespaces/docker-compose.codespaces.yml --profile renderer)
PORT=8080

case "${1:-}" in
  logs)
    exec "${COMPOSE[@]}" logs -f --tail 100 backend
    ;;
  clean)
    docker builder prune -af
    docker image prune -f
    docker system df
    exit 0
    ;;
esac

echo "==> Containers"
"${COMPOSE[@]}" ps

echo
echo "==> Health"
if curl -sf "http://127.0.0.1:${PORT}/health/ready" >/dev/null 2>&1; then
  echo "backend via nginx: ready"
else
  echo "backend via nginx: NOT ready (run: bash deploy/codespaces/start.sh)"
fi
if curl -sf "http://127.0.0.1:${PORT}/" -o /dev/null 2>&1; then
  echo "dashboard: serving"
else
  echo "dashboard: NOT serving"
fi

echo
echo "==> Memory"
free -h | head -2
docker stats --no-stream --format '{{.Name}}: {{.MemUsage}} CPU {{.CPUPerc}}' 2>/dev/null

echo
echo "==> Disk"
df -h / | tail -1
docker system df 2>/dev/null

if [ -n "${CODESPACE_NAME:-}" ]; then
  echo
  echo "==> Private URL"
  echo "https://${CODESPACE_NAME}-${PORT}.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
fi
