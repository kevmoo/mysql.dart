#!/usr/bin/env bash
set -euo pipefail

# Resolve repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

CONTAINER_NAME="mysql-dart-test-pool-debug"

# Clean up any existing container/symlink
podman rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
podman unshare rm -rf .tmp_mysql >/dev/null 2>&1 || true
rm -f /tmp/mysql.sock

# Create localized directory for Unix sockets
mkdir -p .tmp_mysql

echo "Starting MySQL podman container with unix socket mount..."
podman run --name "${CONTAINER_NAME}" \
  -e MYSQL_DATABASE=testdb \
  -e MYSQL_USER=your_user \
  -e MYSQL_PASSWORD=your_password \
  -e MYSQL_RANDOM_ROOT_PASSWORD=yes \
  -v "$(pwd)/.tmp_mysql:/var/run/mysqld:Z,U" \
  -p 3306:3306 \
  -d docker.io/library/mysql:8.4.9

# Function to clean up on exit
cleanup() {
  echo "Cleaning up container..."
  podman rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
  podman unshare rm -rf .tmp_mysql >/dev/null 2>&1 || true
  rm -f /tmp/mysql.sock
}
trap cleanup EXIT

echo "Waiting for MySQL to start..."
# Wait up to 60 seconds
for i in {1..60}; do
  if podman exec "${CONTAINER_NAME}" mysqladmin ping -h 127.0.0.1 -u your_user -pyour_password --silent >/dev/null 2>&1; then
    echo "MySQL is ready!"
    break
  fi
  sleep 1
done

# Create symlink for unix socket
ln -sf "$(pwd)/.tmp_mysql/mysqld.sock" /tmp/mysql.sock

echo "Running tests..."
echo "y" | dart run --disable-service-auth-codes --enable-vm-service=8184 test/pool_integration.dart
echo "Done!"
