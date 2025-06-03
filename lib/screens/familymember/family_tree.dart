import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:graphview/GraphView.dart';
import 'family_member_model.dart';

class FamilyTreePage extends StatefulWidget {
  final String familyID;

  const FamilyTreePage({super.key, required this.familyID});

  @override
  State<FamilyTreePage> createState() => _FamilyTreePageState();
}

class _FamilyTreePageState extends State<FamilyTreePage> {
  final Graph graph = Graph();
  BuchheimWalkerConfiguration builder = BuchheimWalkerConfiguration();

  List<FamilyMember> members = [];
  bool isLoading = true;
  Map<String, FamilyMember> memberMap = {};

  TransformationController _transformationController = TransformationController();
  double _scaleFactor = 1.0;

  @override
  void initState() {
    super.initState();
    fetchFamilyMembers();
  }

  Future<void> fetchFamilyMembers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('families')
          .doc(widget.familyID)
          .collection('family_members')
          .get();

      members = snapshot.docs
          .map((doc) => FamilyMember.fromMap(doc.id, doc.data()))
          .toList();

      memberMap = {for (var m in members) m.id: m};

      buildGraph();

      setState(() => isLoading = false);
    } catch (e) {
      print('Error fetching family members: $e');
      setState(() => isLoading = false);
    }
  }

  void buildGraph() {
    graph.nodes.clear();
    graph.edges.clear();

    Map<String, Node> nodeMap = {};

    for (var member in members) {
      nodeMap[member.id] = Node.Id(member.id);
    }

    for (var member in members) {
      if (member.fatherId != null && nodeMap.containsKey(member.fatherId)) {
        graph.addEdge(nodeMap[member.fatherId]!, nodeMap[member.id]!);
      }
      if (member.motherId != null && nodeMap.containsKey(member.motherId)) {
        graph.addEdge(nodeMap[member.motherId]!, nodeMap[member.id]!);
      }
    }

    builder
      ..siblingSeparation = (60)
      ..levelSeparation = (80)
      ..subtreeSeparation = (50)
      ..orientation = BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM;
  }

  Widget nodeWidget(String memberId) {
    final member = memberMap[memberId]!;
    final color = member.gender.toLowerCase() == 'male'
        ? Colors.blue
        : Colors.pink;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: color,
          child: Icon(Icons.person, color: Colors.white),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 80,
          child: Text(
            member.fullName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  void zoomIn() {
    setState(() {
      _scaleFactor *= 1.2;
      _transformationController.value = Matrix4.identity()..scale(_scaleFactor);
    });
  }

  void zoomOut() {
    setState(() {
      _scaleFactor /= 1.2;
      _transformationController.value = Matrix4.identity()..scale(_scaleFactor);
    });
  }

  void resetZoom() {
    setState(() {
      _scaleFactor = 1.0;
      _transformationController.value = Matrix4.identity();
    });
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : members.isEmpty
          ? const Center(child: Text('No family members found.'))
          : Stack(
        children: [
          InteractiveViewer(
            transformationController: _transformationController,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(100),
            minScale: 0.01,
            maxScale: 5.0,
            child: GraphView(
              graph: graph,
              algorithm: BuchheimWalkerAlgorithm(builder, TreeEdgeRenderer(builder)),
              paint: Paint()
                ..color = Colors.black
                ..strokeWidth = 1
                ..style = PaintingStyle.stroke,
              builder: (Node node) {
                final memberId = node.key!.value as String;
                return nodeWidget(memberId);
              },
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "zoomIn",
                  mini: true,
                  onPressed: zoomIn,
                  child: const Icon(Icons.zoom_in),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "zoomOut",
                  mini: true,
                  onPressed: zoomOut,
                  child: const Icon(Icons.zoom_out),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
