import 'dart:convert';
import 'dart:math';
import 'package:familytree/screens/familymember/family_members_list.dart';
import 'package:familytree/screens/moderator/edit_members.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'family_member_model.dart';

class FamilyTreePage extends StatefulWidget {
  final String familyID;
  final String role;

  const FamilyTreePage({super.key, required this.familyID, this.role = 'family_member'});

  @override
  State<FamilyTreePage> createState() => _FamilyTreePageState();
}

class _FamilyTreePageState extends State<FamilyTreePage> {
  late final WebViewController _controller;
  List<FamilyMember> members = [];
  String selectedGeneration = 'All';
  List<String> generationOptions = ['All', '1st Gen', '2nd Gen', '3rd Gen', '4th Gen+', 'In-Laws/Unknown'];
  bool isLoading = true;

  // Filters
  String searchTerm = '';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('FlutterChannel', onMessageReceived: handleJSMessage)
      ..loadFlutterAsset('assets/html/family_tree.html')
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => sendFamilyTreeData(),
      ));
    fetchMembers();
  }

  void handleJSMessage(JavaScriptMessage message) async {
    try {
      final decoded = jsonDecode(message.message);
      final type = decoded['type'];
      final payload = decoded['payload'];

      if (type == 'updateMember') {
        await FirebaseFirestore.instance
            .collection('families')
            .doc(widget.familyID)
            .collection('family_members')
            .doc(payload['id'])
            .update({
          'nickname': payload['nickname'],
          'birthDate': payload['birthDate'],
        });
        await fetchMembers();
        sendFamilyTreeData();
      } else if (type == 'deleteMember') {
        await FirebaseFirestore.instance
            .collection('families')
            .doc(widget.familyID)
            .collection('family_members')
            .doc(payload['id'])
            .delete();
        await fetchMembers();
        sendFamilyTreeData();
      } else if (type == 'editParents') {
        print("Edit parents requested for: ${payload['id']}");
      }
    } catch (e) {
      print('Error handling JS message: $e');
    }
  }

  Future<void> fetchMembers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('families')
          .doc(widget.familyID)
          .collection('family_members')
          .get();

      members = snapshot.docs
          .map((doc) => FamilyMember.fromMap(doc.id, doc.data()))
          .toList();

      setState(() => isLoading = false);
    } catch (e) {
      print('Error fetching family members: $e');
      setState(() => isLoading = false);
    }
  }

  void sendFamilyTreeData() {
    if (members.isEmpty) return;

    final filtered = members.where((m) {
      final matchesSearch = m.fullName.toLowerCase().contains(searchTerm) ||
          (m.nickname?.toLowerCase().contains(searchTerm) ?? false);
      final matchesGeneration = selectedGeneration == 'All' ||
          _matchesGenerationFilter(m, selectedGeneration);

      return matchesSearch && matchesGeneration;
    }).toList();

    final elements = toCytoscapeElements(filtered);
    final jsonText = jsonEncode(elements);

    _controller.runJavaScript("window.postMessage(`$jsonText`, '*');");
    _controller.runJavaScript("window.setUserRole('${widget.role}');");
  }

  String getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else {
      return name.substring(0, 2).toUpperCase();
    }
  }

  List<Map<String, dynamic>> toCytoscapeElements(List<FamilyMember> members) {
    final elements = <Map<String, dynamic>>[];
    final memberMap = {for (var m in members) m.id: m};

    // Expanded color palette
    final colors = [
      '#4a90e2', '#f06292', '#66bb6a', '#ffa726', '#26c6da',
      '#ab47bc', '#ec407a', '#d4e157', '#5c6bc0', '#ef5350',
      '#8d6e63', '#78909c', '#ff7043', '#26a69a', '#ffee58',
      '#7e57c2', '#42a5f5', '#9ccc65', '#ffca28', '#5d4037',
      '#00897b', '#f4511e', '#6d4c41', '#3949ab', '#c2185b',
      '#e91e63', '#00acc1', '#7cb342', '#fb8c00', '#5e35b1'
    ];

    final familyColors = <String, String>{};

    // First pass - assign colors to root members
    for (var member in members) {
      if (member.fatherId == null && member.motherId == null) {
        if (!familyColors.containsKey(member.id)) {
          final colorIndex = member.id.hashCode.abs() % colors.length;
          familyColors[member.id] = colors[colorIndex];
        }
      }
    }

    // Second pass - assign colors and shapes
    for (var member in members) {
      String color;

      if (member.fatherId != null && familyColors.containsKey(member.fatherId)) {
        color = familyColors[member.fatherId]!;
      }
      else if (member.motherId != null && familyColors.containsKey(member.motherId)) {
        color = familyColors[member.motherId]!;
      }
      else {
        final colorIndex = member.id.hashCode.abs() % colors.length;
        color = colors[colorIndex];
        familyColors[member.id] = color;
      }

      // Add gender-specific properties
      final gender = member.gender?.toLowerCase() ?? '';
      final shape = gender == 'male' ? 'rectangle' :
      gender == 'female' ? 'ellipse' : 'hexagon';

      final elementData = {
        'data': {
          'id': member.id,
          'label': getInitials(member.fullName),
          'fullName': member.fullName,
          'nickname': member.nickname ?? '',
          'birthDate': member.birthDate ?? '',
          'color': color,
          'gender': gender,
          'profileImageUrl': member.profileImageUrl ?? '',
        },
        // Add gender-specific styling
        'classes': gender // This will allow CSS class targeting in Cytoscape
      };

      elements.add(elementData);
    }

    // Relationship creation
    for (var member in members) {
      if (member.fatherId != null && memberMap.containsKey(member.fatherId)) {
        elements.add({
          'data': {'source': member.fatherId, 'target': member.id}
        });
      }
      if (member.motherId != null && memberMap.containsKey(member.motherId)) {
        elements.add({
          'data': {'source': member.motherId, 'target': member.id}
        });
      }
      if (member.spouseId != null && memberMap.containsKey(member.spouseId)) {
        if (!elements.any((e) => e['data']?['relationship'] == 'spouse' &&
            ((e['data']?['source'] == member.id && e['data']?['target'] == member.spouseId) ||
                (e['data']?['source'] == member.spouseId && e['data']?['target'] == member.id)))) {
          elements.add({
            'data': {
              'source': member.id,
              'target': member.spouseId,
              'relationship': 'spouse',
            }
          });
        }
      }
    }

    return elements;
  }

  void _showTreeInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Family Tree Guide"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text("Arrows (→): Parent → Child"),
            SizedBox(height: 8),
            Text("Dotted Line (---): Spouse connection"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Got it!"),
          ),
        ],
      ),
    );
  }

  int _calculateGeneration(FamilyMember member, {int depth = 0, Set<String>? visited}) {
    visited ??= <String>{};

    // Prevent infinite loops in case of circular references
    if (visited.contains(member.id)) return 1;
    visited.add(member.id);

    // Case 1: In-laws (spouses with no parents)
    if (member.fatherId == null && member.motherId == null) {
      // Check if they're connected as spouses
      try {
        final spouse = members.firstWhere(
              (m) => m.spouseId == member.id || member.spouseId == m.id,
        );
        // Inherit generation from spouse
        return _calculateGeneration(spouse, visited: visited);
      } catch (e) {
        // No spouse found
      }
    }

    // Case 2: Regular members with parents
    if (member.fatherId != null || member.motherId != null) {
      FamilyMember? father;
      FamilyMember? mother;

      try {
        father = member.fatherId != null
            ? members.firstWhere((m) => m.id == member.fatherId)
            : null;
      } catch (e) {
        father = null;
      }

      try {
        mother = member.motherId != null
            ? members.firstWhere((m) => m.id == member.motherId)
            : null;
      } catch (e) {
        mother = null;
      }

      int fatherGen = father != null ? _calculateGeneration(father, visited: visited) : 0;
      int motherGen = mother != null ? _calculateGeneration(mother, visited: visited) : 0;

      return max(fatherGen, motherGen) + 1;
    }

    // Case 3: Root members (no parents and not spouses)
    return 1;
  }

  bool _matchesGenerationFilter(FamilyMember member, String selectedGen) {
    final generation = _calculateGeneration(member);

    switch (selectedGen) {
      case '1st Gen':
        return generation == 1;
      case '2nd Gen':
        return generation == 2;
      case '3rd Gen':
        return generation == 3;
      case '4th Gen+':
        return generation >= 4;
      case 'In-Laws/Unknown':
      // Members with no parents and no generational connection
        return member.fatherId == null &&
            member.motherId == null &&
            members.none((m) => m.spouseId == member.id || member.spouseId == m.id);
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(25),
            bottomRight: Radius.circular(25),
          ),
          child: AppBar(
            backgroundColor: Colors.green[200],
            centerTitle: true,
            title: const Text("Family Tree", style: TextStyle(fontWeight: FontWeight.bold)),
            automaticallyImplyLeading: false,
          ),
        ),
      ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (context) {
                return SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.list),
                        title: const Text('View Member List'),
                        onTap: () {
                          Navigator.pop(context); // Close the bottom sheet
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FamilyMemberListPage(familyId: widget.familyID),
                            ),
                          );
                        },
                      ),
                      if (widget.role == 'moderator')
                        ListTile(
                          leading: const Icon(Icons.edit),
                          title: const Text('Edit Parents'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditMembersPage(familyId: widget.familyID),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                );
              },
            );
          },
          child: const Icon(Icons.menu),
          tooltip: 'Options',
        ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  onChanged: (val) {
                    setState(() => searchTerm = val.toLowerCase());
                    sendFamilyTreeData();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search name or nickname',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Generation:'),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: selectedGeneration,
                      onChanged: (val) {
                        setState(() => selectedGeneration = val ?? 'All');
                        sendFamilyTreeData();
                      },
                      items: generationOptions.map((gen) {
                        return DropdownMenuItem(
                          value: gen,
                          child: Text(gen),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _showTreeInfoDialog,
                    icon: Icon(Icons.info_outline, color: Colors.brown),
                    label: Text(
                      "What does arrow and dotted line mean?",
                      style: TextStyle(color: Colors.brown),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}

extension IterableExtension<T> on Iterable<T> {
  bool none(bool Function(T) test) => !any(test);
}
