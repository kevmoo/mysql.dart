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
rm -rf .dart_tool/coverage
mkdir -p .dart_tool/coverage

echo "Starting MySQL docker container with unix socket mount..."
docker run --name "${CONTAINER_NAME}" \
  -e MYSQL_DATABASE=testdb \
  -e MYSQL_USER=your_user \
  -e MYSQL_PASSWORD=your_password \
  -e MYSQL_RANDOM_ROOT_PASSWORD=yes \
  -v /tmp:/var/run/mysqld \
  -p 3306:3306 \
  -d mysql:8.0

# Function to clean up on exit
cleanup() {
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

# 1. Run unit tests and collect coverage
echo "Running unit tests under coverage..."
dart test --coverage=.dart_tool/coverage test/column_type_test.dart test/mysql_packet_test.dart

# Helper function to run a test file with coverage manually
run_manual_coverage() {
  local test_file=$1
  local port=$2
  local output_json=$3

  echo "Running ${test_file} under coverage on VM port ${port}..."
  # Start the test process in the background, piping "y" to it
  echo "y" | dart run --pause-isolates-on-exit --disable-service-auth-codes --enable-vm-service=${port} "${test_file}" &
  local test_pid=$!

  # Wait a moment for the VM service to start up
  sleep 2

  # Collect the coverage and resume the isolates so the test completes
  dart run coverage:collect_coverage --wait-paused --uri=http://127.0.0.1:${port}/ -o "${output_json}" --resume-isolates

  # Wait for the test process to exit
  wait ${test_pid}
}

# 2. Run integration tests under coverage
run_manual_coverage "test/mysql_client_tcp.dart" 8181 ".dart_tool/coverage/mysql_client_tcp.vm.json"
run_manual_coverage "test/mysql_client_socket.dart" 8182 ".dart_tool/coverage/mysql_client_socket.vm.json"
run_manual_coverage "test/pool_integration.dart" 8183 ".dart_tool/coverage/pool_integration.vm.json"

# 3. Format coverage into LCOV
echo "Formatting coverage reports into coverage/lcov.info..."
mkdir -p coverage
dart run coverage:format_coverage --lcov -i .dart_tool/coverage -o coverage/lcov.info --report-on=lib --check-ignore

echo "Coverage collection completed successfully!"
