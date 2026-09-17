#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# mongo_database.sh — materialises (or drops) the database this service owns.
#
#   mongo_database.sh apply    — ensure the database exists
#   mongo_database.sh destroy  — drop it, but only when DROP_ON_DELETE=true
#
# WHY "MATERIALISE" AND NOT "CREATE"
# MongoDB has no createDatabase: a database springs into existence on the first
# write and, until then, does not appear in listDatabases at all. A service
# whose create action did nothing would look identical to one that failed, and
# links against it would resolve to a database the cluster does not report. So
# create writes a sentinel collection, which is the cheapest real write there is.
#
# Like mongo_user.sh, this re-reads Secrets Manager on every invocation: the
# destroy-time provisioner can carry the secret ARN through `triggers` but never
# the password itself.
#
# Required environment:
#   AWS_REGION, SECRET_ARN, DOCDB_HOST, DOCDB_PORT, DB_NAME
#   DROP_ON_DELETE — "true" or "false", consulted by destroy only
# ---------------------------------------------------------------------------

ACTION="${1:-apply}"

for var in AWS_REGION SECRET_ARN DOCDB_HOST DOCDB_PORT DB_NAME; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: $var is not set" >&2
    exit 1
  fi
done

if [ "$ACTION" = "destroy" ] && [ "${DROP_ON_DELETE:-false}" != "true" ]; then
  echo "DROP_ON_DELETE is not true — leaving database '${DB_NAME}' and its data in place."
  echo "The service is being removed; the data is not. Set drop_on_delete on the"
  echo "service if you want deletion to take the database with it."
  exit 0
fi

CA_BUNDLE="/tmp/np-docdb-global-bundle.pem"
if [ ! -s "$CA_BUNDLE" ]; then
  echo "Downloading Amazon RDS global CA bundle..."
  curl -fsSL "https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem" -o "$CA_BUNDLE"
fi

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

# Both passwords travel in one environment variable so neither appears in the
# process list, and the JS authenticates with db.auth() rather than mongosh
# taking --username/--password as arguments.
PAYLOAD=$(jq -n \
  --arg db          "$DB_NAME" \
  --arg action      "$ACTION" \
  --arg master_user "$MASTER_USER" \
  --arg master_pass "$MASTER_PASS" \
  '{db: $db, action: $action, masterUser: $master_user, masterPass: $master_pass}')


URI="mongodb://${DOCDB_HOST}:${DOCDB_PORT}/?tls=true&replicaSet=rs0&readPreference=primary&retryWrites=false"

echo "Connecting to ${DOCDB_HOST}:${DOCDB_PORT} (action=${ACTION}, db=${DB_NAME})..."

NP_LINK_PAYLOAD="$PAYLOAD" mongosh "$URI" \
  --tlsCAFile "$CA_BUNDLE" \
  --quiet \
  --file "$(dirname "${BASH_SOURCE[0]}")/mongo_database.js"

echo "mongo_database.sh ${ACTION} completed."
