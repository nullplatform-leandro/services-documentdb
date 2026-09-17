// Executed by mongosh, driven by the sibling shell script. Its only input is
// NP_LINK_PAYLOAD, a JSON blob in the environment — which is what keeps both
// passwords out of the process list.
//
// It lives in its own file rather than inside a bash heredoc so it can be run,
// and tested, on its own against a real MongoDB.

const cfg = JSON.parse(process.env.NP_LINK_PAYLOAD);
const adminDb = db.getSiblingDB("admin");
const targetDb = db.getSiblingDB(cfg.db);

// Authenticate here rather than via mongosh --username/--password: arguments
// are world-readable in the process list, the environment of this one process
// is not.
adminDb.auth(cfg.masterUser, cfg.masterPass);

function userExists(name) {
  const r = adminDb.runCommand({usersInfo: {user: name, db: "admin"}});
  return (r.users || []).length > 0;
}

function roleExists(name, dbName) {
  const r = db.getSiblingDB(dbName).runCommand({rolesInfo: {role: name, db: dbName}});
  return (r.roles || []).length > 0;
}

// MongoDB has no write-only built-in role: readWrite always implies find. A
// genuine write level therefore needs a user-defined role. DocumentDB caps
// user-defined roles at 100 per cluster, so "read" and "read-write" stay on
// built-ins and never consume one.
function ensureWriteRole() {
  if (roleExists(cfg.writeRole, cfg.db)) return;
  targetDb.runCommand({
    createRole: cfg.writeRole,
    privileges: [{
      resource: {db: cfg.db, collection: ""},
      actions: ["insert", "update", "remove"]
    }],
    roles: []
  });
  print("Created role " + cfg.writeRole + " on " + cfg.db);
}

function dropWriteRoleIfUnused() {
  if (!roleExists(cfg.writeRole, cfg.db)) return;
  const users = adminDb.runCommand({usersInfo: 1}).users || [];
  const stillUsed = users.some(u =>
    (u.roles || []).some(r => r.role === cfg.writeRole && r.db === cfg.db));
  if (stillUsed) {
    print("Role " + cfg.writeRole + " still in use, keeping it");
    return;
  }
  targetDb.runCommand({dropRole: cfg.writeRole});
  print("Dropped unused role " + cfg.writeRole);
}

function rolesFor(level) {
  switch (level) {
    case "read":       return [{role: "read", db: cfg.db}];
    case "read-write": return [{role: "readWrite", db: cfg.db}];
    case "write":      ensureWriteRole();
                       return [{role: cfg.writeRole, db: cfg.db}];
    default: throw new Error("unknown access level: " + level);
  }
}

if (cfg.action === "apply") {
  const roles = rolesFor(cfg.level);
  if (userExists(cfg.user)) {
    // Re-apply is idempotent: refresh both roles and password so a rotated
    // password or a changed access level converges without dropping the user.
    adminDb.runCommand({updateUser: cfg.user, pwd: cfg.pass, roles: roles});
    print("Updated user " + cfg.user + " with level " + cfg.level);
  } else {
    adminDb.runCommand({createUser: cfg.user, pwd: cfg.pass, roles: roles});
    print("Created user " + cfg.user + " with level " + cfg.level);
  }
} else {
  if (userExists(cfg.user)) {
    adminDb.runCommand({dropUser: cfg.user});
    print("Dropped user " + cfg.user);
  } else {
    print("User " + cfg.user + " does not exist, nothing to drop");
  }
  dropWriteRoleIfUnused();
}
