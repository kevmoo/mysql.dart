#!/usr/bin/env bash
set -euo pipefail

# Resolve repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

CONTAINER_NAME="mysql-dart-test"

# Clean up any existing container/symlink
docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
rm -f /tmp/mysql.sock

echo "Starting MySQL docker container with unix socket mount..."
docker run --name "${CONTAINER_NAME}" \
  -e MYSQL_DATABASE=testdb \
  -e MYSQL_USER=your_user \
  -e MYSQL_PASSWORD=your_password \
  -e MYSQL_RANDOM_ROOT_PASSWORD=yes \
  -v /tmp:/var/run/mysqld \
  -p 3306:3306 \
  -d mysql:8.0 --default-authentication-plugin=mysql_native_password

# Function to clean up on exit
cleanup() {
  # If the exit code is non-zero, print container logs for debugging
  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo "=== MySQL Container Logs ==="
    docker logs "${CONTAINER_NAME}" || true
    echo "============================"
  fi
  echo "Stopping and removing MySQL container..."
  docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
  rm -f /tmp/mysql.sock
}
trap cleanup EXIT

echo "Waiting for MySQL to start..."
# Wait up to 60 seconds
for i in {1..60}; do
  if docker exec "${CONTAINER_NAME}" mysqladmin ping -h 127.0.0.1 -u your_user -pyour_password --silent >/dev/null 2>&1; then
    echo "MySQL is ready over TCP!"
    sleep 2
    break
  fi
  if [ "$i" -eq 60 ]; then
    echo "MySQL failed to start over TCP in 60 seconds."
    exit 1
  fi
  sleep 1
done

# Create symlink for unix socket
ln -sf /tmp/mysqld.sock /tmp/mysql.sock

echo "Running TCP integration tests..."
echo "y" | dart test/mysql_client_tcp.dart

echo "Running Unix Socket integration tests..."
echo "y" | dart test/mysql_client_socket.dart

echo "Running Pool integration tests..."
echo "y" | dart test/pool_integration.dart

echo "All integration tests completed successfully!"
