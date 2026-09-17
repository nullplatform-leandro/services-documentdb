// Executed by mongosh, driven by the sibling shell script. Its only input is
// NP_LINK_PAYLOAD, a JSON blob in the environment — which is what keeps both
// passwords out of the process list.
//
// It lives in its own file rather than inside a bash heredoc so it can be run,
// and tested, on its own against a real MongoDB.

const cfg = JSON.parse(process.env.NP_LINK_PAYLOAD);
const adminDb = db.getSiblingDB("admin");
const targetDb = db.getSiblingDB(cfg.db);

adminDb.auth(cfg.masterUser, cfg.masterPass);

const SENTINEL = "_nullplatform";

if (cfg.action === "apply") {
  const existing = targetDb.getCollectionNames();
  if (existing.length > 0) {
    print("Database " + cfg.db + " already exists with " + existing.length + " collection(s)");
  } else {
    targetDb.createCollection(SENTINEL);
    print("Created database " + cfg.db + " (materialised via collection " + SENTINEL + ")");
  }
} else {
  targetDb.dropDatabase();
  print("Dropped database " + cfg.db);
}
