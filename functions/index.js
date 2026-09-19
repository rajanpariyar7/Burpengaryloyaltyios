/**
 * Sends an FCM push to every customer whenever an admin creates a doc in
 * the "notifications" collection from AdminNotificationsView.swift.
 *
 * WHY THIS HAS TO BE HERE AND NOT IN THE APP:
 * Sending a push via FCM requires your Firebase project's server
 * credentials (a service account / server key). Those must never ship
 * inside an iOS app — anyone could extract them from the binary and send
 * pushes to your entire user base as you. A Cloud Function runs on
 * Google's servers with those credentials kept server-side, which is the
 * supported way to do this.
 *
 * DEPLOY:
 *   cd functions && npm install firebase-admin firebase-functions
 *   firebase deploy --only functions
 *
 * (Requires the Firebase CLI and `firebase use <your-project-id>` first.)
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

exports.sendNotificationOnCreate = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const notification = snap.data();
    const db = getFirestore();
    const messaging = getMessaging();

    // Every user with a saved fcmToken (populated by
    // LoyaltyViewModel.updateFCMToken once the app registers for push).
    const usersSnap = await db
      .collection("users")
      .where("fcmToken", "!=", null)
      .get();

    const tokens = usersSnap.docs
      .map((doc) => doc.data().fcmToken)
      .filter((t) => typeof t === "string" && t.length > 0);

    if (tokens.length === 0) {
      console.log("No FCM tokens registered — nothing to send.");
      return;
    }

    const message = {
      notification: {
        title: notification.title || "Burpengary Fruit Market",
        body: notification.message || "",
        ...(notification.imageUrl ? { imageUrl: notification.imageUrl } : {}),
      },
      tokens,
    };

    const response = await messaging.sendEachForMulticast(message);
    console.log(
      `Sent to ${response.successCount}/${tokens.length} devices ` +
      `(${response.failureCount} failed).`
    );

    await snap.ref.update({ sent: true });
  }
);
