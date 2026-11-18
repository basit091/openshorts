#!/usr/bin/env bash
# Stop the OpenShorts containers. Jobs, clips, uploads and the model cache stay
# in their Docker volumes; a job that was running resumes on the next start.
# This does not stop the Codespace itself (see the guide).
set -euo pipefail

cd "$(dirname "$0")/../.."
docker compose -f docker-compose.yml -f deploy/codespaces/docker-compose.codespaces.yml \
  --profile renderer stop
echo "Containers stopped. Your files are kept. Start again with: bash deploy/codespaces/start.sh"
