import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';

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
      body: Container(
        color: Colors.grey[100], // Set background color here
        child: isLoading
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10,
                      ),
                      title: Text(
                        member['fullName'] ?? 'Unnamed',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Nickname: ${member['nickname'] ?? '-'}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit,
                            color: Colors.blueGrey),
                        onPressed: () async {
                          final success = await showDialog<bool>(
                            context: context,
                            builder: (_) => EditParentsDialog(
                              member: member,
                              allMembers: allMembers,
                              familyId: widget.familyId, // pass it here
                            ),
                          );
                          if (success == true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Parents updated successfully!',
                                ),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            fetchMembers();
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EditParentsDialog extends StatefulWidget {
  final DocumentSnapshot member;
  final List<DocumentSnapshot> allMembers;
  final String familyId;

  const EditParentsDialog({
    Key? key,
    required this.member,
    required this.allMembers,
    required this.familyId,
  }) : super(key: key);

  @override
  State<EditParentsDialog> createState() => _EditParentsDialogState();
}

class _EditParentsDialogState extends State<EditParentsDialog> {
  String? selectedFatherId;
  String? selectedMotherId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    selectedFatherId = widget.member['fatherId'];
    selectedMotherId = widget.member['motherId'];
  }

  Future<void> _saveParents() async {
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('families')
          .doc(widget.familyId)
          .collection('family_members')
          .doc(widget.member.id)
          .update({
        'fatherId': selectedFatherId,
        'motherId': selectedMotherId,
      });
      Navigator.of(context).pop(true); // Return success
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: ${e.toString()}')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Convert DocumentSnapshots to a format DropdownSearch can use
    final potentialFathers = widget.allMembers.where((m) =>
    m.id != widget.member.id &&
        (m['gender'] ?? '').toString().toLowerCase() == 'male').toList();

    final potentialMothers = widget.allMembers.where((m) =>
    m.id != widget.member.id &&
        (m['gender'] ?? '').toString().toLowerCase() == 'female').toList();

    // Create a "None" option
    final noneOption = {'id': null, 'name': 'None'};

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Edit Parents for ${widget.member['fullName'] ?? 'Member'}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Father Dropdown
            DropdownSearch<Map<String, dynamic>>(
              items: [noneOption, ...potentialFathers.map((doc) => {
                'id': doc.id,
                'name': doc['fullName'] ?? 'Unnamed',
                'doc': doc,
              })],
              selectedItem: potentialFathers
                  .where((m) => m.id == selectedFatherId)
                  .map((doc) => {
                'id': doc.id,
                'name': doc['fullName'] ?? 'Unnamed',
                'doc': doc,
              })
                  .firstOrNull ?? noneOption,
              itemAsString: (item) => item['name'],
              onChanged: (value) {
                setState(() {
                  selectedFatherId = value?['id'];
                });
              },
              dropdownDecoratorProps: const DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: 'Father',
                  border: OutlineInputBorder(),
                ),
              ),
              popupProps: PopupProps.menu(
                showSearchBox: true,
                itemBuilder: (context, item, isSelected) {
                  return ListTile(
                    title: Text(item['name']),
                  );
                },
                searchFieldProps: const TextFieldProps(
                  decoration: InputDecoration(
                    hintText: 'Search fathers...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Mother Dropdown
            DropdownSearch<Map<String, dynamic>>(
              items: [noneOption, ...potentialMothers.map((doc) => {
                'id': doc.id,
                'name': doc['fullName'] ?? 'Unnamed',
                'doc': doc,
              })],
              selectedItem: potentialMothers
                  .where((m) => m.id == selectedMotherId)
                  .map((doc) => {
                'id': doc.id,
                'name': doc['fullName'] ?? 'Unnamed',
                'doc': doc,
              })
                  .firstOrNull ?? noneOption,
              itemAsString: (item) => item['name'],
              onChanged: (value) {
                setState(() {
                  selectedMotherId = value?['id'];
                });
              },
              dropdownDecoratorProps: const DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: 'Mother',
                  border: OutlineInputBorder(),
                ),
              ),
              popupProps: PopupProps.menu(
                showSearchBox: true,
                itemBuilder: (context, item, isSelected) {
                  return ListTile(
                    title: Text(item['name']),
                  );
                },
                searchFieldProps: const TextFieldProps(
                  decoration: InputDecoration(
                    hintText: 'Search mothers...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveParents,
                  child: _isSaving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}