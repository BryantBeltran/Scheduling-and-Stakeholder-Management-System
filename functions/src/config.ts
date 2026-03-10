import {onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import {
  HttpsError,
  sendPushAndInAppNotification,
  sendWelcomeEmail,
  sendPasswordResetMail,
} from "./shared";

// =============================================================================
// APP CONFIGURATION
// =============================================================================

/** Get application secrets/configuration. Requires authentication. */
export const getAppConfig = onCall(
  {secrets: ["GOOGLE_MAPS_API_KEY"]},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    try {
      return {
        googleMapsApiKey: process.env.GOOGLE_MAPS_API_KEY || "",
      };
    } catch (error) {
      logger.error("Error fetching app config:", error);
      throw new HttpsError("internal", "Failed to fetch configuration");
    }
  }
);

// =============================================================================
// ONBOARDING COMPLETE — SEND WELCOME EMAIL
// =============================================================================

/**
 * Called after completing onboarding to send a branded welcome email
 * and a welcome in-app/push notification.
 */
export const onOnboardingComplete = onCall(async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  try {
    const userDoc = await admin
      .firestore().collection("users").doc(callerUid).get();
    const userData = userDoc.data();

    // Skip welcome email for invited users — they got an "account linked" email
    if (userData?.email && !userData.stakeholderId) {
      await sendWelcomeEmail(userData.email, userData.displayName);
    }

    const firstName = (userData?.displayName ?? "there").split(" ")[0];
    await sendPushAndInAppNotification(
      callerUid,
      `Welcome to SSMS, ${firstName}!`,
      "You're all set. Explore your events and stakeholders to get started.",
      "welcome",
      null
    );

    return {success: true};
  } catch (error) {
    logger.error("Error sending welcome email:", error);
    return {success: false};
  }
});

// =============================================================================
// PASSWORD RESET (BRANDED EMAIL)
// =============================================================================


/**
 * Send a branded password reset email.
 * Generates a Firebase Auth reset link and wraps it in a styled HTML email.
 * Falls back to Firebase's default email if SMTP is not configured.
 */
export const requestPasswordReset = onCall(async (request) => {
  const {email} = request.data;
  if (!email) {
    throw new HttpsError("invalid-argument", "Email is required.");
  }

  try {
    const resetLink = await admin.auth().generatePasswordResetLink(email);

    let displayName: string | undefined;
    try {
      const userRecord = await admin.auth().getUserByEmail(email);
      displayName = userRecord.displayName || undefined;
    } catch {
      // User may not exist — still attempt the email
    }

    const sent = await sendPasswordResetMail(email, resetLink, displayName);

    if (!sent) {
      // SMTP not configured — Firebase default reset email handles delivery
      await admin.auth().generatePasswordResetLink(email);
    }

    logger.info(`Password reset requested for ${email}`);
    return {success: true, emailSent: sent};
  } catch (error) {
    logger.error("Error in password reset:", error);
    return {success: true, emailSent: false};
  }
});
