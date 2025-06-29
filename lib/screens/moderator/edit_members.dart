// 1. New screen for Moderator to edit parent info
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditMembersPage extends StatefulWidget {
  final String familyId;
  const EditMembersPage({super.key, required this.familyId});

  @override
  State<EditMembersPage> createState() => _EditMembersPageState();
}

class _EditMembersPageState extends State<EditMembersPage> {
  List<DocumentSnapshot> allMembers = [];
  bool isLoading = true;

  String searchQuery = '';
  String selectedGender = 'All';

  @override
  void initState() {
    super.initState();
    fetchMembers();
  }

  Future<void> fetchMembers() async {
    final query = await FirebaseFirestore.instance
        .collection('families')
        .doc(widget.familyId)
        .collection('family_members')
        .get();

    setState(() {
      allMembers = query.docs;
      isLoading = false;
    });
  }

  List<DocumentSnapshot> get filteredMembers {
    return allMembers.where((m) {
      final name = (m['fullName'] ?? '').toString().toLowerCase();
      final nickname = (m['nickname'] ?? '').toString().toLowerCase();
      final gender = (m['gender'] ?? '').toString().toLowerCase();

      final genderMatch = selectedGender == 'All' ||
          gender == selectedGender.toLowerCase();
      final searchMatch = name.contains(searchQuery) ||
          nickname.contains(searchQuery);

      return genderMatch && searchMatch;
    }).toList();
  }

  Widget buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search by name or nickname',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              setState(() => searchQuery = value.toLowerCase());
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: DropdownButton<String>(
              value: selectedGender,
              items: ['All', 'Male', 'Female']
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (value) {
                setState(() => selectedGender = value!);
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Parents'),
        backgroundColor: Colors.green[300],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      backgroundColor: Colors.grey[100],
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : allMembers.isEmpty
          ? const Center(child: Text('No family members found.'))
          : Column(
        children: [
          buildFilterBar(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filteredMembers.length,
              itemBuilder: (context, index) {
                final member = filteredMembers[index];
                return Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    title: Text(
                      member['fullName'] ?? 'Unnamed',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                        'Nickname: ${member['nickname'] ?? '-'}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit,
                          color: Colors.blueGrey),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => EditParentsDialog(
                            member: member,
                            allMembers: allMembers,
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class EditParentsDialog extends StatefulWidget {
  final DocumentSnapshot member;
  final List<DocumentSnapshot> allMembers;

  const EditParentsDialog(
      {super.key, required this.member, required this.allMembers});

  @override
  State<EditParentsDialog> createState() => _EditParentsDialogState();
}

class _EditParentsDialogState extends State<EditParentsDialog> {
  String? selectedFatherId;
  String? selectedMotherId;

  @override
  void initState() {
    super.initState();
    selectedFatherId = widget.member['fatherId'];
    selectedMotherId = widget.member['motherId'];
  }

  @override
  Widget build(BuildContext context) {
    List<DropdownMenuItem<String>> fatherOptions = widget.allMembers
        .where((m) =>
    m.id != widget.member.id &&
        (m['gender'] ?? '').toString().toLowerCase() == 'male')
        .map((m) => DropdownMenuItem(
      value: m.id,
      child: Text(m['fullName'] ?? m.id),
    ))
        .toList();

    List<DropdownMenuItem<String>> motherOptions = widget.allMembers
        .where((m) =>
    m.id != widget.member.id &&
        (m['gender'] ?? '').toString().toLowerCase() == 'female')
        .map((m) => DropdownMenuItem(
      value: m.id,
      child: Text(m['fullName'] ?? m.id),
    ))
        .toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Edit Parents of\n${widget.member['fullName'] ?? 'Unnamed'}',
                style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedFatherId,
                decoration: InputDecoration(
                  labelText: 'Father',
                  border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: fatherOptions,
                onChanged: (val) => setState(() => selectedFatherId = val),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedMotherId,
                decoration: InputDecoration(
                  labelText: 'Mother',
                  border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: motherOptions,
                onChanged: (val) => setState(() => selectedMotherId = val),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('families')
                          .doc(widget.member['familyId'])
                          .collection('family_members')
                          .doc(widget.member.id)
                          .update({
                        'fatherId': selectedFatherId,
                        'motherId': selectedMotherId,
                      });
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[400],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
