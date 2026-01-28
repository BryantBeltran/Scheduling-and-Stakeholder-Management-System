import {setGlobalOptions} from "firebase-functions/v2";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {
  onDocumentCreated,
  onDocumentDeleted,
} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK
admin.initializeApp();

// For cost control, set maximum concurrent instances
setGlobalOptions({maxInstances: 10});


// User Management
/**
 * Trigger: When a new user document is created in Firestore
 * Action: Send welcome notification and log user creation
 */
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
      // Create welcome notification
      await admin.firestore().collection("notifications").add({
        userId: userId,
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

/**
 * Trigger: When a user document is deleted
 * Action: Clean up related data (events, notifications)
 */
export const onUserDeleted = onDocumentDeleted(
  "users/{userId}",
  async (event) => {
    const userId = event.params.userId;
    logger.info(`User deleted: ${userId}`);

    try {
      const batch = admin.firestore().batch();

      // Delete user's notifications
      const notificationsSnapshot = await admin
        .firestore()
        .collection("notifications")
        .where("userId", "==", userId)
        .get();

      notificationsSnapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });

      // Note: We don't delete events, just unlink the user
      // Events created by this user remain for historical purposes
      const eventsSnapshot = await admin
        .firestore()
        .collection("events")
        .where("organizerId", "==", userId)
        .get();

      eventsSnapshot.docs.forEach((doc) => {
        batch.update(doc.ref, {
          organizerId: null,
          organizerName: "Deleted User",
        });
      });

      await batch.commit();
      logger.info(`Cleaned up data for deleted user: ${userId}`);
    } catch (error) {
      logger.error(`Error cleaning up data for user ${userId}:`, error);
    }
  }
);

// User crud operations

export const createUser = onCall(async (request) => {
  const {email, password, displayName, role} = request.data;

  // Validate required fields
  if (!email || !password || !displayName) {
    throw new HttpsError(
      "invalid-argument",
      "Email, password, and display name are required."
    );
  }

  try {
    // Create Firebase Auth user
    const userRecord = await admin.auth().createUser({
      email,
      password,
      displayName,
    });

    // Create Firestore user document
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
    logger.error("Error getting user:", error);
    throw new HttpsError("internal", "Error getting user.", error);
  }
});

export const updateUser = onCall(async (request) => {
  const {uid, displayName, role, permissions} = request.data;

  if (!uid) {
    throw new HttpsError("invalid-argument", "User ID is required.");
  }

  try {
    const updateData: Record<string, unknown> = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (displayName) updateData.displayName = displayName;
    if (role) updateData.role = role;
    if (permissions) updateData.permissions = permissions;

    await admin.firestore().collection("users").doc(uid).update(updateData);

    logger.info(`User updated: ${uid}`);
    return {success: true};
  } catch (error) {
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
    // Delete from Firebase Auth
    await admin.auth().deleteUser(uid);

    // Delete from Firestore (triggers onUserDeleted for cleanup)
    await admin.firestore().collection("users").doc(uid).delete();

    logger.info(`User deleted: ${uid}`);
    return {success: true};
  } catch (error) {
    logger.error("Error deleting user:", error);
    throw new HttpsError("internal", "Error deleting user.", error);
  }
});

// Event management functions

/**
 * Trigger: When a new event is created
 * Action: Send notifications to assigned stakeholders
 */
export const onEventCreated = onDocumentCreated(
  "events/{eventId}",
  async (event) => {
    const eventId = event.params.eventId;
    const eventData = event.data?.data();

    if (!eventData) {
      return;
    }

    logger.info(`New event created: ${eventData.title}`, {eventId});

    try {
      // If there are assigned stakeholders, notify them
      if (eventData.stakeholderIds && eventData.stakeholderIds.length > 0) {
        const batch = admin.firestore().batch();

        for (const stakeholderId of eventData.stakeholderIds) {
          const notificationRef = admin
            .firestore()
            .collection("notifications")
            .doc();

          batch.set(notificationRef, {
            userId: stakeholderId,
            title: "New Event Assigned",
            body: `You've been assigned to: ${eventData.title}`,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            isRead: false,
            type: "event_assignment",
            eventId: eventId,
          });
        }

        await batch.commit();
        logger.info(`Notifications sent for event: ${eventId}`);
      }
    } catch (error) {
      logger.error(`Error sending event notifications: ${eventId}`, error);
    }
  }
);

export const createEvent = onCall(async (request) => {
  const {title, description, startTime, endTime, location, organizerId} =
    request.data;

  if (!title || !startTime || !organizerId) {
    throw new HttpsError(
      "invalid-argument",
      "Title, start time, and organizer ID are required."
    );
  }

  try {
    const eventRef = await admin.firestore().collection("events").add({
      title,
      description: description || "",
      startTime: admin.firestore.Timestamp.fromDate(new Date(startTime)),
      endTime: endTime ?
        admin.firestore.Timestamp.fromDate(new Date(endTime)) :
        null,
      location: location || "",
      organizerId,
      status: "scheduled",
      priority: "medium",
      stakeholderIds: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(`Event created: ${title}`, {id: eventRef.id});
    return {id: eventRef.id};
  } catch (error) {
    logger.error("Error creating event:", error);
    throw new HttpsError("internal", "Error creating event.", error);
  }
});

export const getEvent = onCall(async (request) => {
  const {id} = request.data;

  if (!id) {
    throw new HttpsError("invalid-argument", "Event ID is required.");
  }

  try {
    const eventDoc = await admin.firestore().collection("events").doc(id).get();
    if (!eventDoc.exists) {
      throw new HttpsError("not-found", "Event not found.");
    }
    return {id: eventDoc.id, ...eventDoc.data()};
  } catch (error) {
    logger.error("Error getting event:", error);
    throw new HttpsError("internal", "Error getting event.", error);
  }
});

export const updateEvent = onCall(async (request) => {
  const {id, title, description, startTime, endTime, location, status} =
    request.data;

  if (!id) {
    throw new HttpsError("invalid-argument", "Event ID is required.");
  }

  try {
    const updateData: Record<string, unknown> = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (title) updateData.title = title;
    if (description !== undefined) updateData.description = description;
    if (startTime) {
      updateData.startTime =
        admin.firestore.Timestamp.fromDate(new Date(startTime));
    }
    if (endTime) {
      updateData.endTime =
        admin.firestore.Timestamp.fromDate(new Date(endTime));
    }
    if (location !== undefined) updateData.location = location;
    if (status) updateData.status = status;

    await admin.firestore().collection("events").doc(id).update(updateData);

    logger.info(`Event updated: ${id}`);
    return {success: true};
  } catch (error) {
    logger.error("Error updating event:", error);
    throw new HttpsError("internal", "Error updating event.", error);
  }
});

export const deleteEvent = onCall(async (request) => {
  const {id} = request.data;

  if (!id) {
    throw new HttpsError("invalid-argument", "Event ID is required.");
  }

  try {
    await admin.firestore().collection("events").doc(id).delete();
    logger.info(`Event deleted: ${id}`);
    return {success: true};
  } catch (error) {
    logger.error("Error deleting event:", error);
    throw new HttpsError("internal", "Error deleting event.", error);
  }
});

// Stakeholder management functions

export const createStakeholder = onCall(async (request) => {
  const {name, email, phone, organization, type} = request.data;

  if (!name || !email) {
    throw new HttpsError(
      "invalid-argument",
      "Name and email are required."
    );
  }

  try {
    const stakeholderRef = await admin
      .firestore()
      .collection("stakeholders")
      .add({
        name,
        email,
        phone: phone || "",
        organization: organization || "",
        type: type || "internal",
        relationshipType: "attendee",
        participationStatus: "pending",
        eventIds: [],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    logger.info(`Stakeholder created: ${name}`, {id: stakeholderRef.id});
    return {id: stakeholderRef.id};
  } catch (error) {
    logger.error("Error creating stakeholder:", error);
    throw new HttpsError("internal", "Error creating stakeholder.", error);
  }
});

export const getStakeholder = onCall(async (request) => {
  const {id} = request.data;

  if (!id) {
    throw new HttpsError("invalid-argument", "Stakeholder ID is required.");
  }

  try {
    const stakeholderDoc = await admin
      .firestore()
      .collection("stakeholders")
      .doc(id)
      .get();
    if (!stakeholderDoc.exists) {
      throw new HttpsError("not-found", "Stakeholder not found.");
    }
    return {id: stakeholderDoc.id, ...stakeholderDoc.data()};
  } catch (error) {
    logger.error("Error getting stakeholder:", error);
    throw new HttpsError("internal", "Error getting stakeholder.", error);
  }
});

export const updateStakeholder = onCall(async (request) => {
  const {id, name, email, phone, organization, participationStatus} =
    request.data;

  if (!id) {
    throw new HttpsError("invalid-argument", "Stakeholder ID is required.");
  }

  try {
    const updateData: Record<string, unknown> = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (name) updateData.name = name;
    if (email) updateData.email = email;
    if (phone !== undefined) updateData.phone = phone;
    if (organization !== undefined) updateData.organization = organization;
    if (participationStatus) {
      updateData.participationStatus = participationStatus;
    }

    await admin
      .firestore()
      .collection("stakeholders")
      .doc(id)
      .update(updateData);

    logger.info(`Stakeholder updated: ${id}`);
    return {success: true};
  } catch (error) {
    logger.error("Error updating stakeholder:", error);
    throw new HttpsError("internal", "Error updating stakeholder.", error);
  }
});

export const deleteStakeholder = onCall(async (request) => {
  const {id} = request.data;

  if (!id) {
    throw new HttpsError("invalid-argument", "Stakeholder ID is required.");
  }

  try {
    // Remove stakeholder from all events
    const eventsSnapshot = await admin
      .firestore()
      .collection("events")
      .where("stakeholderIds", "array-contains", id)
      .get();

    const batch = admin.firestore().batch();
    eventsSnapshot.docs.forEach((doc) => {
      batch.update(doc.ref, {
        stakeholderIds: admin.firestore.FieldValue.arrayRemove(id),
      });
    });

    // Delete stakeholder document
    const stakeholderRef = admin
      .firestore()
      .collection("stakeholders")
      .doc(id);
    batch.delete(stakeholderRef);

    await batch.commit();

    logger.info(`Stakeholder deleted: ${id}`);
    return {success: true};
  } catch (error) {
    logger.error("Error deleting stakeholder:", error);
    throw new HttpsError("internal", "Error deleting stakeholder.", error);
  }
});

// Event stakeholder relationship management

export const addStakeholderToEvent = onCall(async (request) => {
  const {eventId, stakeholderId} = request.data;

  if (!eventId || !stakeholderId) {
    throw new HttpsError(
      "invalid-argument",
      "Event ID and Stakeholder ID are required."
    );
  }

  try {
    // Add stakeholder ID to event's stakeholderIds array
    await admin
      .firestore()
      .collection("events")
      .doc(eventId)
      .update({
        stakeholderIds: admin.firestore.FieldValue.arrayUnion(stakeholderId),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    // Add event ID to stakeholder's eventIds array
    await admin
      .firestore()
      .collection("stakeholders")
      .doc(stakeholderId)
      .update({
        eventIds: admin.firestore.FieldValue.arrayUnion(eventId),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    logger.info(`Stakeholder ${stakeholderId} added to event ${eventId}`);
    return {success: true};
  } catch (error) {
    logger.error("Error adding stakeholder to event:", error);
    throw new HttpsError(
      "internal",
      "Error adding stakeholder to event.",
      error
    );
  }
});

export const removeStakeholderFromEvent = onCall(async (request) => {
  const {eventId, stakeholderId} = request.data;

  if (!eventId || !stakeholderId) {
    throw new HttpsError(
      "invalid-argument",
      "Event ID and Stakeholder ID are required."
    );
  }

  try {
    // Remove stakeholder ID from event's stakeholderIds array
    await admin
      .firestore()
      .collection("events")
      .doc(eventId)
      .update({
        stakeholderIds: admin.firestore.FieldValue.arrayRemove(stakeholderId),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    // Remove event ID from stakeholder's eventIds array
    await admin
      .firestore()
      .collection("stakeholders")
      .doc(stakeholderId)
      .update({
        eventIds: admin.firestore.FieldValue.arrayRemove(eventId),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    logger.info(`Stakeholder ${stakeholderId} removed from event ${eventId}`);
    return {success: true};
  } catch (error) {
    logger.error("Error removing stakeholder from event:", error);
    throw new HttpsError(
      "internal",
      "Error removing stakeholder from event.",
      error
    );
  }
});

// Notification management

export const sendNotification = onCall(async (request) => {
  const {userId, title, body, type, eventId} = request.data;

  if (!userId || !title || !body) {
    throw new HttpsError(
      "invalid-argument",
      "User ID, title, and body are required."
    );
  }

  try {
    await admin.firestore().collection("notifications").add({
      userId,
      title,
      body,
      type: type || "general",
      eventId: eventId || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    });

    logger.info(`Notification sent to user: ${userId}`);
    return {success: true};
  } catch (error) {
    logger.error("Error sending notification:", error);
    throw new HttpsError("internal", "Error sending notification.", error);
  }
});

export const getNotifications = onCall(async (request) => {
  const {userId, limit} = request.data;

  if (!userId) {
    throw new HttpsError("invalid-argument", "User ID is required.");
  }

  try {
    let query = admin
      .firestore()
      .collection("notifications")
      .where("userId", "==", userId)
      .orderBy("createdAt", "desc");

    if (limit) {
      query = query.limit(limit);
    }

    const snapshot = await query.get();
    const notifications = snapshot.docs.map((doc) => {
      return {id: doc.id, ...doc.data()};
    });

    return notifications;
  } catch (error) {
    logger.error("Error getting notifications:", error);
    throw new HttpsError("internal", "Error getting notifications.", error);
  }
});

export const markNotificationAsRead = onCall(async (request) => {
  const {id} = request.data;

  if (!id) {
    throw new HttpsError("invalid-argument", "Notification ID is required.");
  }

  try {
    await admin.firestore().collection("notifications").doc(id).update({
      isRead: true,
      readAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(`Notification marked as read: ${id}`);
    return {success: true};
  } catch (error) {
    logger.error("Error marking notification as read:", error);
    throw new HttpsError(
      "internal",
      "Error marking notification as read.",
      error
    );
  }
});

// Helper functions

// Valid roles for the system
const VALID_ROLES = ["admin", "manager", "member", "viewer"] as const;
type UserRole = typeof VALID_ROLES[number];

// Permission definitions
const PERMISSIONS = {
  createEvent: "createEvent",
  editEvent: "editEvent",
  deleteEvent: "deleteEvent",
  viewEvent: "viewEvent",
  createStakeholder: "createStakeholder",
  editStakeholder: "editStakeholder",
  deleteStakeholder: "deleteStakeholder",
  viewStakeholder: "viewStakeholder",
  assignStakeholder: "assignStakeholder",
  manageUsers: "manageUsers",
  viewReports: "viewReports",
  editSettings: "editSettings",
} as const;

/**
 * Get default permissions for a given user role
 * @param {string} role - The user role to get permissions for
 * @return {string[]} Array of permission strings for the role
 */
function getDefaultPermissions(role: string): string[] {
  switch (role) {
  case "admin":
    return Object.values(PERMISSIONS);
  case "manager":
    return [
      PERMISSIONS.createEvent,
      PERMISSIONS.editEvent,
      PERMISSIONS.deleteEvent,
      PERMISSIONS.viewEvent,
      PERMISSIONS.createStakeholder,
      PERMISSIONS.editStakeholder,
      PERMISSIONS.deleteStakeholder,
      PERMISSIONS.viewStakeholder,
      PERMISSIONS.assignStakeholder,
      PERMISSIONS.viewReports,
    ];
  case "member":
    return [
      PERMISSIONS.createEvent,
      PERMISSIONS.editEvent,
      PERMISSIONS.viewEvent,
      PERMISSIONS.viewStakeholder,
      PERMISSIONS.assignStakeholder,
    ];
  case "viewer":
    return [
      PERMISSIONS.viewEvent,
      PERMISSIONS.viewStakeholder,
    ];
  default:
    return [];
  }
}

/**
 * Check if a user has a specific permission
 * @param {string} userId - The ID of the user to check permissions for
 * @param {string} permission - The permission to check
 * @return {Promise<boolean>} -
 * True if the user has the permission, false otherwise
 */
async function hasPermission(
  userId: string,
  permission: string
): Promise<boolean> {
  try {
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .get();

    if (!userDoc.exists) {
      return false;
    }

    const userData = userDoc.data();
    const permissions = userData?.permissions || [];
    return permissions.includes(permission);
  } catch (error) {
    logger.error(`Error checking permission for user ${userId}:`, error);
    return false;
  }
}

/**
 * Check if a role is valid
 * @param {string} role - The role to validate
 * @return {boolean} True if the role is valid, false otherwise
 */
function isValidRole(role: string): role is UserRole {
  return VALID_ROLES.includes(role as UserRole);
}

// Export helper functions for use
export {hasPermission, isValidRole, getDefaultPermissions, PERMISSIONS};
