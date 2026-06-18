#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="mysql-dart-test-pool-debug"
docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
rm -f /tmp/mysql.sock

docker run --name "${CONTAINER_NAME}" \
  -e MYSQL_DATABASE=testdb \
  -e MYSQL_USER=your_user \
  -e MYSQL_PASSWORD=your_password \
  -e MYSQL_RANDOM_ROOT_PASSWORD=yes \
  -v /tmp:/var/run/mysqld \
  -p 3306:3306 \
  -d mysql:8.0

cleanup() {
  echo "Cleaning up container..."
  docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
  rm -f /tmp/mysql.sock
}
trap cleanup EXIT

echo "Waiting for MySQL..."
for i in {1..60}; do
  if docker exec "${CONTAINER_NAME}" mysqladmin ping -h 127.0.0.1 -u your_user -pyour_password --silent >/dev/null 2>&1; then
    echo "MySQL is ready!"
    break
  fi
  sleep 1
done

ln -sf /tmp/mysqld.sock /tmp/mysql.sock

echo "Running tests..."
echo "y" | dart run --disable-service-auth-codes --enable-vm-service=8184 test/pool_integration.dart
echo "Done!"
