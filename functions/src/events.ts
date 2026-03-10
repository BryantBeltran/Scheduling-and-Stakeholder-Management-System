import {onCall} from "firebase-functions/v2/https";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import {
  HttpsError,
  hasPermission,
  PERMISSIONS,
  sendPushAndInAppNotification,
} from "./shared";

// =============================================================================
// EVENT TRIGGERS
// =============================================================================

/** When a new event is created, notify any already-assigned stakeholders. */
export const onEventCreated = onDocumentCreated(
  "events/{eventId}",
  async (event) => {
    const eventId = event.params.eventId;
    const eventData = event.data?.data();
    if (!eventData) return;

    logger.info(`New event created: ${eventData.title}`, {eventId});

    try {
      if (eventData.stakeholderIds && eventData.stakeholderIds.length > 0) {
        for (const stakeholderId of eventData.stakeholderIds) {
          const stakeholderDoc = await admin
            .firestore()
            .collection("stakeholders")
            .doc(stakeholderId)
            .get();
          const stakeholder = stakeholderDoc.data();
          const linkedUserId = stakeholder?.linkedUserId;

          if (linkedUserId) {
            await sendPushAndInAppNotification(
              linkedUserId,
              "New Event Assigned",
              `You've been assigned to: ${eventData.title}`,
              "event_assignment",
              eventId
            );
          } else {
            await admin.firestore().collection("notifications").add({
              userId: stakeholderId,
              title: "New Event Assigned",
              body: `You've been assigned to: ${eventData.title}`,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              isRead: false,
              type: "event_assignment",
              eventId,
            });
          }
        }
        logger.info(`Notifications sent for event: ${eventId}`);
      }
    } catch (error) {
      logger.error(`Error sending event notifications: ${eventId}`, error);
    }
  }
);

// =============================================================================
// EVENT CRUD
// =============================================================================

export const createEvent = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const {
    title, description, startTime, endTime, location,
    ownerId, ownerName, status, priority, stakeholderIds,
    recurrenceRule, metadata,
  } = request.data;

  if (ownerId !== callerUid) {
    throw new HttpsError("permission-denied", "You can only create events as yourself.");
  }

  const canCreate = await hasPermission(callerUid, PERMISSIONS.createEvent);
  if (!canCreate) {
    throw new HttpsError("permission-denied", "Insufficient permissions to create events.");
  }

  if (!title || !startTime || !ownerId) {
    throw new HttpsError(
      "invalid-argument",
      "Title, start time, and owner ID are required."
    );
  }

  if (title.length < 3 || title.length > 100) {
    throw new HttpsError(
      "invalid-argument",
      "Title must be between 3 and 100 characters."
    );
  }

  if (endTime) {
    const start = new Date(startTime);
    const end = new Date(endTime);
    if (end <= start) {
      throw new HttpsError("invalid-argument", "End time must be after start time.");
    }
    const diffMs = end.getTime() - start.getTime();
    if (diffMs < 5 * 60 * 1000) {
      throw new HttpsError("invalid-argument", "Event must be at least 5 minutes long.");
    }
    if (diffMs > 30 * 24 * 60 * 60 * 1000) {
      throw new HttpsError("invalid-argument", "Event cannot be longer than 30 days.");
    }
  }

  try {
    const eventLocation =
      location && typeof location === "object" ?
        {
          name: location.name || "",
          address: location.address || null,
          latitude: location.latitude || null,
          longitude: location.longitude || null,
          isVirtual: location.isVirtual || false,
          virtualLink: location.virtualLink || null,
        } :
        {
          name: typeof location === "string" ? location : "",
          address: null,
          latitude: null,
          longitude: null,
          isVirtual: false,
          virtualLink: null,
        };

    const now = new Date().toISOString();
    const eventRef = await admin.firestore().collection("events").add({
      title,
      description: description || null,
      startTime,
      endTime: endTime || null,
      location: eventLocation,
      ownerId,
      ownerName: ownerName || null,
      status: status || "draft",
      priority: priority || "medium",
      stakeholderIds: stakeholderIds || [],
      recurrenceRule: recurrenceRule || null,
      metadata: metadata || null,
      createdAt: now,
      updatedAt: now,
    });

    logger.info(`Event created: ${title}`, {id: eventRef.id});

    const assignedIds: string[] = stakeholderIds || [];
    for (const shId of assignedIds) {
      try {
        const shDoc = await admin.firestore().collection("stakeholders").doc(shId).get();
        const linkedUserId = shDoc.data()?.linkedUserId;
        if (linkedUserId && linkedUserId !== callerUid) {
          await sendPushAndInAppNotification(
            linkedUserId,
            `You've been invited to: ${title}`,
            `You have been added to the event "${title}".`,
            "event_assignment",
            eventRef.id
          );
        }
      } catch (err) {
        logger.warn(`Failed to notify stakeholder ${shId} for new event`, err);
      }
    }

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
    if (error instanceof HttpsError) throw error;
    logger.error("Error getting event:", error);
    throw new HttpsError("internal", "Error getting event.", error);
  }
});

export const getAllEvents = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  try {
    const snapshot = await admin
      .firestore()
      .collection("events")
      .where("ownerId", "==", callerUid)
      .get();

    const events = snapshot.docs.map((doc) => ({id: doc.id, ...doc.data()}));
    logger.info(`Events retrieved for user: ${callerUid}`, {count: events.length});
    return events;
  } catch (error) {
    logger.error("Error getting all events:", error);
    throw new HttpsError("internal", "Error getting all events.", error);
  }
});

export const updateEvent = onCall(async (request) => {
  const {
    id, title, description, startTime, endTime, location,
    status, priority, stakeholderIds, ownerName,
    recurrenceRule, metadata,
  } = request.data;

  if (!id) {
    throw new HttpsError("invalid-argument", "Event ID is required.");
  }

  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  try {
    const eventDoc = await admin.firestore().collection("events").doc(id).get();
    if (!eventDoc.exists) {
      throw new HttpsError("not-found", "Event not found.");
    }

    const existingData = eventDoc.data();
    if (existingData?.ownerId !== callerUid) {
      throw new HttpsError(
        "permission-denied",
        "You do not have permission to update this event."
      );
    }

    if (title !== undefined && (title.length < 3 || title.length > 100)) {
      throw new HttpsError(
        "invalid-argument",
        "Title must be between 3 and 100 characters."
      );
    }

    const updateData: Record<string, unknown> = {updatedAt: new Date().toISOString()};

    if (title !== undefined) updateData.title = title;
    if (description !== undefined) updateData.description = description;
    if (startTime !== undefined) updateData.startTime = startTime;
    if (endTime !== undefined) updateData.endTime = endTime;
    if (ownerName !== undefined) updateData.ownerName = ownerName;
    if (status !== undefined) updateData.status = status;
    if (priority !== undefined) updateData.priority = priority;
    if (stakeholderIds !== undefined) updateData.stakeholderIds = stakeholderIds;
    if (recurrenceRule !== undefined) updateData.recurrenceRule = recurrenceRule;
    if (metadata !== undefined) updateData.metadata = metadata;

    if (location !== undefined) {
      if (typeof location === "object" && location !== null) {
        updateData.location = {
          name: location.name || "",
          address: location.address || null,
          latitude: location.latitude || null,
          longitude: location.longitude || null,
          isVirtual: location.isVirtual || false,
          virtualLink: location.virtualLink || null,
        };
      } else {
        updateData.location = {
          name: typeof location === "string" ? location : "",
          address: null, latitude: null, longitude: null,
          isVirtual: false, virtualLink: null,
        };
      }
    }

    const finalStart = (startTime || existingData?.startTime) as string;
    const finalEnd = (endTime || existingData?.endTime) as string;
    if (finalStart && finalEnd) {
      if (new Date(finalEnd) <= new Date(finalStart)) {
        throw new HttpsError("invalid-argument", "End time must be after start time.");
      }
    }

    await admin.firestore().collection("events").doc(id).update(updateData);
    logger.info(`Event updated: ${id}`);
    return {success: true};
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("Error updating event:", error);
    throw new HttpsError("internal", "Error updating event.", error);
  }
});

export const deleteEvent = onCall(async (request) => {
  const {id} = request.data;
  if (!id) {
    throw new HttpsError("invalid-argument", "Event ID is required.");
  }

  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  try {
    const eventDoc = await admin.firestore().collection("events").doc(id).get();
    if (!eventDoc.exists) {
      throw new HttpsError("not-found", "Event not found.");
    }

    const eventData = eventDoc.data();
    if (eventData?.ownerId !== callerUid) {
      throw new HttpsError(
        "permission-denied",
        "You do not have permission to delete this event."
      );
    }

    const batch = admin.firestore().batch();
    batch.delete(admin.firestore().collection("events").doc(id));

    const eventStakeholders = await admin
      .firestore()
      .collection("eventStakeholders")
      .where("eventId", "==", id)
      .get();
    eventStakeholders.docs.forEach((doc) => batch.delete(doc.ref));

    // Notify assigned stakeholders before deletion
    if (eventData?.stakeholderIds && eventData.stakeholderIds.length > 0) {
      for (const stakeholderId of eventData.stakeholderIds) {
        try {
          const shDoc = await admin
            .firestore().collection("stakeholders").doc(stakeholderId).get();
          const linkedUserId = shDoc.data()?.linkedUserId;
          if (linkedUserId && linkedUserId !== callerUid) {
            await sendPushAndInAppNotification(
              linkedUserId,
              `Event Cancelled: ${eventData.title}`,
              `"${eventData.title}" has been cancelled and removed.`,
              "event_update",
              null
            );
          }
        } catch (err) {
          logger.warn(
            `Could not notify stakeholder ${stakeholderId} of event deletion`, err
          );
        }

        const stakeholderRef = admin.firestore().collection("stakeholders").doc(stakeholderId);
        batch.update(stakeholderRef, {
          eventIds: admin.firestore.FieldValue.arrayRemove(id),
        });
      }
    }

    const notifications = await admin
      .firestore()
      .collection("notifications")
      .where("eventId", "==", id)
      .get();
    notifications.docs.forEach((doc) => batch.delete(doc.ref));

    await batch.commit();
    logger.info(`Event deleted: ${id}`);
    return {success: true};
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("Error deleting event:", error);
    throw new HttpsError("internal", "Error deleting event.", error);
  }
});

/** Notify all stakeholders when an event is updated. */
export const notifyEventUpdate = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const {eventId, changeDescription} = request.data;
  if (!eventId) {
    throw new HttpsError("invalid-argument", "Event ID is required.");
  }

  try {
    const eventDoc = await admin.firestore().collection("events").doc(eventId).get();
    if (!eventDoc.exists) {
      throw new HttpsError("not-found", "Event not found.");
    }

    const eventData = eventDoc.data();
    if (!eventData) {
      throw new HttpsError("internal", "Event data is empty.");
    }

    const stakeholderIds: string[] = eventData.stakeholderIds || [];
    const description = changeDescription || "Event details have been updated.";
    let notified = 0;

    for (const shId of stakeholderIds) {
      const shDoc = await admin.firestore().collection("stakeholders").doc(shId).get();
      const linkedUserId = shDoc.data()?.linkedUserId;
      if (linkedUserId && linkedUserId !== callerUid) {
        await sendPushAndInAppNotification(
          linkedUserId,
          `Event Updated: ${eventData.title}`,
          description,
          "event_update",
          eventId
        );
        notified++;
      }
    }

    if (eventData.ownerId && eventData.ownerId !== callerUid) {
      await sendPushAndInAppNotification(
        eventData.ownerId,
        `Event Updated: ${eventData.title}`,
        description,
        "event_update",
        eventId
      );
      notified++;
    }

    logger.info(
      `Event update notification sent to ${notified} user(s) for event: ${eventId}`
    );
    return {success: true, notifiedCount: notified};
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("Error sending event update notification:", error);
    throw new HttpsError("internal", "Error sending event update notification.", error);
  }
});
