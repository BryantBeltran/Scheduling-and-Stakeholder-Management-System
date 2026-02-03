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

/**
 * Get all users (Admin only)
 * Used by the User Management screen to list all users
 */
export const getAllUsers = onCall(async (request) => {
  const callerUid = request.auth?.uid;

  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  try {
    // Verify caller has manageUsers permission
    const callerDoc = await admin
      .firestore().collection("users").doc(callerUid).get();
    const callerData = callerDoc.data();
    const callerPermissions = callerData?.permissions || [];

    if (!callerPermissions.includes("manageUsers") &&
        !callerPermissions.includes("admin") &&
        callerData?.role !== "admin") {
      throw new HttpsError(
        "permission-denied",
        "You do not have permission to view all users."
      );
    }

    const usersSnapshot = await admin.firestore().collection("users").get();
    const users = usersSnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    logger.info(
      `Users retrieved by admin: ${callerUid}`, {count: users.length}
    );
    return users;
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("Error getting all users:", error);
    throw new HttpsError("internal", "Error getting all users.", error);
  }
});

/**
 * Update user role (Admin only)
 * Secure endpoint for changing user roles and permissions
 */
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
    // Verify caller has manageUsers permission
    const callerDoc = await admin
      .firestore().collection("users").doc(callerUid).get();
    const callerData = callerDoc.data();
    const callerPermissions = callerData?.permissions || [];

    if (!callerPermissions.includes("manageUsers") &&
        !callerPermissions.includes("admin") &&
        callerData?.role !== "admin") {
      throw new HttpsError(
        "permission-denied",
        "You do not have permission to change user roles."
      );
    }

    // Prevent self role change
    if (callerUid === uid) {
      throw new HttpsError(
        "permission-denied",
        "You cannot change your own role."
      );
    }

    // Validate role
    if (!isValidRole(role)) {
      throw new HttpsError("invalid-argument", `Invalid role: ${role}`);
    }

    // Use provided permissions or default for role
    const finalPermissions = permissions || getDefaultPermissions(role);

    await admin.firestore().collection("users").doc(uid).update({
      role: role,
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

/**
 * Activate or deactivate a user (Admin only)
 */
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
    // Verify caller has manageUsers permission
    const callerDoc = await admin
      .firestore().collection("users").doc(callerUid).get();
    const callerData = callerDoc.data();
    const callerPermissions = callerData?.permissions || [];

    if (!callerPermissions.includes("manageUsers") &&
        !callerPermissions.includes("admin") &&
        callerData?.role !== "admin") {
      throw new HttpsError(
        "permission-denied",
        "You do not have permission to activate/deactivate users."
      );
    }

    // Prevent self deactivation
    if (callerUid === uid) {
      throw new HttpsError(
        "permission-denied",
        "You cannot deactivate your own account."
      );
    }

    await admin.firestore().collection("users").doc(uid).update({
      isActive: isActive,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // If deactivating, also disable in Firebase Auth
    if (!isActive) {
      await admin.auth().updateUser(uid, {disabled: true});
    } else {
      await admin.auth().updateUser(uid, {disabled: false});
    }

    logger.info(
      `User ${isActive ? "activated" : "deactivated"}: ${uid} by ${callerUid}`
    );
    return {success: true, isActive};
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("Error setting user active status:", error);
    throw new HttpsError(
      "internal", "Error setting user active status.", error
    );
  }
});

export const updateUser = onCall(async (request) => {
  const {uid, displayName, role, permissions, isActive} = request.data;
  const callerUid = request.auth?.uid;

  if (!uid) {
    throw new HttpsError("invalid-argument", "User ID is required.");
  }

  // Check if caller is authenticated
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  try {
    // Check if caller has permission to update other users
    const isSelfUpdate = callerUid === uid;

    if (!isSelfUpdate) {
      // Verify caller has manageUsers permission
      const callerDoc = await admin
        .firestore().collection("users").doc(callerUid).get();
      const callerData = callerDoc.data();
      const callerPermissions = callerData?.permissions || [];

      if (!callerPermissions.includes("manageUsers") &&
          !callerPermissions.includes("admin") &&
          callerData?.role !== "admin") {
        throw new HttpsError(
          "permission-denied",
          "You do not have permission to update other users."
        );
      }
    }

    const updateData: Record<string, unknown> = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    // Self-update restrictions
    if (isSelfUpdate) {
      // Users can only update their own displayName
      if (displayName) updateData.displayName = displayName;
      // Cannot change own role or permissions
      if (role || permissions) {
        throw new HttpsError(
          "permission-denied",
          "You cannot change your own role or permissions."
        );
      }
    } else {
      // Admin updates
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
        linkedUserId: null,
        inviteStatus: "notInvited",
        invitedAt: null,
        inviteToken: null,
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

// Stakeholder invitation functions

export const inviteStakeholder = onCall(async (request) => {
  const {stakeholderId, defaultRole} = request.data;

  if (!stakeholderId) {
    throw new HttpsError(
      "invalid-argument",
      "Stakeholder ID is required."
    );
  }

  try {
    const stakeholderRef = admin
      .firestore()
      .collection("stakeholders")
      .doc(stakeholderId);
    const stakeholderDoc = await stakeholderRef.get();

    if (!stakeholderDoc.exists) {
      throw new HttpsError("not-found", "Stakeholder not found.");
    }

    const stakeholderData = stakeholderDoc.data();
    if (!stakeholderData) {
      throw new HttpsError("internal", "Stakeholder data is empty.");
    }

    // Generate invite token
    const inviteToken = admin.firestore().collection("_temp").doc().id;

    // Update stakeholder with invite info
    await stakeholderRef.update({
      inviteStatus: "pending",
      invitedAt: admin.firestore.FieldValue.serverTimestamp(),
      inviteToken: inviteToken,
      defaultRole: defaultRole || "member",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Store invite in invites collection for lookup during signup
    await admin.firestore().collection("invites").doc(inviteToken).set({
      stakeholderId: stakeholderId,
      email: stakeholderData.email,
      defaultRole: defaultRole || "member",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) // 7 days
      ),
      used: false,
    });

    logger.info(`Stakeholder invited: ${stakeholderId}`, {
      email: stakeholderData.email,
      token: inviteToken,
    });

    // TODO: Send email with invite link
    // For now, return the token for manual sharing
    return {
      success: true,
      inviteToken: inviteToken,
      email: stakeholderData.email,
    };
  } catch (error) {
    logger.error("Error inviting stakeholder:", error);
    throw new HttpsError("internal", "Error inviting stakeholder.", error);
  }
});

export const validateInviteToken = onCall(async (request) => {
  const {token} = request.data;

  if (!token) {
    throw new HttpsError("invalid-argument", "Invite token is required.");
  }

  try {
    const inviteDoc = await admin
      .firestore()
      .collection("invites")
      .doc(token)
      .get();

    if (!inviteDoc.exists) {
      return {valid: false, reason: "Token not found"};
    }

    const inviteData = inviteDoc.data();
    if (!inviteData) {
      return {valid: false, reason: "Invalid invite data"};
    }

    if (inviteData.used) {
      return {valid: false, reason: "Token already used"};
    }

    const expiresAt = inviteData.expiresAt?.toDate();
    if (expiresAt && new Date() > expiresAt) {
      return {valid: false, reason: "Token expired"};
    }

    return {
      valid: true,
      email: inviteData.email,
      stakeholderId: inviteData.stakeholderId,
      defaultRole: inviteData.defaultRole,
    };
  } catch (error) {
    logger.error("Error validating invite token:", error);
    throw new HttpsError("internal", "Error validating invite token.", error);
  }
});

export const linkUserToStakeholder = onCall(async (request) => {
  const {userId, stakeholderId, inviteToken} = request.data;

  if (!userId || !stakeholderId) {
    throw new HttpsError(
      "invalid-argument",
      "User ID and Stakeholder ID are required."
    );
  }

  try {
    const batch = admin.firestore().batch();

    // Get invite data for default role
    let defaultRole = "member";
    if (inviteToken) {
      const inviteDoc = await admin
        .firestore()
        .collection("invites")
        .doc(inviteToken)
        .get();
      if (inviteDoc.exists) {
        const inviteData = inviteDoc.data();
        defaultRole = inviteData?.defaultRole || "member";

        // Mark invite as used
        batch.update(inviteDoc.ref, {used: true});
      }
    }

    // Update user with stakeholder link
    const userRef = admin.firestore().collection("users").doc(userId);
    batch.update(userRef, {
      stakeholderId: stakeholderId,
      role: defaultRole,
      permissions: getDefaultPermissions(defaultRole),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Update stakeholder with user link
    const stakeholderRef = admin
      .firestore()
      .collection("stakeholders")
      .doc(stakeholderId);
    batch.update(stakeholderRef, {
      linkedUserId: userId,
      inviteStatus: "accepted",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await batch.commit();

    logger.info(`User ${userId} linked to stakeholder ${stakeholderId}`);
    return {success: true, role: defaultRole};
  } catch (error) {
    logger.error("Error linking user to stakeholder:", error);
    throw new HttpsError(
      "internal",
      "Error linking user to stakeholder.",
      error
    );
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

// Permission definitions - must match Flutter Permission enum
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
  inviteStakeholder: "inviteStakeholder",
  manageUsers: "manageUsers",
  viewReports: "viewReports",
  editSettings: "editSettings",
  admin: "admin",
  root: "root",
} as const;

/**
 * Get default permissions for a given user role
 * Must match Flutter UserModel.getDefaultPermissions()
 * @param {string} role - The user role to get permissions for
 * @return {string[]} Array of permission strings for the role
 */
function getDefaultPermissions(role: string): string[] {
  switch (role) {
  case "admin":
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
      PERMISSIONS.inviteStakeholder,
      PERMISSIONS.manageUsers,
      PERMISSIONS.viewReports,
      PERMISSIONS.editSettings,
      PERMISSIONS.admin,
    ];
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
      PERMISSIONS.inviteStakeholder,
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
    return [
      PERMISSIONS.viewEvent,
      PERMISSIONS.viewStakeholder,
    ];
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
