const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.sendEventNotification = functions
  .region("asia-southeast1")
  .firestore.document("families/{familyId}/events/{eventId}")
  .onCreate(async (snap, context) => {
    const eventData = snap.data();
    const familyID = context.params.familyId;
    const eventId = context.params.eventId;
    const invitedIds = eventData.invitedMemberIds || [];

    const db = admin.firestore();

    // 1. Send push notification like you already do
    const memberDocs = await Promise.all(
      invitedIds.map((memberId) =>
        db.doc(`families/${familyID}/family_members/${memberId}`).get()
      )
    );

    const tokens = memberDocs
      .map((doc) => (doc.exists ? doc.data()?.fcmToken : null))
      .filter((token) => !!token);

    if (tokens.length) {
      await admin.messaging().sendEachForMulticast({
        tokens: tokens,
        notification: {
          title: `You're invited: ${eventData.title || "Family Event"}`,
          body: `Starts at ${eventData.startTime || "soon"}`,
        },
        data: {
          type: "event_invite",
          eventId: eventId,
          familyId: familyID,
        },
      });
    }

    // 2. Save to Firestore "notifications" collection for each member
    const batch = db.batch();

    invitedIds.forEach((memberId) => {
      const notifRef = db
        .collection("families")
        .doc(familyID)
        .collection("family_members")
        .doc(memberId)
        .collection("notifications")
        .doc(); // random ID

      batch.set(notifRef, {
        title: `You're invited: ${eventData.title || "Family Event"}`,
        body: `Starts at ${eventData.startTime || "soon"}`,
        type: "event_invite",
        eventId: eventId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        rsvpStatus: "pending", // Will be updated when user taps RSVP
      });
    });

    await batch.commit();
    return null;
  });