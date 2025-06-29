import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsPage extends StatefulWidget {
  final String familyID;
  const NotificationsPage({Key? key, required this.familyID}) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String userId;

  @override
  void initState() {
    super.initState();
    userId = _auth.currentUser?.uid ?? '';
  }

  Future<void> _respondToEvent(String notifId, String newStatus) async {
    final notifRef = _firestore
        .collection("families")
        .doc(widget.familyID)
        .collection("family_members")
        .doc(userId)
        .collection("notifications")
        .doc(notifId);

    await notifRef.update({"rsvpStatus": newStatus});
  }

  @override
  Widget build(BuildContext context) {
    final notifStream = _firestore
        .collection("families")
        .doc(widget.familyID)
        .collection("family_members")
        .doc(userId)
        .collection("notifications")
        .orderBy("timestamp", descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        backgroundColor: Colors.green[200],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: notifStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text("No notifications found."));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'] ?? "No title";
              final body = data['body'] ?? "";
              final rsvp = data['rsvpStatus'] ?? "pending";

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(body),
                      const SizedBox(height: 8),
                      Text("RSVP: ${rsvp.toUpperCase()}", style: TextStyle(color: Colors.grey[700])),
                      const SizedBox(height: 10),
                      if (rsvp == "pending")
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600]),
                              icon: const Icon(Icons.check),
                              label: const Text("Going"),
                              onPressed: () => _respondToEvent(doc.id, "going"),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[400]),
                              icon: const Icon(Icons.help_outline),
                              label: const Text("Maybe"),
                              onPressed: () => _respondToEvent(doc.id, "maybe"),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[400]),
                              icon: const Icon(Icons.close),
                              label: const Text("Not Going"),
                              onPressed: () => _respondToEvent(doc.id, "not_going"),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
