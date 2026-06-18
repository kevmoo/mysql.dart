#!/usr/bin/env bash
set -euo pipefail

# Resolve repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

CONTAINER_NAME="dolt-dart-test"

# Clean up any existing container
podman rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true

echo "Starting Dolt podman container..."
podman run --name "${CONTAINER_NAME}" \
  -e DOLT_ROOT_HOST=% \
  -p 3306:3306 \
  -d docker.io/dolthub/dolt-sql-server:latest

# Function to clean up on exit
cleanup() {
  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo "=== Dolt Container Logs ==="
    podman logs "${CONTAINER_NAME}" || true
    echo "============================"
  fi
  echo "Stopping and removing Dolt container..."
  podman rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Waiting for Dolt to start..."
# Wait up to 60 seconds
for i in {1..60}; do
  if podman exec "${CONTAINER_NAME}" dolt sql -q "SELECT 1" >/dev/null 2>&1; then
    echo "Dolt is ready!"
    sleep 2
    break
  fi
  if [ "$i" -eq 60 ]; then
    echo "Dolt failed to start in 60 seconds."
    exit 1
  fi
  sleep 1
done

# Initialize the testdb database and the user
echo "Initializing testdb database and user in Dolt..."
podman exec "${CONTAINER_NAME}" dolt sql -q "CREATE USER 'your_user'@'%' IDENTIFIED WITH mysql_native_password BY 'your_password'"
podman exec "${CONTAINER_NAME}" dolt sql -q "GRANT ALL PRIVILEGES ON *.* TO 'your_user'@'%' WITH GRANT OPTION"
podman exec "${CONTAINER_NAME}" dolt sql -q "CREATE DATABASE IF NOT EXISTS testdb"

# Expose MYSQL_SECURE=false so tests disable SSL
export MYSQL_SECURE="false"

echo "Running TCP integration tests against Dolt..."
echo "y" | dart test/mysql_client_tcp.dart

echo "Running Pool integration tests against Dolt..."
echo "y" | dart test/pool_integration.dart

echo "All Dolt integration tests completed successfully!"
