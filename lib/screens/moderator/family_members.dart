import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyMembersScreen extends StatelessWidget {
  final String familyID;

  FamilyMembersScreen({required this.familyID});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Family Members")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('families')
            .doc(familyID)
            .collection('members')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          var members = snapshot.data!.docs;
          return ListView.builder(
            itemCount: members.length,
            itemBuilder: (context, index) {
              var member = members[index];
              return ListTile(
                title: Text(member['name']),
                subtitle: Text(member['email']),
                leading: Icon(Icons.person),
              );
            },
          );
        },
      ),
    );
  }
}
