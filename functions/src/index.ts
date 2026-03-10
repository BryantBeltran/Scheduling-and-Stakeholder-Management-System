import {setGlobalOptions} from "firebase-functions/v2";
import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK (must happen before any module imports)
admin.initializeApp();

// For cost control, set maximum concurrent instances
// SMTP credentials injected from Firebase Secret Manager
setGlobalOptions({
  maxInstances: 10,
  secrets: ["SMTP_HOST", "SMTP_PORT", "SMTP_USER", "SMTP_PASS", "SMTP_FROM"],
});

// =============================================================================
// RE-EXPORTS — each domain in its own module
// =============================================================================

export {
  onUserCreated,
  onUserDeleted,
  createUser,
  getUser,
  getAllUsers,
  updateUserRole,
  setUserActiveStatus,
  updateUser,
  deleteUser,
} from "./users";

export {
  onEventCreated,
  createEvent,
  getEvent,
  getAllEvents,
  updateEvent,
  deleteEvent,
  notifyEventUpdate,
} from "./events";

export {
  createStakeholder,
  getStakeholder,
  updateStakeholder,
  deleteStakeholder,
  inviteStakeholder,
  validateInviteToken,
  linkUserToStakeholder,
  resendInvite,
  addStakeholderToEvent,
  removeStakeholderFromEvent,
} from "./stakeholders";

export {
  sendNotification,
  getNotifications,
  markNotificationAsRead,
  saveFcmToken,
  removeFcmToken,
  sendEventReminders,
  cleanupExpiredInvites,
  sendTestNotification,
} from "./notifications";

export {
  getAppConfig,
  onOnboardingComplete,
  requestPasswordReset,
} from "./config";

// Shared helpers exported for use by the Firebase Admin SDK itself
// (e.g. in integration tests or admin tooling)
export {
  hasPermission,
  isValidRole,
  getDefaultPermissions,
  PERMISSIONS,
} from "./shared";
