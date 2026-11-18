#!/usr/bin/env bash
# Start OpenShorts in this Codespace (builds the images on the first run only).
#
#   bash deploy/codespaces/start.sh             start, building only what is missing
#   bash deploy/codespaces/start.sh --rebuild   rebuild the images (after pulling new code)
#   WITH_RENDERER=1 bash deploy/codespaces/start.sh   also start the optional Remotion renderer
set -euo pipefail

cd "$(dirname "$0")/../.."
COMPOSE=(docker compose -f docker-compose.yml -f deploy/codespaces/docker-compose.codespaces.yml)
PORT=8080

if [ "${WITH_RENDERER:-0}" = "1" ]; then
  COMPOSE+=(--profile renderer)
fi

echo "==> Waiting for Docker"
for _ in $(seq 1 60); do
  docker info >/dev/null 2>&1 && break
  sleep 2
done
if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker is not running in this Codespace."
  echo "Rebuild the container: Command Palette > Codespaces: Rebuild Container."
  exit 1
fi

free_gb=$(df -Pk / | awk 'NR==2 {print int($4 / 1048576)}')
echo "==> Free disk: ${free_gb} GB"
if [ "$free_gb" -lt 6 ]; then
  echo "WARNING: under 6 GB free. A build or a long video may fail."
  echo "Free space with: bash deploy/codespaces/status.sh clean"
fi

if [ -n "${GEMINI_API_KEY:-}" ]; then
  echo "==> GEMINI_API_KEY Codespaces secret: set (used as a server-side fallback)"
else
  echo "==> GEMINI_API_KEY Codespaces secret: not set (enter the key in the dashboard Settings page)"
fi

built=0
if [ "${1:-}" = "--rebuild" ] \
   || ! docker image inspect openshorts-backend >/dev/null 2>&1 \
   || ! docker image inspect openshorts-frontend >/dev/null 2>&1; then
  echo "==> Building images (first run takes about 15-25 minutes)"
  "${COMPOSE[@]}" build
  built=1
fi

echo "==> Starting containers"
"${COMPOSE[@]}" up -d

if [ "$built" = "1" ]; then
  # The build cache is several GB and counts against the Codespaces storage
  # quota; the finished images are all a restart needs.
  echo "==> Removing build cache to save storage"
  docker builder prune -af >/dev/null || true
  docker image prune -f >/dev/null || true
fi

echo "==> Waiting for the backend to answer through nginx"
ready=0
for _ in $(seq 1 90); do
  if curl -sf "http://127.0.0.1:${PORT}/health/ready" >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 2
done

if [ "$ready" != "1" ]; then
  echo "ERROR: the app did not become ready. Last backend log lines:"
  "${COMPOSE[@]}" logs --tail 40 backend || true
  exit 1
fi

if [ -n "${CODESPACE_NAME:-}" ]; then
  # Forwarded ports are private by default; make sure nobody switched it.
  gh codespace ports visibility "${PORT}:private" -c "$CODESPACE_NAME" >/dev/null 2>&1 \
    || echo "NOTE: could not confirm the port visibility automatically. In the PORTS tab, port ${PORT} must show Private."
  domain="${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
  echo
  echo "OpenShorts is running. Open this private URL in Safari (GitHub login required):"
  echo "https://${CODESPACE_NAME}-${PORT}.${domain}"
else
  echo
  echo "OpenShorts is running at http://127.0.0.1:${PORT}"
fi
