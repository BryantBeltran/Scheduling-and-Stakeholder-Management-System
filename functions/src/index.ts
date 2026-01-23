import {setGlobalOptions} from "firebase-functions/v2";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK
admin.initializeApp();

// Start writing functions
// https://firebase.google.com/docs/functions/typescript

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({maxInstances: 10});

export const createUser = onCall(async (request) => {
  const {email, password, displayName} = request.data;
  try {
    const userRecord = await admin.auth().createUser({
      email,
      password,
      displayName,
    });
    await admin.firestore().collection("users").doc(userRecord.uid).set({
      displayName,
      email,
    });
    return {uid: userRecord.uid};
  } catch (error) {
    logger.error("Error creating user:", error);
    throw new HttpsError("internal", "Error creating user.", error);
  }
});

export const getUser = onCall(async (request) => {
  const {uid} = request.data;
  try {
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    if (!userDoc.exists) {
      throw new HttpsError("not-found", "User not found.");
    }
    return userDoc.data();
  } catch (error) {
    logger.error("Error getting user:", error);
    throw new HttpsError("internal", "Error getting user.", error);
  }
});

export const updateUser = onCall(async (request) => {
  const {uid, displayName} = request.data;
  try {
    await admin.firestore().collection("users").doc(uid).update({
      displayName,
    });
    return {success: true};
  } catch (error) {
    logger.error("Error updating user:", error);
    throw new HttpsError("internal", "Error updating user.", error);
  }
});

export const deleteUser = onCall(async (request) => {
  const {uid} = request.data;
  try {
    await admin.auth().deleteUser(uid);
    await admin.firestore().collection("users").doc(uid).delete();
    return {success: true};
  } catch (error) {
    logger.error("Error deleting user:", error);
    throw new HttpsError("internal", "Error deleting user.", error);
  }
});

export const createEvent = onCall(async (request) => {
  const {title, description, date, location} = request.data;
  try {
    const eventRef = await admin.firestore().collection("events").add({
      title,
      description,
      date,
      location,
    });
    return {id: eventRef.id};
  } catch (error) {
    logger.error("Error creating event:", error);
    throw new HttpsError("internal", "Error creating event.", error);
  }
});

export const getEvent = onCall(async (request) => {
  const {id} = request.data;
  try {
    const eventDoc = await admin.firestore().collection("events").doc(id).get();
    if (!eventDoc.exists) {
      throw new HttpsError("not-found", "Event not found.");
    }
    return eventDoc.data();
  } catch (error) {
    logger.error("Error getting event:", error);
    throw new HttpsError("internal", "Error getting event.", error);
  }
});

export const updateEvent = onCall(async (request) => {
  const {id, title, description, date, location} = request.data;
  try {
    await admin.firestore().collection("events").doc(id).update({
      title,
      description,
      date,
      location,
    });
    return {success: true};
  } catch (error) {
    logger.error("Error updating event:", error);
    throw new HttpsError("internal", "Error updating event.", error);
  }
});

export const deleteEvent = onCall(async (request) => {
  const {id} = request.data;
  try {
    await admin.firestore().collection("events").doc(id).delete();
    return {success: true};
  } catch (error) {
    logger.error("Error deleting event:", error);
    throw new HttpsError("internal", "Error deleting event.", error);
  }
});

export const createStakeholder = onCall(async (request) => {
  const {name, email, phone} = request.data;
  try {
    const stakeholderRef = await admin
      .firestore()
      .collection("stakeholders")
      .add({
        name,
        email,
        phone,
      });
    return {id: stakeholderRef.id};
  } catch (error) {
    logger.error("Error creating stakeholder:", error);
    throw new HttpsError("internal",
      "Error creating stakeholder.", error);
  }
});

export const getStakeholder = onCall(async (request) => {
  const {id} = request.data;
  try {
    const stakeholderDoc = await admin
      .firestore()
      .collection("stakeholders")
      .doc(id)
      .get();
    if (!stakeholderDoc.exists) {
      throw new HttpsError("not-found", "Stakeholder not found.");
    }
    return stakeholderDoc.data();
  } catch (error) {
    logger.error("Error getting stakeholder:", error);
    throw new HttpsError("internal",
      "Error getting stakeholder.", error);
  }
});

export const updateStakeholder = onCall(async (request) => {
  const {id, name, email, phone} = request.data;
  try {
    await admin.firestore().collection("stakeholders").doc(id).update({
      name,
      email,
      phone,
    });
    return {success: true};
  } catch (error) {
    logger.error("Error updating stakeholder:", error);
    throw new HttpsError("internal", "Error updating stakeholder.", error);
  }
});

export const deleteStakeholder = onCall(async (request) => {
  const {id} = request.data;
  try {
    await admin.firestore().collection("stakeholders").doc(id).delete();
    return {success: true};
  } catch (error) {
    logger.error("Error deleting stakeholder:", error);
    throw new HttpsError("internal", "Error deleting stakeholder.", error);
  }
});

export const addStakeholderToEvent = onCall(async (request) => {
  const {eventId, stakeholderId} = request.data;
  try {
    await admin.firestore().collection("eventStakeholders").add({
      eventId,
      stakeholderId,
    });
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
  try {
    const snapshot = await admin
      .firestore()
      .collection("eventStakeholders")
      .where("eventId", "==", eventId)
      .where("stakeholderId", "==", stakeholderId)
      .get();

    if (snapshot.empty) {
      throw new HttpsError(
        "not-found",
        "Event-stakeholder relationship not found."
      );
    }

    const batch = admin.firestore().batch();
    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });
    await batch.commit();

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

export const sendNotification = onCall(async (request) => {
  const {userId, title, body} = request.data;
  try {
    await admin.firestore().collection("notifications").add({
      userId,
      title,
      body,
      createdAt: new Date(),
      isRead: false,
    });
    return {success: true};
  } catch (error) {
    logger.error("Error sending notification:", error);
    throw new HttpsError("internal", "Error sending notification.", error);
  }
});

export const getNotifications = onCall(async (request) => {
  const {userId} = request.data;
  try {
    const snapshot = await admin.firestore().collection("notifications")
      .where("userId", "==", userId)
      .orderBy("createdAt", "desc")
      .get();

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
  try {
    await admin.firestore().collection("notifications").doc(id).update({
      isRead: true,
    });
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

// export const helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// })
