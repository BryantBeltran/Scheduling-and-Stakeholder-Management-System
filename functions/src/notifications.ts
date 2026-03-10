import {onCall} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import {HttpsError, sendPushAndInAppNotification} from "./shared";

// =============================================================================
// IN-APP NOTIFICATION CRUD
// =============================================================================

export const sendNotification = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const {userId, title, body, type, eventId} = request.data;
  if (!userId || !title || !body) {
    throw new HttpsError(
      "invalid-argument",
      "User ID, title, and body are required."
    );
  }

  try {
    await sendPushAndInAppNotification(
      userId, title, body, type || "general", eventId || null
    );
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

    if (limit) query = query.limit(limit);

    const snapshot = await query.get();
    return snapshot.docs.map((doc) => ({id: doc.id, ...doc.data()}));
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

// =============================================================================
// FCM TOKEN MANAGEMENT
// =============================================================================

/** Save an FCM token for the authenticated user. */
export const saveFcmToken = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const {token} = request.data;
  if (!token) {
    throw new HttpsError("invalid-argument", "FCM token is required.");
  }

  try {
    await admin.firestore().collection("users").doc(callerUid).update({
      fcmTokens: admin.firestore.FieldValue.arrayUnion([token]),
      lastTokenUpdate: admin.firestore.FieldValue.serverTimestamp(),
    });
    logger.info(`FCM token saved for user: ${callerUid}`);
    return {success: true};
  } catch (error) {
    logger.error("Error saving FCM token:", error);
    throw new HttpsError("internal", "Error saving FCM token.", error);
  }
});

/** Remove an FCM token on logout. */
export const removeFcmToken = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const {token} = request.data;
  if (!token) {
    throw new HttpsError("invalid-argument", "FCM token is required.");
  }

  try {
    await admin.firestore().collection("users").doc(callerUid).update({
      fcmTokens: admin.firestore.FieldValue.arrayRemove([token]),
    });
    logger.info(`FCM token removed for user: ${callerUid}`);
    return {success: true};
  } catch (error) {
    logger.error("Error removing FCM token:", error);
    throw new HttpsError("internal", "Error removing FCM token.", error);
  }
});

// =============================================================================
// SCHEDULED: EVENT REMINDERS (every 15 minutes)
// =============================================================================

/**
 * Runs every 15 minutes. For each reminder window (15, 30, 60, 1440 minutes),
 * finds upcoming events and sends a reminder to each recipient — but ONLY if
 * that window matches the user's defaultReminderMinutes preference.
 *
 * Deduplication uses a per-user key: remindersSent.{window_key}_{userId}
 */
export const sendEventReminders = onSchedule(
  "every 15 minutes",
  async () => {
    try {
      const now = new Date();

      const windows = [
        {key: "reminder_1440", minutesBefore: 1440, label: "24 hours"},
        {key: "reminder_60", minutesBefore: 60, label: "1 hour"},
        {key: "reminder_30", minutesBefore: 30, label: "30 minutes"},
        {key: "reminder_15", minutesBefore: 15, label: "15 minutes"},
      ];

      for (const window of windows) {
        const targetStart = new Date(
          now.getTime() + window.minutesBefore * 60 * 1000
        );
        const targetEnd = new Date(targetStart.getTime() + 15 * 60 * 1000);

        const eventsSnapshot = await admin
          .firestore()
          .collection("events")
          .where("status", "==", "scheduled")
          .where("startTime", ">=", targetStart.toISOString())
          .where("startTime", "<", targetEnd.toISOString())
          .get();

        for (const eventDoc of eventsSnapshot.docs) {
          const eventData = eventDoc.data();
          const remindersSent = eventData.remindersSent || {};
          const stakeholderIds: string[] = eventData.stakeholderIds || [];

          // Collect all user IDs to notify
          const userIdsToNotify: string[] = [];

          for (const shId of stakeholderIds) {
            const shDoc = await admin
              .firestore().collection("stakeholders").doc(shId).get();
            const linkedUserId = shDoc.data()?.linkedUserId;
            if (linkedUserId) userIdsToNotify.push(linkedUserId);
          }

          if (eventData.ownerId) userIdsToNotify.push(eventData.ownerId);

          const uniqueUserIds = [...new Set(userIdsToNotify)];

          for (const userId of uniqueUserIds) {
            const userReminderKey = `${window.key}_${userId}`;
            if (remindersSent[userReminderKey]) continue;

            // Check user's preferred reminder time
            const userDoc = await admin
              .firestore().collection("users").doc(userId).get();
            const prefs =
              (userDoc.data()?.notificationPreferences ?? {}) as
              Record<string, unknown>;
            const preferredMinutes =
              (prefs.defaultReminderMinutes as number) ?? 30;

            if (preferredMinutes !== window.minutesBefore) continue;

            await sendPushAndInAppNotification(
              userId,
              `Event in ${window.label}`,
              `"${eventData.title}" starts in ${window.label}.`,
              "event_reminder",
              eventDoc.id
            );

            await eventDoc.ref.update({
              [`remindersSent.${userReminderKey}`]: true,
            });

            logger.info(
              `Reminder (${window.label}) sent for event ` +
              `${eventDoc.id} to user ${userId}`
            );
          }
        }
      }
    } catch (error) {
      logger.error("Error sending event reminders:", error);
    }
  }
);

// =============================================================================
// SCHEDULED: CLEANUP EXPIRED INVITES (daily)
// =============================================================================

export const cleanupExpiredInvites = onSchedule(
  "every 24 hours",
  async () => {
    try {
      const now = admin.firestore.Timestamp.now();
      const snapshot = await admin
        .firestore()
        .collection("invites")
        .where("used", "==", false)
        .where("expiresAt", "<", now)
        .get();

      if (snapshot.empty) {
        logger.info("No expired invites to clean up.");
        return;
      }

      const batch = admin.firestore().batch();
      let count = 0;

      for (const doc of snapshot.docs) {
        const data = doc.data();
        batch.update(doc.ref, {
          used: true,
          expiredAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        if (data.stakeholderId) {
          const stakeholderRef = admin
            .firestore().collection("stakeholders").doc(data.stakeholderId);
          batch.update(stakeholderRef, {
            inviteStatus: "expired",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        count++;
      }

      await batch.commit();
      logger.info(`Cleaned up ${count} expired invite(s).`);
    } catch (error) {
      logger.error("Error cleaning up expired invites:", error);
    }
  }
);

// =============================================================================
// SCHEDULED: AUTO STATUS TRANSITIONS (every 5 minutes)
// =============================================================================

/**
 * Runs every 5 minutes.
 * - Marks scheduled events as inProgress when startTime has passed.
 * - Marks inProgress events as completed when endTime has passed.
 * Notifies the event owner in both cases.
 */
export const autoTransitionEventStatus = onSchedule(
  "every 5 minutes",
  async () => {
    try {
      const now = new Date().toISOString();

      // --- scheduled → inProgress ---
      const startedSnapshot = await admin
        .firestore()
        .collection("events")
        .where("status", "==", "scheduled")
        .where("startTime", "<=", now)
        .get();

      for (const doc of startedSnapshot.docs) {
        const data = doc.data();
        await doc.ref.update({
          status: "inProgress",
          updatedAt: now,
        });
        logger.info(`Event ${doc.id} transitioned to inProgress`);

        if (data.ownerId) {
          await sendPushAndInAppNotification(
            data.ownerId,
            `Event Started: ${data.title}`,
            `"${data.title}" is now in progress.`,
            "event_update",
            doc.id
          );
        }
      }

      // --- inProgress → completed ---
      const endedSnapshot = await admin
        .firestore()
        .collection("events")
        .where("status", "==", "inProgress")
        .where("endTime", "<=", now)
        .get();

      for (const doc of endedSnapshot.docs) {
        const data = doc.data();
        await doc.ref.update({
          status: "completed",
          updatedAt: now,
        });
        logger.info(`Event ${doc.id} transitioned to completed`);

        if (data.ownerId) {
          await sendPushAndInAppNotification(
            data.ownerId,
            `Event Completed: ${data.title}`,
            `"${data.title}" has ended and been marked as completed.`,
            "event_update",
            doc.id
          );
        }
      }

      logger.info(
        `autoTransitionEventStatus: ${startedSnapshot.size} started, ` +
        `${endedSnapshot.size} completed`
      );
    } catch (error) {
      logger.error("Error in autoTransitionEventStatus:", error);
    }
  }
);

// =============================================================================
// TEST NOTIFICATION
// =============================================================================

export const sendTestNotification = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const userId = request.auth.uid;
  try {
    await sendPushAndInAppNotification(
      userId,
      "🔔 Test Notification",
      "Notifications are working correctly on this device.",
      "general",
      null
    );
    logger.info(`Test notification sent to user: ${userId}`);
    return {success: true, message: "Test notification sent."};
  } catch (error) {
    logger.error("Error sending test notification:", error);
    throw new HttpsError(
      "internal", "Failed to send test notification.", error
    );
  }
});
