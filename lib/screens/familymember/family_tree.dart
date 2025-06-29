import 'dart:convert';
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
  bool isLoading = true;

  // Filters
  String searchTerm = '';
  String selectedGender = 'All';

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
      final matchesGender = selectedGender == 'All' || m.gender.toLowerCase() == selectedGender.toLowerCase();
      return matchesSearch && matchesGender;
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

    for (var member in members) {
      elements.add({
        'data': {
          'id': member.id,
          'label': getInitials(member.fullName),
          'fullName': member.fullName,
          'nickname': member.nickname ?? '',
          'birthDate': member.birthDate ?? '',
          'color': member.gender.toLowerCase() == 'male'
              ? '#4a90e2'
              : '#f06292',
        }
      });
    }

    for (var member in members) {
      if (member.fatherId != null && memberMap.containsKey(member.fatherId)) {
        elements.add({
          'data': {
            'source': member.fatherId,
            'target': member.id,
          }
        });
      }
      if (member.motherId != null && memberMap.containsKey(member.motherId)) {
        elements.add({
          'data': {
            'source': member.motherId,
            'target': member.id,
          }
        });
      }
      if (member.spouseId != null && memberMap.containsKey(member.spouseId)) {
        if (!elements.any((e) =>
        e['data']?['relationship'] == 'spouse' &&
            ((e['data']?['source'] == member.id &&
                e['data']?['target'] == member.spouseId) ||
                (e['data']?['source'] == member.spouseId &&
                    e['data']?['target'] == member.id)))) {
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
      floatingActionButton: (widget.role == 'moderator')
          ? FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditMembersPage(familyId: widget.familyID),
            ),
          );
        },
        child: const Icon(Icons.list),
        tooltip: 'Edit Members',
      )
          : null,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Column(
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
                    const Text('Gender:'),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: selectedGender,
                      onChanged: (val) {
                        setState(() => selectedGender = val ?? 'All');
                        sendFamilyTreeData();
                      },
                      items: ['All', 'Male', 'Female'].map((gender) {
                        return DropdownMenuItem(value: gender, child: Text(gender));
                      }).toList(),
                    ),
                  ],
                )
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
