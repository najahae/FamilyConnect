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

    // Fetch all invited member docs
    const memberDocs = await Promise.all(
      invitedIds.map((memberId) =>
        db.doc(`families/${familyID}/family_members/${memberId}`).get()
      )
    );

    // Send notifications one by one with userId included
    for (let i = 0; i < memberDocs.length; i++) {
      const doc = memberDocs[i];
      if (!doc.exists) continue;

      const memberData = doc.data();
      const token = memberData?.fcmToken;
      const memberId = invitedIds[i];

      if (!token) continue;

      await admin.messaging().send({
        token: token,
        notification: {
          title: `You're invited: ${eventData.title || "Family Event"}`,
          body: `Starts at ${eventData.startTime || "soon"}`,
        },
        data: {
          type: "event_invite",
          eventId: eventId,
          familyId: familyID,
          userId: memberId, // ✅ Here's the magic
        },
      });
    }

    // Save notification doc for each invited member
    const batch = db.batch();

    invitedIds.forEach((memberId) => {
      const notifRef = db
        .collection("families")
        .doc(familyID)
        .collection("family_members")
        .doc(memberId)
        .collection("notifications")
        .doc(); // auto ID

      batch.set(notifRef, {
        title: `You're invited: ${eventData.title || "Family Event"}`,
        body: `Starts at ${eventData.startTime || "soon"}`,
        type: "event_invite",
        eventId: eventId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        rsvpStatus: "pending",
      });
    });

    await batch.commit();
    return null;
  });
