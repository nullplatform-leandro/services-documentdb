#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# mongo_user.sh — creates, updates or drops the MongoDB user backing one link.
#
# Called by Terraform's null_resource provisioners in main.tf, NOT by a
# workflow step directly. Two invocations exist:
#
#   mongo_user.sh apply    — create the user, or update its roles if it exists
#   mongo_user.sh destroy  — drop the user, and the custom role if it is unused
#
# WHY THIS READS SECRETS MANAGER ITSELF
# A destroy-time provisioner may only reference `self`, never `var` — so the
# unlink path cannot be handed the master password as a Terraform variable.
# What it CAN carry is the secret's ARN, through the resource's `triggers`.
# So every invocation, including destroy, re-reads the secret with the AWS CLI.
# This is also why the permissions IAM policy needs secretsmanager:GetSecretValue
# and not just write access.
#
# Required environment (set by the provisioner's `environment` block):
#   AWS_REGION       — region the secret lives in
#   SECRET_ARN       — Secrets Manager ARN of the cluster master credentials
#   DOCDB_HOST       — cluster writer endpoint
#   DOCDB_PORT       — cluster port (27017)
#   DB_NAME          — database this link is scoped to
#   MONGO_USERNAME   — user to create/drop
#   ACCESS_LEVEL     — read | write | read-write
#   MONGO_PASSWORD   — required for "apply" only
# ---------------------------------------------------------------------------

ACTION="${1:-apply}"

for var in AWS_REGION SECRET_ARN DOCDB_HOST DOCDB_PORT DB_NAME MONGO_USERNAME ACCESS_LEVEL; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: $var is not set" >&2
    exit 1
  fi
done

if [ "$ACTION" = "apply" ] && [ -z "${MONGO_PASSWORD:-}" ]; then
  echo "ERROR: MONGO_PASSWORD is required for apply" >&2
  exit 1
fi

# --- TLS CA bundle ----------------------------------------------------------
# DocumentDB always presents a certificate signed by the Amazon RDS CA. Cache
# the bundle per pod so repeated link actions do not re-download it.

CA_BUNDLE="/tmp/np-docdb-global-bundle.pem"
if [ ! -s "$CA_BUNDLE" ]; then
  echo "Downloading Amazon RDS global CA bundle..."
  curl -fsSL "https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem" -o "$CA_BUNDLE"
fi

# --- Master credentials -----------------------------------------------------

echo "Reading master credentials from Secrets Manager..."
MASTER_CREDS=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --region "$AWS_REGION" \
  --query 'SecretString' \
  --output text)

MASTER_USER=$(echo "$MASTER_CREDS" | jq -r '.username')
MASTER_PASS=$(echo "$MASTER_CREDS" | jq -r '.password')

if [ -z "$MASTER_USER" ] || [ "$MASTER_USER" = "null" ]; then
  echo "ERROR: could not read username from secret $SECRET_ARN" >&2
  exit 1
fi

# Custom role backing the write-only access level, scoped to this database.
WRITE_ROLE="npwrite_${DB_NAME}"

# --- Build the JS payload ---------------------------------------------------
# Everything mongosh needs — including both passwords — travels in a single
# environment variable. Nothing sensitive is passed as an argument, so neither
# the master password nor the link password appears in the process list. That
# is also why the script authenticates with db.auth() inside the JS instead of
# mongosh --username/--password.

PAYLOAD=$(jq -n \
  --arg db          "$DB_NAME" \
  --arg user        "$MONGO_USERNAME" \
  --arg pass        "${MONGO_PASSWORD:-}" \
  --arg level       "$ACCESS_LEVEL" \
  --arg write_role  "$WRITE_ROLE" \
  --arg action      "$ACTION" \
  --arg master_user "$MASTER_USER" \
  --arg master_pass "$MASTER_PASS" \
  '{db: $db, user: $user, pass: $pass, level: $level, writeRole: $write_role,
    action: $action, masterUser: $master_user, masterPass: $master_pass}')


# --- Run it -----------------------------------------------------------------
# retryWrites=false is mandatory: DocumentDB does not implement retryable
# writes and every modern driver defaults them on.

URI="mongodb://${DOCDB_HOST}:${DOCDB_PORT}/?tls=true&replicaSet=rs0&readPreference=primary&retryWrites=false"

echo "Connecting to ${DOCDB_HOST}:${DOCDB_PORT} (action=${ACTION}, db=${DB_NAME}, user=${MONGO_USERNAME})..."

NP_LINK_PAYLOAD="$PAYLOAD" mongosh "$URI" \
  --tlsCAFile "$CA_BUNDLE" \
  --quiet \
  --file "$(dirname "${BASH_SOURCE[0]}")/mongo_user.js"

echo "mongo_user.sh ${ACTION} completed."
