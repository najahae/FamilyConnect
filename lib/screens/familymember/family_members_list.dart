import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'family_member_model.dart';

class FamilyMemberListPage extends StatefulWidget {
  final String familyId;

  const FamilyMemberListPage({super.key, required this.familyId});

  @override
  State<FamilyMemberListPage> createState() => _FamilyMemberListPageState();
}

class _FamilyMemberListPageState extends State<FamilyMemberListPage> {
  List<FamilyMember> allMembers = [];
  String searchTerm = '';
  String selectedGender = 'All';

  @override
  void initState() {
    super.initState();
    fetchMembers();
  }

  Future<void> fetchMembers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('families')
        .doc(widget.familyId)
        .collection('family_members')
        .get();

    final members = snapshot.docs
        .map((doc) => FamilyMember.fromMap(doc.id, doc.data()))
        .toList();

    setState(() {
      allMembers = members;
    });
  }

  List<FamilyMember> get filteredMembers {
    return allMembers.where((member) {
      final matchesSearch = member.fullName.toLowerCase().contains(searchTerm) ||
          (member.nickname?.toLowerCase().contains(searchTerm) ?? false);
      final matchesGender = selectedGender == 'All' || member.gender.toLowerCase() == selectedGender.toLowerCase();
      return matchesSearch && matchesGender;
    }).toList();
  }

  Map<String, List<FamilyMember>> get groupedByParents {
    final Map<String, List<FamilyMember>> map = {};
    for (var member in filteredMembers) {
      final fatherId = member.fatherId ?? 'Unknown';
      final motherId = member.motherId ?? 'Unknown';
      final key = '$fatherId|$motherId';
      map.putIfAbsent(key, () => []);
      map[key]!.add(member);
    }
    return map;
  }

  String getParentNames(String key) {
    final parts = key.split('|');
    final fatherId = parts[0];
    final motherId = parts[1];

    final father = allMembers.firstWhere(
            (m) => m.id == fatherId,
        orElse: () => FamilyMember(id: 'Unknown', fullName: 'Unknown Father', gender: ''));
    final mother = allMembers.firstWhere(
            (m) => m.id == motherId,
        orElse: () => FamilyMember(id: 'Unknown', fullName: 'Unknown Mother', gender: ''));

    return 'Father: ${father.fullName} | Mother: ${mother.fullName}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Members by Parents'),
        backgroundColor: Colors.green[200],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => searchTerm = val.toLowerCase()),
                  decoration: const InputDecoration(
                    hintText: 'Search by name or nickname',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Gender:'),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: selectedGender,
                      onChanged: (val) => setState(() => selectedGender = val!),
                      items: ['All', 'Male', 'Female']
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              children: groupedByParents.entries.map((entry) {
                final parentKey = entry.key;
                final children = entry.value;
                return ExpansionTile(
                  title: Text(getParentNames(parentKey)),
                  children: children.map((member) => ListTile(
                    leading: CircleAvatar(
                      backgroundImage: member.profileImageUrl != null && member.profileImageUrl!.isNotEmpty
                          ? NetworkImage(member.profileImageUrl!)
                          : AssetImage('assets/images/user.png') as ImageProvider,
                    ),
                    title: Text(member.fullName),
                    subtitle: Text(member.nickname ?? ''),
                    trailing: Text(member.gender),
                  )).toList(),
                );
              }).toList(),
            ),
          )
        ],
      ),
    );
  }
}
