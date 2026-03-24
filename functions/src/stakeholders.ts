import {onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import {
  HttpsError,
  hasPermission,
  getDefaultPermissions,
  PERMISSIONS,
  sendInviteEmail,
  sendAccountLinkedEmail,
  sendPushAndInAppNotification,
  writeAuditLog,
} from "./shared";

// =============================================================================
// STAKEHOLDER CRUD
// =============================================================================

export const createStakeholder = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const canCreate = await hasPermission(
    callerUid, PERMISSIONS.createStakeholder
  );
  if (!canCreate) {
    throw new HttpsError(
      "permission-denied",
      "Insufficient permissions to create stakeholders."
    );
  }

  const {name, email, phone, organization, type} = request.data;
  if (!name || !email) {
    throw new HttpsError("invalid-argument", "Name and email are required.");
  }
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (typeof email !== "string" || !emailRegex.test(email)) {
    throw new HttpsError(
      "invalid-argument",
      "A valid email address is required."
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

    const callerDoc = await admin
      .firestore().collection("users").doc(callerUid).get();
    await writeAuditLog(
      callerUid, callerDoc.data()?.displayName || callerUid,
      "create_stakeholder", "stakeholder", stakeholderRef.id,
      `Created stakeholder "${name}"`
    );

    return {id: stakeholderRef.id};
  } catch (error) {
    logger.error("Error creating stakeholder:", error);
    throw new HttpsError("internal", "Error creating stakeholder.", error);
  }
});

export const getStakeholder = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const {id} = request.data;
  if (!id) {
    throw new HttpsError("invalid-argument", "Stakeholder ID is required.");
  }

  try {
    const stakeholderDoc = await admin
      .firestore().collection("stakeholders").doc(id).get();
    if (!stakeholderDoc.exists) {
      throw new HttpsError("not-found", "Stakeholder not found.");
    }
    return {id: stakeholderDoc.id, ...stakeholderDoc.data()};
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("Error getting stakeholder:", error);
    throw new HttpsError("internal", "Error getting stakeholder.", error);
  }
});

export const updateStakeholder = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const canEdit = await hasPermission(callerUid, PERMISSIONS.editStakeholder);
  if (!canEdit) {
    throw new HttpsError(
      "permission-denied",
      "Insufficient permissions to edit stakeholders."
    );
  }

  const {
    id, name, email, phone, organization, participationStatus,
  } = request.data;
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
      .firestore().collection("stakeholders").doc(id).update(updateData);
    logger.info(`Stakeholder updated: ${id}`);

    const callerDoc = await admin
      .firestore().collection("users").doc(callerUid).get();
    await writeAuditLog(
      callerUid, callerDoc.data()?.displayName || callerUid,
      "update_stakeholder", "stakeholder", id,
      `Updated stakeholder "${name || id}"`
    );

    return {success: true};
  } catch (error) {
    logger.error("Error updating stakeholder:", error);
    throw new HttpsError("internal", "Error updating stakeholder.", error);
  }
});

export const deleteStakeholder = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const canDelete = await hasPermission(
    callerUid, PERMISSIONS.deleteStakeholder
  );
  if (!canDelete) {
    throw new HttpsError(
      "permission-denied",
      "Insufficient permissions to delete stakeholders."
    );
  }

  const {id} = request.data;
  if (!id) {
    throw new HttpsError("invalid-argument", "Stakeholder ID is required.");
  }

  try {
    const eventsSnapshot = await admin
      .firestore()
      .collection("events")
      .where("stakeholderIds", "array-contains", id)
      .get();

    const batch = admin.firestore().batch();
    eventsSnapshot.docs.forEach((doc) =>
      batch.update(doc.ref, {
        stakeholderIds: admin.firestore.FieldValue.arrayRemove(id),
      })
    );
    batch.delete(admin.firestore().collection("stakeholders").doc(id));
    await batch.commit();

    logger.info(`Stakeholder deleted: ${id}`);

    const callerDoc = await admin
      .firestore().collection("users").doc(callerUid).get();
    await writeAuditLog(
      callerUid, callerDoc.data()?.displayName || callerUid,
      "delete_stakeholder", "stakeholder", id,
      `Deleted stakeholder "${id}"`
    );

    return {success: true};
  } catch (error) {
    logger.error("Error deleting stakeholder:", error);
    throw new HttpsError("internal", "Error deleting stakeholder.", error);
  }
});

// =============================================================================
// INVITE FLOW
// =============================================================================

export const inviteStakeholder = onCall(async (request) => {
  const {stakeholderId, defaultRole} = request.data;
  const callerUid = request.auth?.uid;

  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  if (!stakeholderId) {
    throw new HttpsError("invalid-argument", "Stakeholder ID is required.");
  }

  const canInvite = await hasPermission(
    callerUid, PERMISSIONS.inviteStakeholder
  );
  if (!canInvite) {
    throw new HttpsError(
      "permission-denied",
      "You don't have permission to invite stakeholders."
    );
  }

  const callerDoc = await admin
    .firestore().collection("users").doc(callerUid).get();
  const callerRole = callerDoc.data()?.role;
  const resolvedRole = defaultRole || "member";

  if (callerRole !== "admin" && !["member", "viewer"].includes(resolvedRole)) {
    throw new HttpsError(
      "permission-denied",
      "You can only invite stakeholders as member or viewer."
    );
  }

  try {
    const stakeholderRef = admin
      .firestore().collection("stakeholders").doc(stakeholderId);
    const stakeholderDoc = await stakeholderRef.get();
    if (!stakeholderDoc.exists) {
      throw new HttpsError("not-found", "Stakeholder not found.");
    }
    const stakeholderData = stakeholderDoc.data();
    if (!stakeholderData) {
      throw new HttpsError("internal", "Stakeholder data is empty.");
    }

    const inviteToken = admin.firestore().collection("_temp").doc().id;

    await stakeholderRef.update({
      inviteStatus: "pending",
      invitedAt: admin.firestore.FieldValue.serverTimestamp(),
      inviteToken,
      defaultRole: resolvedRole,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await admin.firestore().collection("invites").doc(inviteToken).set({
      stakeholderId,
      email: stakeholderData.email,
      defaultRole: resolvedRole,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
      ),
      used: false,
    });

    logger.info(`Stakeholder invited: ${stakeholderId}`, {
      email: stakeholderData.email,
      token: inviteToken,
    });

    const emailSent = await sendInviteEmail(
      stakeholderData.email,
      inviteToken,
      stakeholderData.name || stakeholderData.displayName
    );

    // Send push/in-app notification to linked user (if any)
    const linkedUserId = stakeholderData.linkedUserId;
    if (linkedUserId) {
      try {
        await sendPushAndInAppNotification(
          linkedUserId,
          "You've been invited to SSMS",
          "You have been invited to the Scheduling" +
          " & Stakeholder Management System.",
          "invite_sent",
          null
        );
      } catch (notifErr) {
        logger.warn(
          `Could not send invite notification to user ${linkedUserId}`,
          notifErr
        );
      }
    }

    return {
      success: true,
      inviteToken,
      email: stakeholderData.email,
      emailSent,
    };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
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
      .firestore().collection("invites").doc(token).get();
    if (!inviteDoc.exists) {
      return {valid: false, reason: "Token not found"};
    }

    const inviteData = inviteDoc.data();
    if (!inviteData) return {valid: false, reason: "Invalid invite data"};
    if (inviteData.used) return {valid: false, reason: "Token already used"};

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
  const {userId, token, inviteToken} = request.data;
  const resolvedToken = token || inviteToken;

  if (!userId) {
    throw new HttpsError("invalid-argument", "User ID is required.");
  }
  if (!resolvedToken) {
    throw new HttpsError("invalid-argument", "Invite token is required.");
  }

  try {
    const inviteDoc = await admin
      .firestore().collection("invites").doc(resolvedToken).get();
    if (!inviteDoc.exists) {
      throw new HttpsError("not-found", "Invite token not found.");
    }

    const inviteData = inviteDoc.data();
    if (!inviteData) throw new HttpsError("internal", "Invite data is empty.");
    if (inviteData.used) {
      throw new HttpsError(
        "already-exists",
        "This invite has already been used."
      );
    }

    const expiresAt = inviteData.expiresAt?.toDate();
    if (expiresAt && new Date() > expiresAt) {
      throw new HttpsError("deadline-exceeded", "This invite has expired.");
    }

    const stakeholderId = inviteData.stakeholderId;
    const defaultRole = inviteData.defaultRole || "member";
    if (!stakeholderId) {
      throw new HttpsError("internal", "Invite is missing stakeholder ID.");
    }

    const batch = admin.firestore().batch();

    batch.update(inviteDoc.ref, {
      used: true,
      usedAt: admin.firestore.FieldValue.serverTimestamp(),
      usedByUserId: userId,
    });

    const userRef = admin.firestore().collection("users").doc(userId);
    batch.update(userRef, {
      stakeholderId,
      role: defaultRole,
      permissions: getDefaultPermissions(defaultRole),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const stakeholderRef = admin
      .firestore().collection("stakeholders").doc(stakeholderId);
    batch.update(stakeholderRef, {
      linkedUserId: userId,
      inviteStatus: "accepted",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await batch.commit();

    const [stakeholderDoc, userDoc] = await Promise.all([
      stakeholderRef.get(),
      userRef.get(),
    ]);
    const stakeholderData = stakeholderDoc.data();
    const userData = userDoc.data();

    if (stakeholderData) {
      await sendPushAndInAppNotification(
        userId,
        "Account Linked!",
        "Your account has been linked to your " +
        "stakeholder profile. Welcome aboard!",
        "invite_accepted",
        null
      );

      if (userData?.email) {
        await sendAccountLinkedEmail(
          userData.email,
          userData.displayName,
          stakeholderData.name
        );
      }
    }

    logger.info(`User ${userId} linked to stakeholder ${stakeholderId}`);
    return {success: true, role: defaultRole};
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("Error linking user to stakeholder:", error);
    throw new HttpsError(
      "internal", "Error linking user to stakeholder.", error
    );
  }
});

export const resendInvite = onCall(async (request) => {
  const {stakeholderId} = request.data;
  const callerUid = request.auth?.uid;

  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  if (!stakeholderId) {
    throw new HttpsError("invalid-argument", "Stakeholder ID is required.");
  }

  try {
    const canInvite = await hasPermission(
      callerUid, PERMISSIONS.inviteStakeholder
    );
    if (!canInvite) {
      throw new HttpsError(
        "permission-denied",
        "You don't have permission to invite stakeholders."
      );
    }

    const stakeholderRef = admin
      .firestore().collection("stakeholders").doc(stakeholderId);
    const stakeholderDoc = await stakeholderRef.get();
    if (!stakeholderDoc.exists) {
      throw new HttpsError("not-found", "Stakeholder not found.");
    }

    const stakeholderData = stakeholderDoc.data();
    if (!stakeholderData) {
      throw new HttpsError("internal", "Stakeholder data is empty.");
    }
    if (stakeholderData.linkedUserId) {
      throw new HttpsError(
        "already-exists",
        "Stakeholder already has a linked account."
      );
    }

    const callerDoc = await admin
      .firestore().collection("users").doc(callerUid).get();
    const callerRole = callerDoc.data()?.role;
    const existingRole = stakeholderData.defaultRole || "member";

    if (
      callerRole !== "admin" &&
      !["member", "viewer"].includes(existingRole)
    ) {
      throw new HttpsError(
        "permission-denied",
        "You can only resend invites for member or viewer stakeholders."
      );
    }

    // Expire old invite
    const oldToken = stakeholderData.inviteToken;
    if (oldToken) {
      const oldInviteRef = admin
        .firestore().collection("invites").doc(oldToken);
      const oldInviteDoc = await oldInviteRef.get();
      if (oldInviteDoc.exists) {
        await oldInviteRef.update({
          used: true,
          replacedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    const newToken = admin.firestore().collection("_temp").doc().id;

    await stakeholderRef.update({
      inviteStatus: "pending",
      invitedAt: admin.firestore.FieldValue.serverTimestamp(),
      inviteToken: newToken,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await admin.firestore().collection("invites").doc(newToken).set({
      stakeholderId,
      email: stakeholderData.email,
      defaultRole: stakeholderData.defaultRole || "member",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
      ),
      used: false,
      resentBy: callerUid,
    });

    const emailSent = await sendInviteEmail(
      stakeholderData.email,
      newToken,
      stakeholderData.name || stakeholderData.displayName
    );

    logger.info(`Invite resent to stakeholder: ${stakeholderId}`);
    return {
      success: true,
      inviteToken: newToken,
      email: stakeholderData.email,
      emailSent,
    };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("Error resending invite:", error);
    throw new HttpsError("internal", "Error resending invite.", error);
  }
});

// =============================================================================
// EVENT-STAKEHOLDER RELATIONSHIP MANAGEMENT
// =============================================================================

export const addStakeholderToEvent = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const {eventId, stakeholderId} = request.data;
  if (!eventId || !stakeholderId) {
    throw new HttpsError(
      "invalid-argument",
      "Event ID and Stakeholder ID are required."
    );
  }

  const canAssign = await hasPermission(
    callerUid, PERMISSIONS.assignStakeholder
  );
  if (!canAssign) {
    throw new HttpsError(
      "permission-denied",
      "You don't have permission to assign stakeholders."
    );
  }

  try {
    await admin.firestore().collection("events").doc(eventId).update({
      stakeholderIds: admin.firestore.FieldValue.arrayUnion(stakeholderId),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await admin
      .firestore().collection("stakeholders").doc(stakeholderId).update({
        eventIds: admin.firestore.FieldValue.arrayUnion(eventId),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    const [stakeholderDoc, eventDoc] = await Promise.all([
      admin.firestore().collection("stakeholders").doc(stakeholderId).get(),
      admin.firestore().collection("events").doc(eventId).get(),
    ]);
    const linkedUserId = stakeholderDoc.data()?.linkedUserId;
    const eventTitle = eventDoc.data()?.title ?? "an event";

    if (linkedUserId && linkedUserId !== callerUid) {
      await sendPushAndInAppNotification(
        linkedUserId,
        `Added to Event: ${eventTitle}`,
        `You have been assigned to "${eventTitle}".`,
        "event_assignment",
        eventId
      );
    }

    logger.info(`Stakeholder ${stakeholderId} added to event ${eventId}`);

    const assignCallerUid = request.auth?.uid;
    if (assignCallerUid) {
      const callerDoc = await admin
        .firestore().collection("users").doc(assignCallerUid).get();
      await writeAuditLog(
        assignCallerUid, callerDoc.data()?.displayName || assignCallerUid,
        "assign_stakeholder", "event", eventId,
        `Assigned stakeholder ${stakeholderId} to event "${eventTitle}"`
      );
    }

    return {success: true};
  } catch (error) {
    logger.error("Error adding stakeholder to event:", error);
    throw new HttpsError(
      "internal", "Error adding stakeholder to event.", error
    );
  }
});

export const removeStakeholderFromEvent = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const {eventId, stakeholderId} = request.data;
  if (!eventId || !stakeholderId) {
    throw new HttpsError(
      "invalid-argument",
      "Event ID and Stakeholder ID are required."
    );
  }

  const canAssign = await hasPermission(
    callerUid, PERMISSIONS.assignStakeholder
  );
  if (!canAssign) {
    throw new HttpsError(
      "permission-denied",
      "You don't have permission to manage stakeholder assignments."
    );
  }

  try {
    await admin.firestore().collection("events").doc(eventId).update({
      stakeholderIds: admin.firestore.FieldValue.arrayRemove(stakeholderId),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await admin
      .firestore().collection("stakeholders").doc(stakeholderId).update({
        eventIds: admin.firestore.FieldValue.arrayRemove(eventId),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    try {
      const [shDoc, evDoc] = await Promise.all([
        admin.firestore().collection("stakeholders").doc(stakeholderId).get(),
        admin.firestore().collection("events").doc(eventId).get(),
      ]);
      const linkedUserId = shDoc.data()?.linkedUserId;
      const eventTitle = evDoc.data()?.title ?? "an event";
      if (linkedUserId && linkedUserId !== callerUid) {
        await sendPushAndInAppNotification(
          linkedUserId,
          `Removed from Event: ${eventTitle}`,
          `You have been removed from "${eventTitle}".`,
          "event_update",
          null
        );
      }
    } catch (err) {
      logger.warn(
        "Could not send removal notification " +
        `for stakeholder ${stakeholderId}`, err
      );
    }

    logger.info(`Stakeholder ${stakeholderId} removed from event ${eventId}`);
    return {success: true};
  } catch (error) {
    logger.error("Error removing stakeholder from event:", error);
    throw new HttpsError(
      "internal", "Error removing stakeholder from event.", error
    );
  }
});
