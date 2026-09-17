#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Exercises the MongoDB provisioning logic — mongo_user.js and
# mongo_database.js — against a real MongoDB, inside the real worker image.
#
# WHAT THIS DOES AND DOES NOT PROVE
# The user, role and database logic is plain MongoDB wire protocol, so a stock
# mongod exercises it faithfully: that is what is covered here, and it is the
# part with the most behaviour per line.
#
# It does NOT prove anything about DocumentDB itself — TLS with the RDS CA
# bundle, replicaSet=rs0 topology, retryWrites=false, or the 100 user-defined
# role cap. DocumentDB has no public endpoint and no local emulator, so those
# only get exercised by an agent running inside the VPC.
#
# Usage:  ./test/run.sh [image]
# ---------------------------------------------------------------------------

IMAGE="${1:-np-documentdb-cluster:local}"
NETWORK=np-docdb-test
MONGO=np-mongo-test
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"

cleanup() {
  docker rm -f "$MONGO" >/dev/null 2>&1 || true
  docker network rm "$NETWORK" >/dev/null 2>&1 || true
}
trap cleanup EXIT

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Building $IMAGE ..."
  ARCH=$(uname -m); case "$ARCH" in arm64|aarch64) TA=arm64;; *) TA=amd64;; esac
  docker build --build-arg TARGETARCH="$TA" -f "$REPO/Dockerfile.cluster" -t "$IMAGE" "$REPO"
fi

cleanup
docker network create "$NETWORK" >/dev/null
docker run -d --name "$MONGO" --network "$NETWORK" \
  -e MONGO_INITDB_ROOT_USERNAME=npmaster \
  -e MONGO_INITDB_ROOT_PASSWORD=testpass123 \
  mongo:7 >/dev/null

echo "Waiting for mongod to finish initialising its root user..."
for _ in $(seq 1 60); do
  if docker exec "$MONGO" mongosh --quiet -u npmaster -p testpass123 \
       --authenticationDatabase admin --eval 'db.version()' >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

docker run --rm -i --network "$NETWORK" --entrypoint bash "$IMAGE" -s < "$HERE/mongo-logic-test.sh"
