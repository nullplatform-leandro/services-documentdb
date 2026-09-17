#!/bin/bash
set -uo pipefail
URI="mongodb://np-mongo-test:27017/?retryWrites=false"
JS=/app/pkg/documentdb-cluster/permissions/mongo_user.js
DBJS=/app/pkg/documentdb-database/db_setup/mongo_database.js
PASS=0; FAIL=0
run() {  # run <action> <user> <level> [db]
  local action="$1" user="$2" level="$3" db="${4:-testdb}"
  NP_LINK_PAYLOAD=$(jq -nc --arg db "$db" --arg user "$user" --arg pass "p_${user}_secret" \
      --arg level "$level" --arg wr "npwrite_${db}" --arg action "$action" \
      --arg mu npmaster --arg mp testpass123 \
      '{db:$db,user:$user,pass:$pass,level:$level,writeRole:$wr,action:$action,masterUser:$mu,masterPass:$mp}') \
    mongosh "$URI" --quiet --file "$JS"
}
check() { # check <description> <expected> <actual>
  if [ "$2" = "$3" ]; then echo "  PASS  $1"; PASS=$((PASS+1));
  else echo "  FAIL  $1 (expected '$2', got '$3')"; FAIL=$((FAIL+1)); fi
}
q() { mongosh "$URI" --quiet -u npmaster -p testpass123 --authenticationDatabase admin --eval "$1"; }

echo "== 1. create a read user =="
run apply np_reader read
check "role is 'read' on testdb" "read:testdb" \
  "$(q 'const u=db.getSiblingDB("admin").getUser("np_reader"); print(u.roles.map(r=>r.role+":"+r.db).join(","))')"

echo "== 2. create a read-write user =="
run apply np_rw read-write
check "role is 'readWrite' on testdb" "readWrite:testdb" \
  "$(q 'const u=db.getSiblingDB("admin").getUser("np_rw"); print(u.roles.map(r=>r.role+":"+r.db).join(","))')"

echo "== 3. create a write-only user (custom role) =="
run apply np_writer write
check "role is the custom npwrite_testdb" "npwrite_testdb:testdb" \
  "$(q 'const u=db.getSiblingDB("admin").getUser("np_writer"); print(u.roles.map(r=>r.role+":"+r.db).join(","))')"
check "custom role grants insert,remove,update and NOT find" "insert,remove,update" \
  "$(q 'const r=db.getSiblingDB("testdb").getRole("npwrite_testdb",{showPrivileges:true}); print(r.privileges[0].actions.sort().join(","))')"

echo "== 4. re-apply is idempotent (updateUser path) =="
run apply np_reader read
check "still exactly one np_reader" "1" \
  "$(q 'print(db.getSiblingDB("admin").getUsers().users.filter(u=>u.user=="np_reader").length)')"

echo "== 5. changing access level converges without dropping the user =="
run apply np_reader read-write
check "np_reader is now readWrite" "readWrite:testdb" \
  "$(q 'const u=db.getSiblingDB("admin").getUser("np_reader"); print(u.roles.map(r=>r.role+":"+r.db).join(","))')"

echo "== 6. the custom role survives while another user still holds it =="
run apply np_writer2 write
run destroy np_writer2 write
check "npwrite_testdb still exists (np_writer holds it)" "npwrite_testdb" \
  "$(q 'const r=db.getSiblingDB("testdb").getRole("npwrite_testdb"); print(r ? r.role.split(".").pop() : "GONE")')"

echo "== 7. dropping the last holder reclaims the custom role =="
run destroy np_writer write
check "npwrite_testdb is gone" "GONE" \
  "$(q 'const r=db.getSiblingDB("testdb").getRole("npwrite_testdb"); print(r ? "STILL THERE" : "GONE")')"

echo "== 8. destroy is idempotent on a user that does not exist =="
run destroy np_never_existed read >/dev/null 2>&1
check "exit code is 0" "0" "$?"

echo "== 9. database materialisation (mongo_database.js) =="
NP_LINK_PAYLOAD=$(jq -nc '{db:"appdb_1",action:"apply",masterUser:"npmaster",masterPass:"testpass123"}') \
  mongosh "$URI" --quiet --file "$DBJS"
check "appdb_1 now listed by the server" "appdb_1" \
  "$(q 'print(db.adminCommand({listDatabases:1}).databases.map(d=>d.name).filter(n=>n=="appdb_1").join(""))')"
check "sentinel collection created" "_nullplatform" \
  "$(q 'print(db.getSiblingDB("appdb_1").getCollectionNames().join(","))')"

echo "== 10. re-applying an existing database leaves it alone =="
q 'db.getSiblingDB("appdb_1").real.insertOne({keep:true})' >/dev/null
NP_LINK_PAYLOAD=$(jq -nc '{db:"appdb_1",action:"apply",masterUser:"npmaster",masterPass:"testpass123"}') \
  mongosh "$URI" --quiet --file "$DBJS"
check "the pre-existing document survives" "1" \
  "$(q 'print(db.getSiblingDB("appdb_1").real.countDocuments({}))')"

echo; echo "RESULT: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ]
