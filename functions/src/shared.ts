import {HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import * as nodemailer from "nodemailer";

const INVITE_BASE_URL =
  process.env.INVITE_BASE_URL || "https://managemateapp.me";

// ---------------------------------------------------------------------------
// ROLES & PERMISSIONS
// ---------------------------------------------------------------------------

export const VALID_ROLES = [
  "admin", "manager", "member", "viewer",
] as const;
export type UserRole = typeof VALID_ROLES[number];

export const PERMISSIONS = {
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
 * Get default permissions for a given user role.
 * Must match Flutter UserModel.getDefaultPermissions().
 * @param {string} role - The user role
 * @return {string[]} Array of permission strings
 */
export function getDefaultPermissions(role: string): string[] {
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
  default:
    return [
      PERMISSIONS.viewEvent,
      PERMISSIONS.viewStakeholder,
    ];
  }
}

/**
 * Check if a role string is a valid UserRole.
 * @param {string} role - Role string to validate
 * @return {boolean} True if valid
 */
export function isValidRole(role: string): role is UserRole {
  return VALID_ROLES.includes(role as UserRole);
}

/**
 * Check if a user has a specific permission.
 * Admins and root users bypass all checks.
 * @param {string} userId - The user ID to check
 * @param {string} permission - The permission string
 * @return {Promise<boolean>} True if the user has the permission
 */
export async function hasPermission(
  userId: string,
  permission: string
): Promise<boolean> {
  try {
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .get();

    if (!userDoc.exists) return false;

    const userData = userDoc.data();
    const permissions: string[] = userData?.permissions || [];

    if (
      userData?.role === "admin" ||
      permissions.includes(PERMISSIONS.admin) ||
      permissions.includes(PERMISSIONS.root)
    ) {
      return true;
    }

    return permissions.includes(permission);
  } catch (error) {
    logger.error(`Error checking permission for user ${userId}:`, error);
    return false;
  }
}

// ---------------------------------------------------------------------------
// EMAIL HELPERS
// ---------------------------------------------------------------------------

/**
 * Create a Nodemailer transporter from SMTP environment variables.
 * Returns null if SMTP is not fully configured.
 * @return {nodemailer.Transporter | null} Transporter or null
 */
export function getMailTransporter(): nodemailer.Transporter | null {
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
    auth: {user: smtpUser, pass: smtpPass},
  });
}

/**
 * Send an invite email to a stakeholder.
 * @param {string} email - Recipient email address
 * @param {string} inviteToken - Unique invite token
 * @param {string} stakeholderName - Stakeholder name (optional)
 * @return {Promise<boolean>} True if email was sent
 */
export async function sendInviteEmail(
  email: string,
  inviteToken: string,
  stakeholderName?: string
): Promise<boolean> {
  const transporter = getMailTransporter();
  if (!transporter) {
    logger.info(
      "Email sending skipped (SMTP not configured). " +
      `Invite link: ${INVITE_BASE_URL}/invite?token=${inviteToken}`
    );
    return false;
  }

  const senderEmail = process.env.SMTP_FROM || "no-reply@managemateapp.me";
  const recipientName = stakeholderName || "there";

  try {
    const deepLink = `${INVITE_BASE_URL}/invite?token=${inviteToken}`;
    /* eslint-disable max-len */
    await transporter.sendMail({
      from: `"SSMS" <${senderEmail}>`,
      to: email,
      subject: "You've been invited to SSMS",
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background-color: #000; color: #fff; padding: 24px; text-align: center;">
            <h1 style="margin: 0; font-size: 24px;">Scheduling &amp; Stakeholder Management</h1>
          </div>
          <div style="padding: 32px 24px;">
            <h2 style="color: #333;">Hi ${recipientName}!</h2>
            <p style="color: #555; font-size: 16px; line-height: 1.6;">
              You've been invited to join the Scheduling &amp; Stakeholder Management System.
              Tap the button below to open the app and get started.
            </p>
            <div style="text-align: center; margin: 32px 0;">
              <table role="presentation" cellpadding="0" cellspacing="0" style="margin: 0 auto;">
                <tr>
                  <td style="background-color: #000; border-radius: 8px; text-align: center;">
                    <a href="${deepLink}" target="_blank" style="display: inline-block; padding: 16px 40px; color: #ffffff; font-size: 16px; font-weight: 700; text-decoration: none; font-family: Arial, sans-serif;">Open SSMS &amp; Sign Up</a>
                  </td>
                </tr>
              </table>
            </div>
            <p style="color: #888; font-size: 13px; text-align: center; margin-bottom: 8px;">
              Or copy this link into your mobile browser:
            </p>
            <p style="text-align: center; margin-bottom: 24px;">
              <a href="${deepLink}" style="color: #555; font-size: 13px; word-break: break-all;">${deepLink}</a>
            </p>
            <p style="color: #888; font-size: 13px; margin-top: 24px;">
              This invite expires in 7 days. If you didn&rsquo;t expect this email,
              you can safely ignore it.
            </p>
          </div>
        </div>
      `,
      text: `Hi ${recipientName}! You've been invited to join SSMS. ` +
            `Tap this link to open the app: ${deepLink}\n\n` +
            "This invite expires in 7 days.",
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
 * Send a branded password reset email via Nodemailer.
 * @param {string} email - Recipient email address
 * @param {string} resetLink - Firebase password reset link
 * @param {string} displayName - User display name (optional)
 * @return {Promise<boolean>} True if email was sent
 */
export async function sendPasswordResetMail(
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

  const senderEmail = process.env.SMTP_FROM || "no-reply@managemateapp.me";
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
              We received a request to reset your password. Click the button below to choose a new password.
            </p>
            <div style="text-align: center; margin: 32px 0;">
              <a href="${resetLink}" style="background-color: #000; color: #fff; padding: 14px 32px; text-decoration: none; border-radius: 8px; font-size: 16px; font-weight: 600; display: inline-block;">
                Reset Password
              </a>
            </div>
            <p style="color: #888; font-size: 13px;">
              This link expires in 1 hour. If you didn&rsquo;t request a password reset, you can safely ignore this email.
            </p>
            <hr style="border: none; border-top: 1px solid #eee; margin: 24px 0;" />
            <p style="color: #999; font-size: 12px;">
              If the button doesn&rsquo;t work, copy and paste this link:<br/>
              <a href="${resetLink}" style="color: #666;">${resetLink}</a>
            </p>
          </div>
        </div>
      `,
      text: `Hi ${recipientName}! We received a request to reset your password. ` +
            `Click here to reset it: ${resetLink} This link expires in 1 hour.`,
    });
    /* eslint-enable max-len */
    logger.info(`Password reset email sent to ${email}`);
    return true;
  } catch (error) {
    logger.error(`Failed to send reset email to ${email}:`, error);
    return false;
  }
}

/**
 * Send a welcome/onboarding confirmation email.
 * @param {string} email - Recipient email address
 * @param {string} displayName - User display name (optional)
 * @return {Promise<boolean>} True if email was sent
 */
export async function sendWelcomeEmail(
  email: string,
  displayName?: string
): Promise<boolean> {
  const transporter = getMailTransporter();
  if (!transporter) {
    logger.info("Welcome email skipped (SMTP not configured).");
    return false;
  }

  const senderEmail = process.env.SMTP_FROM || "no-reply@managemateapp.me";
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
              Your account has been set up successfully. You now have full access to the Scheduling &amp; Stakeholder Management System.
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
    logger.error(`Failed to send welcome email to ${email}:`, error);
    return false;
  }
}

/**
 * Send an account-linked confirmation email to an invited user.
 * @param {string} email - Recipient email address
 * @param {string} displayName - User display name (optional)
 * @param {string} stakeholderName - Stakeholder profile name (optional)
 * @return {Promise<boolean>} True if email was sent
 */
export async function sendAccountLinkedEmail(
  email: string,
  displayName?: string,
  stakeholderName?: string
): Promise<boolean> {
  const transporter = getMailTransporter();
  if (!transporter) {
    logger.info("Account linked email skipped (SMTP not configured).");
    return false;
  }

  const senderEmail = process.env.SMTP_FROM || "no-reply@managemateapp.me";
  const name = displayName || "there";
  const profileName = stakeholderName || name;

  try {
    /* eslint-disable max-len */
    await transporter.sendMail({
      from: `"SSMS" <${senderEmail}>`,
      to: email,
      subject: "Your account has been linked — Welcome to SSMS!",
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background-color: #000; color: #fff; padding: 24px; text-align: center;">
            <h1 style="margin: 0; font-size: 24px;">Scheduling &amp; Stakeholder Management</h1>
          </div>
          <div style="padding: 32px 24px;">
            <h2 style="color: #333;">You're all set, ${name}!</h2>
            <p style="color: #555; font-size: 16px; line-height: 1.6;">
              Your account has been successfully linked to the stakeholder profile for <strong>${profileName}</strong>.
            </p>
            <div style="background-color: #f0faf4; border-left: 4px solid #22c55e; border-radius: 4px; padding: 16px; margin: 24px 0;">
              <p style="margin: 0; color: #166534; font-size: 14px;">
                You can now receive event invitations, view your assigned events, and collaborate with your team inside the app.
              </p>
            </div>
            <p style="color: #888; font-size: 13px;">
              If you didn't request this, please contact your organization admin.
            </p>
          </div>
        </div>
      `,
      text: `Hi ${name}, your SSMS account has been linked to the stakeholder profile for ${profileName}. You can now view assigned events and receive notifications.`,
    });
    /* eslint-enable max-len */
    logger.info(`Account linked email sent to ${email}`);
    return true;
  } catch (error) {
    logger.error(`Failed to send account linked email to ${email}:`, error);
    return false;
  }
}

/**
 * Send an event assignment notification email.
 * @param {string} email - Recipient email address
 * @param {string} recipientName - Recipient display name
 * @param {string} eventTitle - Event title
 * @param {string} role - Assignment role ("stakeholder" or "manager")
 * @param {string} startTime - Event start time (ISO string)
 * @return {Promise<boolean>} True if email was sent
 */
export async function sendEventAssignmentEmail(
  email: string,
  recipientName: string,
  eventTitle: string,
  role: "stakeholder" | "manager",
  startTime?: string
): Promise<boolean> {
  const transporter = getMailTransporter();
  if (!transporter) {
    logger.info("Event assignment email skipped (SMTP not configured).");
    return false;
  }

  const senderEmail = process.env.SMTP_FROM || "no-reply@managemateapp.me";
  const name = recipientName || "there";
  const roleLabel = role === "manager" ?
    "assigned as manager for" :
    "assigned to";
  const formattedDate = startTime ?
    new Date(startTime).toLocaleString("en-US", {
      weekday: "long", year: "numeric", month: "long",
      day: "numeric", hour: "numeric", minute: "2-digit",
    }) :
    null;

  try {
    /* eslint-disable max-len */
    await transporter.sendMail({
      from: `"SSMS" <${senderEmail}>`,
      to: email,
      subject: `You've been ${roleLabel}: ${eventTitle}`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background-color: #000; color: #fff; padding: 24px; text-align: center;">
            <h1 style="margin: 0; font-size: 24px;">Scheduling &amp; Stakeholder Management</h1>
          </div>
          <div style="padding: 32px 24px;">
            <h2 style="color: #333;">Hi ${name}!</h2>
            <p style="color: #555; font-size: 16px; line-height: 1.6;">
              You've been ${roleLabel} the event <strong>${eventTitle}</strong>.
            </p>
            ${formattedDate ? `
            <div style="background-color: #f0f4ff; border-left: 4px solid #3b82f6; border-radius: 4px; padding: 16px; margin: 24px 0;">
              <p style="margin: 0; color: #1e3a5f; font-size: 14px;">
                <strong>When:</strong> ${formattedDate}
              </p>
            </div>
            ` : ""}
            <p style="color: #555; font-size: 14px; line-height: 1.6;">
              Open the SSMS app to view event details and collaborate with your team.
            </p>
            <p style="color: #888; font-size: 13px; margin-top: 24px;">
              If you didn&rsquo;t expect this email, you can safely ignore it.
            </p>
          </div>
        </div>
      `,
      text: `Hi ${name}! You've been ${roleLabel} the event "${eventTitle}".${formattedDate ? ` When: ${formattedDate}.` : ""} Open the SSMS app for details.`,
    });
    /* eslint-enable max-len */
    logger.info(`Event assignment email sent to ${email}`);
    return true;
  } catch (error) {
    logger.error(`Failed to send event assignment email to ${email}:`, error);
    return false;
  }
}

// ---------------------------------------------------------------------------
// FCM + IN-APP NOTIFICATION HELPER
// ---------------------------------------------------------------------------

/**
 * Send a push notification via FCM and create a Firestore
 * in-app notification. Respects the user's notificationPreferences
 * (pushEnabled, eventRemindersEnabled, inviteNotificationsEnabled).
 * @param {string} userId - Target user ID
 * @param {string} title - Notification title
 * @param {string} body - Notification body text
 * @param {string} type - Notification type string
 * @param {string | null} eventId - Associated event ID or null
 * @param {Record<string, string>} extraData - Extra FCM data payload
 * @return {Promise<void>}
 */
export async function sendPushAndInAppNotification(
  userId: string,
  title: string,
  body: string,
  type = "general",
  eventId: string | null = null,
  extraData: Record<string, string> = {}
): Promise<void> {
  const userDoc = await admin
    .firestore()
    .collection("users")
    .doc(userId)
    .get();
  const userData = userDoc.data();
  const prefs =
    (userData?.notificationPreferences ?? {}) as Record<string, unknown>;

  // Respect type-specific preferences
  if (type === "event_reminder" && prefs.eventRemindersEnabled === false) {
    logger.info(`Event reminders disabled for user ${userId}, skipping.`);
    return;
  }
  if (
    ["event_assignment", "event_update"].includes(type) &&
    prefs.inviteNotificationsEnabled === false
  ) {
    logger.info(
      `Invite/event notifications disabled for user ${userId}, skipping.`
    );
    return;
  }

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

  // 2. Send FCM push notification (if push is enabled)
  if (prefs.pushEnabled === false) {
    logger.info(
      `Push notifications disabled for user ${userId}, skipping FCM.`
    );
    return;
  }

  try {
    const fcmTokens: string[] = userData?.fcmTokens || [];
    if (fcmTokens.length === 0) {
      logger.info(`No FCM tokens for user ${userId}, skipping push.`);
      return;
    }

    const dataPayload: Record<string, string> = {type, ...extraData};
    if (eventId) dataPayload.eventId = eventId;

    const invalidTokens: string[] = [];
    for (const token of fcmTokens) {
      try {
        await admin.messaging().send({
          token,
          notification: {title, body},
          data: dataPayload,
          android: {
            priority: type === "event_reminder" ? "high" : "normal",
            notification: {
              channelId: type === "event_reminder" ?
                "ssms_reminders" : "ssms_notifications",
              priority: type === "event_reminder" ? "high" : "default",
            },
          },
          apns: {
            payload: {aps: {alert: {title, body}, badge: 1, sound: "default"}},
          },
        });
      } catch (tokenError: unknown) {
        const errMsg = tokenError instanceof Error ?
          tokenError.message : String(tokenError);
        if (
          errMsg.includes("not-registered") ||
          errMsg.includes("invalid-registration-token") ||
          errMsg.includes("registration-token-not-registered")
        ) {
          invalidTokens.push(token);
        }
        logger.warn(`FCM send failed for token: ${errMsg}`);
      }
    }

    if (invalidTokens.length > 0) {
      await admin.firestore().collection("users").doc(userId).update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
      });
      logger.info(
        `Removed ${invalidTokens.length} invalid FCM token(s) for ${userId}.`
      );
    }
  } catch (error) {
    logger.error(`Error sending FCM to user ${userId}:`, error);
  }
}

// ---------------------------------------------------------------------------
// AUDIT LOG HELPER
// ---------------------------------------------------------------------------

/**
 * Write an audit log entry to the auditLogs Firestore collection.
 * @param {string} actorId - UID of the user who performed the action
 * @param {string} actorName - Display name of the actor
 * @param {string} action - Action type (create_event, delete_stakeholder, etc.)
 * @param {string} resourceType - Resource type (event, stakeholder, user)
 * @param {string | null} resourceId - ID of the affected resource
 * @param {string} description - Human-readable description
 * @return {Promise<void>}
 */
export async function writeAuditLog(
  actorId: string,
  actorName: string,
  action: string,
  resourceType: string,
  resourceId: string | null,
  description: string
): Promise<void> {
  try {
    await admin.firestore().collection("auditLogs").add({
      actorId,
      actorName,
      action,
      resourceType,
      resourceId: resourceId || null,
      description,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    logger.error("Failed to write audit log:", error);
  }
}

// Re-export HttpsError so modules can import it from shared
export {HttpsError};
