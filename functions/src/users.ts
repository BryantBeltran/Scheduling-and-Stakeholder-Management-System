import {onCall} from "firebase-functions/v2/https";
import {onDocumentCreated, onDocumentDeleted} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import {
  HttpsError,
  isValidRole,
  getDefaultPermissions,
} from "./shared";

// =============================================================================
// USER TRIGGERS
// =============================================================================

/** When a new user document is created, send a welcome in-app notification. */
export const onUserCreated = onDocumentCreated(
  "users/{userId}",
  async (event) => {
    const userId = event.params.userId;
    const userData = event.data?.data();

    if (!userData) {
      logger.warn(`No data found for new user: ${userId}`);
      return;
    }

    logger.info(`New user created: ${userData.email}`, {userId});

    try {
      await admin.firestore().collection("notifications").add({
        userId,
        title: "Welcome to SSMS!",
        body: `Hi ${userData.displayName || "there"}! ` +
          "Welcome to the Scheduling & Stakeholder Management System.",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
        type: "welcome",
      });
      logger.info(`Welcome notification sent to user: ${userId}`);
    } catch (error) {
      logger.error(`Error sending welcome notification to ${userId}:`, error);
    }
  }
);

/** When a user document is deleted, clean up their notifications and unlink events. */
export const onUserDeleted = onDocumentDeleted(
  "users/{userId}",
  async (event) => {
    const userId = event.params.userId;
    logger.info(`User deleted: ${userId}`);

    try {
      const batch = admin.firestore().batch();

      const notificationsSnapshot = await admin
        .firestore()
        .collection("notifications")
        .where("userId", "==", userId)
        .get();
      notificationsSnapshot.docs.forEach((doc) => batch.delete(doc.ref));

      const eventsSnapshot = await admin
        .firestore()
        .collection("events")
        .where("ownerId", "==", userId)
        .get();
      eventsSnapshot.docs.forEach((doc) =>
        batch.update(doc.ref, {ownerId: null, ownerName: "Deleted User"})
      );

      await batch.commit();
      logger.info(`Cleaned up data for deleted user: ${userId}`);
    } catch (error) {
      logger.error(`Error cleaning up data for user ${userId}:`, error);
    }
  }
);

// =============================================================================
// USER CRUD
// =============================================================================

export const createUser = onCall(async (request) => {
  const {email, password, displayName, role} = request.data;

  if (!email || !password || !displayName) {
    throw new HttpsError(
      "invalid-argument",
      "Email, password, and display name are required."
    );
  }

  try {
    const userRecord = await admin.auth().createUser({email, password, displayName});

    await admin.firestore().collection("users").doc(userRecord.uid).set({
      id: userRecord.uid,
      email,
      displayName,
      photoUrl: null,
      role: role || "member",
      permissions: getDefaultPermissions(role || "member"),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      isActive: true,
    });

    logger.info(`User created successfully: ${email}`, {uid: userRecord.uid});
    return {uid: userRecord.uid};
  } catch (error) {
    logger.error("Error creating user:", error);
    throw new HttpsError("internal", "Error creating user.", error);
  }
});

export const getUser = onCall(async (request) => {
  const {uid} = request.data;

  if (!uid) {
    throw new HttpsError("invalid-argument", "User ID is required.");
  }

  try {
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    if (!userDoc.exists) {
      throw new HttpsError("not-found", "User not found.");
    }
    return {id: userDoc.id, ...userDoc.data()};
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("Error getting user:", error);
    throw new HttpsError("internal", "Error getting user.", error);
  }
});

/** Get all users. Requires manageUsers permission. */
export const getAllUsers = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  try {
    const callerDoc = await admin.firestore().collection("users").doc(callerUid).get();
    const callerData = callerDoc.data();
    const callerPermissions: string[] = callerData?.permissions || [];

    if (
      !callerPermissions.includes("manageUsers") &&
      !callerPermissions.includes("admin") &&
      callerData?.role !== "admin"
    ) {
      throw new HttpsError(
        "permission-denied",
        "You do not have permission to view all users."
      );
    }

    const usersSnapshot = await admin.firestore().collection("users").get();
    const users = usersSnapshot.docs.map((doc) => ({id: doc.id, ...doc.data()}));

    logger.info(`Users retrieved by admin: ${callerUid}`, {count: users.length});
    return users;
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("Error getting all users:", error);
    throw new HttpsError("internal", "Error getting all users.", error);
  }
});

/** Update user role. Admin only. */
export const updateUserRole = onCall(async (request) => {
  const {uid, role, permissions} = request.data;
  const callerUid = request.auth?.uid;

  if (!uid || !role) {
    throw new HttpsError("invalid-argument", "User ID and role are required.");
  }
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  try {
    const callerDoc = await admin.firestore().collection("users").doc(callerUid).get();
    const callerData = callerDoc.data();
    const callerPermissions: string[] = callerData?.permissions || [];

    if (
      !callerPermissions.includes("manageUsers") &&
      !callerPermissions.includes("admin") &&
      callerData?.role !== "admin"
    ) {
      throw new HttpsError(
        "permission-denied",
        "You do not have permission to change user roles."
      );
    }

    if (callerUid === uid) {
      throw new HttpsError("permission-denied", "You cannot change your own role.");
    }

    if (!isValidRole(role)) {
      throw new HttpsError("invalid-argument", `Invalid role: ${role}`);
    }

    const finalPermissions = permissions || getDefaultPermissions(role);

    await admin.firestore().collection("users").doc(uid).update({
      role,
      permissions: finalPermissions,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(`User role updated: ${uid} to ${role} by ${callerUid}`);
    return {success: true, role, permissions: finalPermissions};
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("Error updating user role:", error);
    throw new HttpsError("internal", "Error updating user role.", error);
  }
});

/** Activate or deactivate a user. Admin only. */
export const setUserActiveStatus = onCall(async (request) => {
  const {uid, isActive} = request.data;
  const callerUid = request.auth?.uid;

  if (!uid || typeof isActive !== "boolean") {
    throw new HttpsError(
      "invalid-argument",
      "User ID and isActive status are required."
    );
  }
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  try {
    const callerDoc = await admin.firestore().collection("users").doc(callerUid).get();
    const callerData = callerDoc.data();
    const callerPermissions: string[] = callerData?.permissions || [];

    if (
      !callerPermissions.includes("manageUsers") &&
      !callerPermissions.includes("admin") &&
      callerData?.role !== "admin"
    ) {
      throw new HttpsError(
        "permission-denied",
        "You do not have permission to activate/deactivate users."
      );
    }

    if (callerUid === uid) {
      throw new HttpsError(
        "permission-denied",
        "You cannot deactivate your own account."
      );
    }

    await admin.firestore().collection("users").doc(uid).update({
      isActive,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await admin.auth().updateUser(uid, {disabled: !isActive});

    logger.info(`User ${isActive ? "activated" : "deactivated"}: ${uid} by ${callerUid}`);
    return {success: true, isActive};
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("Error setting user active status:", error);
    throw new HttpsError("internal", "Error setting user active status.", error);
  }
});

export const updateUser = onCall(async (request) => {
  const {uid, displayName, role, permissions, isActive} = request.data;
  const callerUid = request.auth?.uid;

  if (!uid) {
    throw new HttpsError("invalid-argument", "User ID is required.");
  }
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  try {
    const isSelfUpdate = callerUid === uid;

    if (!isSelfUpdate) {
      const callerDoc = await admin.firestore().collection("users").doc(callerUid).get();
      const callerData = callerDoc.data();
      const callerPermissions: string[] = callerData?.permissions || [];

      if (
        !callerPermissions.includes("manageUsers") &&
        !callerPermissions.includes("admin") &&
        callerData?.role !== "admin"
      ) {
        throw new HttpsError(
          "permission-denied",
          "You do not have permission to update other users."
        );
      }
    }

    const updateData: Record<string, unknown> = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (isSelfUpdate) {
      if (displayName) updateData.displayName = displayName;
      if (role || permissions) {
        throw new HttpsError(
          "permission-denied",
          "You cannot change your own role or permissions."
        );
      }
    } else {
      if (displayName) updateData.displayName = displayName;
      if (role) {
        if (!isValidRole(role)) {
          throw new HttpsError("invalid-argument", `Invalid role: ${role}`);
        }
        updateData.role = role;
      }
      if (permissions) updateData.permissions = permissions;
      if (typeof isActive === "boolean") updateData.isActive = isActive;
    }

    await admin.firestore().collection("users").doc(uid).update(updateData);
    logger.info(`User updated: ${uid} by ${callerUid}`);
    return {success: true};
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("Error updating user:", error);
    throw new HttpsError("internal", "Error updating user.", error);
  }
});

export const deleteUser = onCall(async (request) => {
  const {uid} = request.data;

  if (!uid) {
    throw new HttpsError("invalid-argument", "User ID is required.");
  }

  try {
    await admin.auth().deleteUser(uid);
    await admin.firestore().collection("users").doc(uid).delete();
    logger.info(`User deleted: ${uid}`);
    return {success: true};
  } catch (error) {
    logger.error("Error deleting user:", error);
    throw new HttpsError("internal", "Error deleting user.", error);
  }
});

