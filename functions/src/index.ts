import {setGlobalOptions} from "firebase-functions/v2";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {
  onDocumentCreated,
  onDocumentDeleted,
} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import * as nodemailer from "nodemailer";

// Initialize Firebase Admin SDK
admin.initializeApp();

// For cost control, set maximum concurrent instances
setGlobalOptions({maxInstances: 10});

// =============================================================================
// EMAIL CONFIGURATION
// =============================================================================
// Uses Firebase environment config for SMTP credentials.
// Set with:
//   firebase functions:config:set smtp.host smtp.port smtp.user smtp.pass
// For Gmail:
//   host=smtp.gmail.com, port=587, user=your@gmail.com, pass=app-password
// For testing without SMTP, the function will log the invite link
// and skip email.
// =============================================================================

/**
 * Create a Nodemailer transporter using SMTP config from environment.
 * Returns null if SMTP is not configured (emails will be skipped gracefully).
 * @return {nodemailer.Transporter | null} Transporter or null if not configured
 */
function getMailTransporter(): nodemailer.Transporter | null {
  const smtpHost = process.env.SMTP_HOST;
  const smtpPort = process.env.SMTP_PORT;
  const smtpUser = process.env.SMTP_USER;
  const smtpPass = process.env.SMTP_PASS;

  if (!smtpHost || !smtpUser || !smtpPass) {
    logger.warn(
      "SMTP not configured. Set SMTP_HOST, SMTP_PORT, SMTP_USER, " +
      "SMTP_PASS environment variables to enable invite emails."
    );
    return null;
  }

  return nodemailer.createTransport({
    host: smtpHost,
    port: parseInt(smtpPort || "587", 10),
    secure: smtpPort === "465",
    auth: {
      user: smtpUser,
      pass: smtpPass,
    },
  });
}

/**
 * Send an invite email to a stakeholder
 * @param {string} email - The recipient email address
 * @param {string} inviteToken - The unique invite token
 * @param {string} stakeholderName - The name of the stakeholder (optional)
 * @return {Promise<boolean>} True if email was sent, false otherwise
 */
async function sendInviteEmail(
  email: string,
  inviteToken: string,
  stakeholderName?: string
): Promise<boolean> {
  const transporter = getMailTransporter();
  if (!transporter) {
    logger.info(
      "Email sending skipped (SMTP not configured). " +
      `Invite link: https://ssms.app/invite?token=${inviteToken}`
    );
    return false;
  }

  const inviteLink = `https://ssms.app/invite?token=${inviteToken}`;
  const senderEmail = process.env.SMTP_USER || "noreply@ssms.app";
  const recipientName = stakeholderName || "there";

  try {
    /* eslint-disable max-len */
    await transporter.sendMail({
      from: `"SSMS" <${senderEmail}>`,
      to: email,
      subject: "You've been invited to SSMS",
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background-color: #000; color: #fff; padding: 24px; text-align: center;">
            <h1 style="margin: 0; font-size: 24px;">Scheduling & Stakeholder Management</h1>
          </div>
          <div style="padding: 32px 24px;">
            <h2 style="color: #333;">Hi ${recipientName}!</h2>
            <p style="color: #555; font-size: 16px; line-height: 1.6;">
              You've been invited to join the Scheduling & Stakeholder Management System.
              Click the button below to create your account and get started.
            </p>
            <div style="text-align: center; margin: 32px 0;">
              <a href="${inviteLink}"
                 style="background-color: #000; color: #fff; padding: 14px 32px;
                        text-decoration: none; border-radius: 8px; font-size: 16px;
                        font-weight: 600; display: inline-block;">
                Accept Invitation
              </a>
            </div>
            <p style="color: #888; font-size: 13px;">
              This invitation expires in 7 days. If you didn't expect this email,
              you can safely ignore it.
            </p>
            <hr style="border: none; border-top: 1px solid #eee; margin: 24px 0;" />
            <p style="color: #999; font-size: 12px;">
              If the button doesn't work, copy and paste this link into your browser:<br/>
              <a href="${inviteLink}" style="color: #666;">${inviteLink}</a>
            </p>
          </div>
        </div>
      `,
      text: `Hi ${recipientName}! You've been invited to join SSMS. ` +
            `Click here to create your account: ${inviteLink} ` +
            "This invitation expires in 7 days.",
    });
    /* eslint-enable max-len */

    logger.info(`Invite email sent successfully to ${email}`);
    return true;
  } catch (error) {
    logger.error(`Failed to send invite email to ${email}:`, error);
    return false;
  }
}

/**
 * Send a branded password reset email via Nodemailer
 * Falls back to Firebase's built-in reset if SMTP is not configured
 * @param {string} email - The recipient email address
 * @param {string} resetLink - The Firebase password reset link
 * @param {string} displayName - User's display name (optional)
 * @return {Promise<boolean>} True if email was sent
 */
async function sendPasswordResetMail(
  email: string,
  resetLink: string,
  displayName?: string
): Promise<boolean> {
  const transporter = getMailTransporter();
  if (!transporter) {
    logger.info(
      "SMTP not configured — Firebase default reset " +
      "email will be used instead."
    );
    return false;
  }

  const senderEmail = process.env.SMTP_USER || "noreply@ssms.app";
  const recipientName = displayName || "there";

  try {
    /* eslint-disable max-len */
    await transporter.sendMail({
      from: `"SSMS" <${senderEmail}>`,
      to: email,
      subject: "Reset Your SSMS Password",
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background-color: #000; color: #fff; padding: 24px; text-align: center;">
            <h1 style="margin: 0; font-size: 24px;">Scheduling &amp; Stakeholder Management</h1>
          </div>
          <div style="padding: 32px 24px;">
            <h2 style="color: #333;">Hi ${recipientName}!</h2>
            <p style="color: #555; font-size: 16px; line-height: 1.6;">
              We received a request to reset your password. Click the button
              below to choose a new password.
            </p>
            <div style="text-align: center; margin: 32px 0;">
              <a href="${resetLink}"
                 style="background-color: #000; color: #fff; padding: 14px 32px;
                        text-decoration: none; border-radius: 8px; font-size: 16px;
                        font-weight: 600; display: inline-block;">
                Reset Password
              </a>
            </div>
            <p style="color: #888; font-size: 13px;">
              This link expires in 1 hour. If you didn&rsquo;t request a password
              reset, you can safely ignore this email.
            </p>
            <hr style="border: none; border-top: 1px solid #eee; margin: 24px 0;" />
            <p style="color: #999; font-size: 12px;">
              If the button doesn&rsquo;t work, copy and paste this link:<br/>
              <a href="${resetLink}" style="color: #666;">${resetLink}</a>
            </p>
          </div>
        </div>
      `,
      text: `Hi ${recipientName}! ` +
            "We received a request to reset your password. " +
            `Click here to reset it: ${resetLink} ` +
            "This link expires in 1 hour.",
    });
    /* eslint-enable max-len */

    logger.info(`Password reset email sent to ${email}`);
    return true;
  } catch (error) {
    logger.error(
      `Failed to send reset email to ${email}:`, error
    );
    return false;
  }
}

/**
 * Send a welcome / onboarding confirmation email
 * @param {string} email - The recipient email address
 * @param {string} displayName - User's display name
 * @return {Promise<boolean>} True if email was sent
 */
async function sendWelcomeEmail(
  email: string,
  displayName?: string
): Promise<boolean> {
  const transporter = getMailTransporter();
  if (!transporter) {
    logger.info(
      "Welcome email skipped (SMTP not configured)."
    );
    return false;
  }

  const senderEmail = process.env.SMTP_USER || "noreply@ssms.app";
  const name = displayName || "there";

  try {
    /* eslint-disable max-len */
    await transporter.sendMail({
      from: `"SSMS" <${senderEmail}>`,
      to: email,
      subject: "Welcome to SSMS!",
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background-color: #000; color: #fff; padding: 24px; text-align: center;">
            <h1 style="margin: 0; font-size: 24px;">Scheduling &amp; Stakeholder Management</h1>
          </div>
          <div style="padding: 32px 24px;">
            <h2 style="color: #333;">Welcome, ${name}!</h2>
            <p style="color: #555; font-size: 16px; line-height: 1.6;">
              Your account has been set up successfully. You now have full
              access to the Scheduling &amp; Stakeholder Management System.
            </p>
            <div style="background-color: #f9f9f9; border-radius: 8px; padding: 20px; margin: 24px 0;">
              <h3 style="margin: 0 0 12px; color: #333;">Getting Started</h3>
              <ul style="color: #555; font-size: 14px; line-height: 1.8; padding-left: 20px;">
                <li>Create and manage events from your dashboard</li>
                <li>View your assigned events and stakeholders</li>
                <li>Get real-time notifications for updates</li>
              </ul>
            </div>
            <p style="color: #888; font-size: 13px;">
              If you have any questions, reach out to your organization admin.
            </p>
          </div>
        </div>
      `,
      text: `Welcome, ${name}! Your SSMS account is ready. ` +
            "You can now create events, manage stakeholders, " +
            "and receive real-time notifications.",
    });
    /* eslint-enable max-len */

    logger.info(`Welcome email sent to ${email}`);
    return true;
  } catch (error) {
    logger.error(
      `Failed to send welcome email to ${email}:`, error
    );
    return false;
  }
}


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
        .where("ownerId", "==", userId)
        .get();

      eventsSnapshot.docs.forEach((doc) => {
        batch.update(doc.ref, {
          ownerId: null,
          ownerName: "Deleted User",
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
        for (const stakeholderId of eventData.stakeholderIds) {
          // Look up stakeholder to find their linked userId
          const stakeholderDoc = await admin
            .firestore()
            .collection("stakeholders")
            .doc(stakeholderId)
            .get();
          const stakeholder = stakeholderDoc.data();
          const linkedUserId = stakeholder?.linkedUserId;

          if (linkedUserId) {
            // Send push + in-app notification to linked user
            await sendPushAndInAppNotification(
              linkedUserId,
              "New Event Assigned",
              `You've been assigned to: ${eventData.title}`,
              "event_assignment",
              eventId
            );
          } else {
            // Stakeholder has no account — create in-app
            // notification under stakeholder ID for later
            await admin
              .firestore()
              .collection("notifications")
              .add({
                userId: stakeholderId,
                title: "New Event Assigned",
                body: "You've been assigned to: " +
                  `${eventData.title}`,
                createdAt: admin.firestore.FieldValue
                  .serverTimestamp(),
                isRead: false,
                type: "event_assignment",
                eventId: eventId,
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

export const createEvent = onCall(async (request) => {
  const {
    title, description, startTime, endTime, location,
    ownerId, ownerName, status, priority, stakeholderIds,
    recurrenceRule, metadata,
  } = request.data;

  if (!title || !startTime || !ownerId) {
    throw new HttpsError(
      "invalid-argument",
      "Title, start time, and owner ID are required."
    );
  }

  // Validate title length
  if (title.length < 3 || title.length > 100) {
    throw new HttpsError(
      "invalid-argument",
      "Title must be between 3 and 100 characters."
    );
  }

  // Validate time range
  if (endTime) {
    const start = new Date(startTime);
    const end = new Date(endTime);
    if (end <= start) {
      throw new HttpsError(
        "invalid-argument",
        "End time must be after start time."
      );
    }
    const diffMs = end.getTime() - start.getTime();
    if (diffMs < 5 * 60 * 1000) {
      throw new HttpsError(
        "invalid-argument",
        "Event must be at least 5 minutes long."
      );
    }
    if (diffMs > 30 * 24 * 60 * 60 * 1000) {
      throw new HttpsError(
        "invalid-argument",
        "Event cannot be longer than 30 days."
      );
    }
  }

  try {
    // Build location object matching Flutter EventLocation model
    const eventLocation = location && typeof location === "object" ?
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
      startTime: startTime,
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

/**
 * Get all events for the authenticated user
 * Returns events where ownerId matches the caller's UID
 */
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

    const events = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    logger.info(`Events retrieved for user: ${callerUid}`, {
      count: events.length,
    });
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
    // Verify ownership
    const eventDoc = await admin
      .firestore()
      .collection("events")
      .doc(id)
      .get();

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

    // Validate title if provided
    if (title !== undefined) {
      if (title.length < 3 || title.length > 100) {
        throw new HttpsError(
          "invalid-argument",
          "Title must be between 3 and 100 characters."
        );
      }
    }

    const updateData: Record<string, unknown> = {
      updatedAt: new Date().toISOString(),
    };

    if (title !== undefined) updateData.title = title;
    if (description !== undefined) updateData.description = description;
    if (startTime !== undefined) updateData.startTime = startTime;
    if (endTime !== undefined) updateData.endTime = endTime;
    if (ownerName !== undefined) updateData.ownerName = ownerName;
    if (status !== undefined) updateData.status = status;
    if (priority !== undefined) updateData.priority = priority;
    if (stakeholderIds !== undefined) {
      updateData.stakeholderIds = stakeholderIds;
    }
    if (recurrenceRule !== undefined) {
      updateData.recurrenceRule = recurrenceRule;
    }
    if (metadata !== undefined) updateData.metadata = metadata;

    // Handle location as object (matching Flutter EventLocation model)
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
          address: null,
          latitude: null,
          longitude: null,
          isVirtual: false,
          virtualLink: null,
        };
      }
    }

    // Validate time range if both times are provided
    const finalStart = (startTime || existingData?.startTime) as string;
    const finalEnd = (endTime || existingData?.endTime) as string;
    if (finalStart && finalEnd) {
      const start = new Date(finalStart);
      const end = new Date(finalEnd);
      if (end <= start) {
        throw new HttpsError(
          "invalid-argument",
          "End time must be after start time."
        );
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
    // Verify ownership
    const eventDoc = await admin
      .firestore()
      .collection("events")
      .doc(id)
      .get();

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

    // Delete the event
    batch.delete(admin.firestore().collection("events").doc(id));

    // Clean up associated eventStakeholder relationships
    const eventStakeholders = await admin
      .firestore()
      .collection("eventStakeholders")
      .where("eventId", "==", id)
      .get();

    eventStakeholders.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });

    // Remove event from stakeholders' eventIds arrays
    if (eventData?.stakeholderIds && eventData.stakeholderIds.length > 0) {
      for (const stakeholderId of eventData.stakeholderIds) {
        const stakeholderRef = admin
          .firestore()
          .collection("stakeholders")
          .doc(stakeholderId);
        batch.update(stakeholderRef, {
          eventIds: admin.firestore.FieldValue.arrayRemove(id),
        });
      }
    }

    // Delete related notifications
    const notifications = await admin
      .firestore()
      .collection("notifications")
      .where("eventId", "==", id)
      .get();

    notifications.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });

    await batch.commit();

    logger.info(`Event deleted: ${id}`);
    return {success: true};
  } catch (error) {
    if (error instanceof HttpsError) throw error;
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

    // Send invite email
    const emailSent = await sendInviteEmail(
      stakeholderData.email,
      inviteToken,
      stakeholderData.name || stakeholderData.displayName
    );

    return {
      success: true,
      inviteToken: inviteToken,
      email: stakeholderData.email,
      emailSent: emailSent,
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
  const {userId, token, inviteToken} = request.data;
  // Accept both 'token' and 'inviteToken' for backwards compat
  const resolvedToken = token || inviteToken;

  if (!userId) {
    throw new HttpsError(
      "invalid-argument",
      "User ID is required."
    );
  }

  if (!resolvedToken) {
    throw new HttpsError(
      "invalid-argument",
      "Invite token is required."
    );
  }

  try {
    // Look up stakeholder from the invite token
    const inviteDoc = await admin
      .firestore()
      .collection("invites")
      .doc(resolvedToken)
      .get();

    if (!inviteDoc.exists) {
      throw new HttpsError(
        "not-found",
        "Invite token not found."
      );
    }

    const inviteData = inviteDoc.data();
    if (!inviteData) {
      throw new HttpsError(
        "internal",
        "Invite data is empty."
      );
    }

    if (inviteData.used) {
      throw new HttpsError(
        "already-exists",
        "This invite has already been used."
      );
    }

    const expiresAt = inviteData.expiresAt?.toDate();
    if (expiresAt && new Date() > expiresAt) {
      throw new HttpsError(
        "deadline-exceeded",
        "This invite has expired."
      );
    }

    const stakeholderId = inviteData.stakeholderId;
    const defaultRole = inviteData.defaultRole || "member";

    if (!stakeholderId) {
      throw new HttpsError(
        "internal",
        "Invite is missing stakeholder ID."
      );
    }

    const batch = admin.firestore().batch();

    // Mark invite as used
    batch.update(inviteDoc.ref, {
      used: true,
      usedAt: admin.firestore.FieldValue.serverTimestamp(),
      usedByUserId: userId,
    });

    // Update user with stakeholder link
    const userRef = admin
      .firestore().collection("users").doc(userId);
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

    // Send acceptance notification to the stakeholder
    const stakeholderDoc = await stakeholderRef.get();
    const stakeholderData = stakeholderDoc.data();
    if (stakeholderData) {
      // Notify the user who sent the invite (if known)
      const userDoc = await userRef.get();
      const userData = userDoc.data();
      await admin.firestore().collection("notifications").add({
        userId: userId,
        title: "Account Linked!",
        body: "Your account has been linked to your " +
          "stakeholder profile. Welcome aboard!",
        type: "invite_accepted",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
      });

      // Send welcome email to newly linked user
      if (userData?.email) {
        await sendWelcomeEmail(
          userData.email,
          userData.displayName
        );
      }
    }

    logger.info(
      `User ${userId} linked to stakeholder ${stakeholderId}`
    );
    return {success: true, role: defaultRole};
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error(
      "Error linking user to stakeholder:", error
    );
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

// =============================================================================
// FCM PUSH NOTIFICATION HELPER
// =============================================================================

/**
 * Send a push notification via FCM to a specific user.
 * Looks up the user's fcmTokens array and sends to all registered devices.
 * Also creates a Firestore notification document for in-app display.
 *
 * @param {string} userId - Target user ID
 * @param {string} title - Notification title
 * @param {string} body - Notification body text
 * @param {string} type - Notification type (welcome, event_reminder, etc.)
 * @param {string | null} eventId - Related event ID (for navigation)
 * @param {Record<string, string>} extraData - Additional payload data
 */
async function sendPushAndInAppNotification(
  userId: string,
  title: string,
  body: string,
  type = "general",
  eventId: string | null = null,
  extraData: Record<string, string> = {}
): Promise<void> {
  // 1. Create Firestore in-app notification
  await admin.firestore().collection("notifications").add({
    userId,
    title,
    body,
    type,
    eventId: eventId || null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    isRead: false,
  });

  // 2. Send FCM push notification
  try {
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .get();
    const userData = userDoc.data();
    const fcmTokens: string[] = userData?.fcmTokens || [];

    if (fcmTokens.length === 0) {
      logger.info(
        `No FCM tokens for user ${userId}, ` +
        "skipping push notification."
      );
      return;
    }

    // Build FCM message payload
    const dataPayload: Record<string, string> = {
      type,
      ...extraData,
    };
    if (eventId) {
      dataPayload.eventId = eventId;
    }

    // Send to all registered devices
    const invalidTokens: string[] = [];
    for (const token of fcmTokens) {
      try {
        await admin.messaging().send({
          token,
          notification: {title, body},
          data: dataPayload,
          android: {
            priority: type === "event_reminder" ?
              "high" : "normal",
            notification: {
              channelId: type === "event_reminder" ?
                "ssms_reminders" : "ssms_notifications",
              priority: type === "event_reminder" ?
                "high" : "default",
            },
          },
          apns: {
            payload: {
              aps: {
                alert: {title, body},
                badge: 1,
                sound: "default",
              },
            },
          },
        });
      } catch (tokenError: unknown) {
        const errMsg = tokenError instanceof Error ?
          tokenError.message : String(tokenError);
        // Remove invalid tokens
        if (
          errMsg.includes("not-registered") ||
          errMsg.includes("invalid-registration-token") ||
          errMsg.includes("registration-token-not-registered")
        ) {
          invalidTokens.push(token);
        }
        logger.warn(
          `FCM send failed for token: ${errMsg}`
        );
      }
    }

    // Clean up invalid tokens
    if (invalidTokens.length > 0) {
      await admin
        .firestore()
        .collection("users")
        .doc(userId)
        .update({
          fcmTokens:
            admin.firestore.FieldValue.arrayRemove(
              invalidTokens
            ),
        });
      logger.info(
        `Removed ${invalidTokens.length} ` +
        `invalid FCM token(s) for user ${userId}.`
      );
    }
  } catch (error) {
    logger.error(
      `Error sending FCM to user ${userId}:`,
      error
    );
    // Non-critical: in-app notification was already created
  }
}

export const sendNotification = onCall(async (request) => {
  // Require authentication
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication required."
    );
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
      userId,
      title,
      body,
      type || "general",
      eventId || null
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

// =============================================================================
// FCM TOKEN MANAGEMENT
// =============================================================================

/**
 * Save an FCM token for the authenticated user.
 * Called from the Flutter app when FCM is initialized or token refreshes.
 */
export const saveFcmToken = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication required."
    );
  }

  const {token} = request.data;
  if (!token) {
    throw new HttpsError(
      "invalid-argument",
      "FCM token is required."
    );
  }

  try {
    await admin
      .firestore()
      .collection("users")
      .doc(callerUid)
      .update({
        fcmTokens:
          admin.firestore.FieldValue.arrayUnion([token]),
        lastTokenUpdate:
          admin.firestore.FieldValue.serverTimestamp(),
      });

    logger.info(`FCM token saved for user: ${callerUid}`);
    return {success: true};
  } catch (error) {
    logger.error("Error saving FCM token:", error);
    throw new HttpsError(
      "internal",
      "Error saving FCM token.",
      error
    );
  }
});

/**
 * Remove an FCM token on logout so the user stops
 * receiving push notifications on that device.
 */
export const removeFcmToken = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication required."
    );
  }

  const {token} = request.data;
  if (!token) {
    throw new HttpsError(
      "invalid-argument",
      "FCM token is required."
    );
  }

  try {
    await admin
      .firestore()
      .collection("users")
      .doc(callerUid)
      .update({
        fcmTokens:
          admin.firestore.FieldValue.arrayRemove([token]),
      });

    logger.info(
      `FCM token removed for user: ${callerUid}`
    );
    return {success: true};
  } catch (error) {
    logger.error("Error removing FCM token:", error);
    throw new HttpsError(
      "internal",
      "Error removing FCM token.",
      error
    );
  }
});

// =============================================================================
// SCHEDULED: EVENT REMINDERS (every 15 minutes)
// =============================================================================

/**
 * Runs every 15 minutes to check for upcoming events
 * and send reminder notifications to assigned stakeholders.
 *
 * Reminder windows:
 *  - 24 hours before (1440 minutes)
 *  - 1 hour before (60 minutes)
 *  - 15 minutes before
 *
 * Uses a `remindersSent` map on the event doc to avoid
 * duplicate reminders.
 */
export const sendEventReminders = onSchedule(
  "every 15 minutes",
  async () => {
    try {
      const now = new Date();

      // Define reminder windows
      const windows = [
        {key: "reminder_1440", minutesBefore: 1440,
          label: "24 hours"},
        {key: "reminder_60", minutesBefore: 60,
          label: "1 hour"},
        {key: "reminder_15", minutesBefore: 15,
          label: "15 minutes"},
      ];

      // For each window, find events that fall within
      // the window and haven't been reminded yet
      for (const window of windows) {
        const targetStart = new Date(
          now.getTime() + window.minutesBefore * 60 * 1000
        );
        const targetEnd = new Date(
          targetStart.getTime() + 15 * 60 * 1000
        );

        // Query events starting within this window
        const eventsSnapshot = await admin
          .firestore()
          .collection("events")
          .where("status", "in", [
            "scheduled", "draft",
          ])
          .where(
            "startTime",
            ">=",
            targetStart.toISOString()
          )
          .where(
            "startTime",
            "<",
            targetEnd.toISOString()
          )
          .get();

        for (const eventDoc of eventsSnapshot.docs) {
          const eventData = eventDoc.data();
          const remindersSent =
            eventData.remindersSent || {};

          // Skip if this reminder was already sent
          if (remindersSent[window.key]) continue;

          const stakeholderIds: string[] =
            eventData.stakeholderIds || [];

          if (stakeholderIds.length === 0) continue;

          // Send reminder to each stakeholder
          for (const shId of stakeholderIds) {
            // Look up linked user
            const shDoc = await admin
              .firestore()
              .collection("stakeholders")
              .doc(shId)
              .get();
            const shData = shDoc.data();
            const linkedUserId = shData?.linkedUserId;

            if (linkedUserId) {
              await sendPushAndInAppNotification(
                linkedUserId,
                `Event in ${window.label}`,
                `"${eventData.title}" starts in ` +
                `${window.label}.`,
                "event_reminder",
                eventDoc.id
              );
            }
          }

          // Also notify the event owner
          if (eventData.ownerId) {
            await sendPushAndInAppNotification(
              eventData.ownerId,
              `Event in ${window.label}`,
              `"${eventData.title}" starts in ` +
              `${window.label}.`,
              "event_reminder",
              eventDoc.id
            );
          }

          // Mark this reminder window as sent
          await eventDoc.ref.update({
            [`remindersSent.${window.key}`]: true,
          });

          logger.info(
            `Reminder (${window.label}) sent for ` +
            `event: ${eventDoc.id}`
          );
        }
      }
    } catch (error) {
      logger.error(
        "Error sending event reminders:", error
      );
    }
  }
);

// =============================================================================
// EVENT UPDATE NOTIFICATION
// =============================================================================

/**
 * Notify all stakeholders when an event is updated
 * (time change, reschedule, etc.).
 */
export const notifyEventUpdate = onCall(
  async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication required."
      );
    }

    const {eventId, changeDescription} = request.data;

    if (!eventId) {
      throw new HttpsError(
        "invalid-argument",
        "Event ID is required."
      );
    }

    try {
      const eventDoc = await admin
        .firestore()
        .collection("events")
        .doc(eventId)
        .get();

      if (!eventDoc.exists) {
        throw new HttpsError(
          "not-found",
          "Event not found."
        );
      }

      const eventData = eventDoc.data();
      if (!eventData) {
        throw new HttpsError(
          "internal",
          "Event data is empty."
        );
      }

      const stakeholderIds: string[] =
        eventData.stakeholderIds || [];
      const description = changeDescription ||
        "Event details have been updated.";

      let notified = 0;

      for (const shId of stakeholderIds) {
        const shDoc = await admin
          .firestore()
          .collection("stakeholders")
          .doc(shId)
          .get();
        const shData = shDoc.data();
        const linkedUserId = shData?.linkedUserId;

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

      // Also notify the owner if caller is not the owner
      if (
        eventData.ownerId &&
        eventData.ownerId !== callerUid
      ) {
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
        "Event update notification sent to " +
        `${notified} user(s) for event: ${eventId}`
      );
      return {success: true, notifiedCount: notified};
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      logger.error(
        "Error sending event update notification:",
        error
      );
      throw new HttpsError(
        "internal",
        "Error sending event update notification.",
        error
      );
    }
  }
);

// =============================================================================
// PASSWORD RESET (BRANDED EMAIL)
// =============================================================================

/**
 * Send a branded password reset email using Nodemailer.
 * Generates a Firebase Auth password reset link and wraps it
 * in a styled HTML email. Falls back to Firebase default email
 * if SMTP is not configured.
 */
export const requestPasswordReset = onCall(async (request) => {
  const {email} = request.data;

  if (!email) {
    throw new HttpsError(
      "invalid-argument",
      "Email is required."
    );
  }

  try {
    // Generate the Firebase Auth password reset link
    const resetLink = await admin
      .auth()
      .generatePasswordResetLink(email);

    // Look up user display name for personalisation
    let displayName: string | undefined;
    try {
      const userRecord = await admin.auth().getUserByEmail(email);
      displayName = userRecord.displayName || undefined;
    } catch {
      // User may not exist — still send the email; Firebase
      // link will handle invalid accounts gracefully.
    }

    // Attempt branded email via Nodemailer
    const sent = await sendPasswordResetMail(
      email,
      resetLink,
      displayName
    );

    if (!sent) {
      // SMTP not configured — fall back to Firebase default
      await admin
        .auth()
        .generatePasswordResetLink(email);
      // Firebase will send its default reset email
      // when the client calls sendPasswordResetEmail
    }

    logger.info(`Password reset requested for ${email}`);
    return {success: true, emailSent: sent};
  } catch (error) {
    // Don't reveal whether the email exists
    logger.error("Error in password reset:", error);
    return {success: true, emailSent: false};
  }
});

// =============================================================================
// RESEND STAKEHOLDER INVITE
// =============================================================================

/**
 * Resend an invitation to a stakeholder.
 * Generates a fresh token, updates the invite, and sends
 * a new email. Requires authentication.
 */
export const resendInvite = onCall(async (request) => {
  const {stakeholderId} = request.data;
  const callerUid = request.auth?.uid;

  if (!callerUid) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication required."
    );
  }

  if (!stakeholderId) {
    throw new HttpsError(
      "invalid-argument",
      "Stakeholder ID is required."
    );
  }

  try {
    // Verify caller has invite permission
    const canInvite = await hasPermission(
      callerUid,
      PERMISSIONS.inviteStakeholder
    );
    if (!canInvite) {
      throw new HttpsError(
        "permission-denied",
        "You don't have permission to invite stakeholders."
      );
    }

    const stakeholderRef = admin
      .firestore()
      .collection("stakeholders")
      .doc(stakeholderId);
    const stakeholderDoc = await stakeholderRef.get();

    if (!stakeholderDoc.exists) {
      throw new HttpsError(
        "not-found",
        "Stakeholder not found."
      );
    }

    const stakeholderData = stakeholderDoc.data();
    if (!stakeholderData) {
      throw new HttpsError(
        "internal",
        "Stakeholder data is empty."
      );
    }

    if (stakeholderData.linkedUserId) {
      throw new HttpsError(
        "already-exists",
        "Stakeholder already has a linked account."
      );
    }

    // Expire old invite if it exists
    const oldToken = stakeholderData.inviteToken;
    if (oldToken) {
      const oldInviteRef = admin
        .firestore()
        .collection("invites")
        .doc(oldToken);
      const oldInviteDoc = await oldInviteRef.get();
      if (oldInviteDoc.exists) {
        await oldInviteRef.update({
          used: true,
          replacedAt:
            admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    // Generate fresh invite token
    const newToken = admin
      .firestore().collection("_temp").doc().id;

    // Update stakeholder
    await stakeholderRef.update({
      inviteStatus: "pending",
      invitedAt:
        admin.firestore.FieldValue.serverTimestamp(),
      inviteToken: newToken,
      updatedAt:
        admin.firestore.FieldValue.serverTimestamp(),
    });

    // Create new invite document
    await admin
      .firestore()
      .collection("invites")
      .doc(newToken)
      .set({
        stakeholderId: stakeholderId,
        email: stakeholderData.email,
        defaultRole:
          stakeholderData.defaultRole || "member",
        createdAt:
          admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
        ),
        used: false,
        resentBy: callerUid,
      });

    // Send email
    const emailSent = await sendInviteEmail(
      stakeholderData.email,
      newToken,
      stakeholderData.name || stakeholderData.displayName
    );

    logger.info(
      `Invite resent to stakeholder: ${stakeholderId}`
    );
    return {
      success: true,
      inviteToken: newToken,
      email: stakeholderData.email,
      emailSent,
    };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("Error resending invite:", error);
    throw new HttpsError(
      "internal",
      "Error resending invite.",
      error
    );
  }
});

// =============================================================================
// SCHEDULED: CLEANUP EXPIRED INVITES
// =============================================================================

/**
 * Runs daily to mark expired invites.
 * Updates invite documents and corresponding stakeholder
 * records so the UI shows accurate status.
 */
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
        // Mark invite as expired
        batch.update(doc.ref, {
          used: true,
          expiredAt:
            admin.firestore.FieldValue.serverTimestamp(),
        });

        // Update stakeholder invite status
        if (data.stakeholderId) {
          const stakeholderRef = admin
            .firestore()
            .collection("stakeholders")
            .doc(data.stakeholderId);
          batch.update(stakeholderRef, {
            inviteStatus: "expired",
            updatedAt:
              admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        count++;
      }

      await batch.commit();
      logger.info(
        `Cleaned up ${count} expired invite(s).`
      );
    } catch (error) {
      logger.error(
        "Error cleaning up expired invites:", error
      );
    }
  }
);

// =============================================================================
// ONBOARDING COMPLETE — SEND WELCOME EMAIL
// =============================================================================

/**
 * Callable function: triggered after completing onboarding
 * to send a branded welcome email.
 */
export const onOnboardingComplete = onCall(
  async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication required."
      );
    }

    try {
      const userDoc = await admin
        .firestore()
        .collection("users")
        .doc(callerUid)
        .get();
      const userData = userDoc.data();

      if (userData?.email) {
        await sendWelcomeEmail(
          userData.email,
          userData.displayName
        );
      }

      return {success: true};
    } catch (error) {
      logger.error(
        "Error sending welcome email:", error
      );
      // Non-critical — don't throw
      return {success: false};
    }
  }
);

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
      PERMISSIONS.createStakeholder,
      PERMISSIONS.editStakeholder,
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

// ============================================================================
// CONFIGURATION / SECRETS
// ============================================================================

/**
 * Get application configuration/secrets
 * Only authenticated users can access this
 * Secrets are stored in Firebase Functions secrets
 */
export const getAppConfig = onCall(
  {secrets: ["GOOGLE_MAPS_API_KEY"]},
  async (request) => {
    // Require authentication
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    try {
      // Return configuration from environment secrets
      return {
        googleMapsApiKey: process.env.GOOGLE_MAPS_API_KEY || "",
      };
    } catch (error) {
      logger.error("Error fetching app config:", error);
      throw new HttpsError("internal", "Failed to fetch configuration");
    }
  }
);
