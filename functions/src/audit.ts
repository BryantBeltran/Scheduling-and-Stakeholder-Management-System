import {onCall} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import {HttpsError, hasPermission, PERMISSIONS} from "./shared";

// =============================================================================
// AUDIT LOG RETRIEVAL (Admin only)
// =============================================================================

export const getAuditLogs = onCall(
  {enforceAppCheck: false},
  async (request) => {
    const callerUid = request.auth?.uid;
    logger.info("getAuditLogs called", {callerUid});
    if (!callerUid) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }

    // Debug: read user doc directly
    const userDoc = await admin.firestore()
      .collection("users").doc(callerUid).get();
    logger.info("User doc", {
      exists: userDoc.exists,
      role: userDoc.data()?.role,
      permissions: userDoc.data()?.permissions,
    });

    const canView = await hasPermission(
      callerUid, PERMISSIONS.admin
    );
    logger.info("hasPermission result", {canView});
    if (!canView) {
      throw new HttpsError(
        "permission-denied",
        "Only admins can view audit logs."
      );
    }

    const {limit: queryLimit, startAfter} = request.data || {};
    const pageSize = queryLimit || 50;

    try {
      let query = admin
        .firestore()
        .collection("auditLogs")
        .orderBy("createdAt", "desc")
        .limit(pageSize);

      if (startAfter) {
        const startDoc = await admin
          .firestore()
          .collection("auditLogs")
          .doc(startAfter)
          .get();
        if (startDoc.exists) {
          query = query.startAfter(startDoc);
        }
      }

      const snapshot = await query.get();
      return snapshot.docs.map((doc) => {
        const data = doc.data();
        return {
          id: doc.id,
          ...data,
          createdAt: data.createdAt?.toDate?.()?.toISOString() ||
            data.createdAt || null,
        };
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("internal", "Error fetching audit logs.", error);
    }
  }
);
