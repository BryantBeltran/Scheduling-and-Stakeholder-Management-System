/**
 * One-time script to seed the auditLogs Firestore collection.
 *
 * Usage (from the functions/ directory):
 *   node scripts/seed-audit-log.js path\to\serviceAccount.json
 *
 * Example:
 *   node scripts/seed-audit-log.js C:\Users\Bryant\serviceAccount.json
 */

const admin = require("firebase-admin");
const path = require("path");

const keyPath = process.argv[2];
if (!keyPath) {
  console.error("Usage: node scripts/seed-audit-log.js <path-to-serviceAccount.json>");
  console.error("Example: node scripts/seed-audit-log.js C:\\Users\\Bryant\\serviceAccount.json");
  process.exit(1);
}

const resolvedPath = path.resolve(keyPath);
console.log("Using service account:", resolvedPath);

admin.initializeApp({
  credential: admin.credential.cert(resolvedPath),
  projectId: "stakeholder-management-367ba",
});

const db = admin.firestore();

async function seed() {
  const existing = await db.collection("auditLogs").limit(1).get();
  if (!existing.empty) {
    console.log("auditLogs collection already has documents — nothing to seed.");
    process.exit(0);
  }

  await db.collection("auditLogs").add({
    actorId: "system",
    actorName: "System",
    action: "system_init",
    resourceType: "system",
    resourceId: null,
    description: "Audit log collection initialized.",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log("auditLogs collection seeded successfully.");
  process.exit(0);
}

seed().catch((err) => {
  console.error("Error seeding auditLogs:", err);
  process.exit(1);
});
