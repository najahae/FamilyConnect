import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:familytree/screens/welcome_screen.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _selectedRange = 'Months';
  final List<String> _ranges = ['Days', 'Months', 'Years'];

  Map<String, int> signUps = {};
  Map<String, int> deletions = {};

  @override
  void initState() {
    super.initState();
    _fetchAnalyticsData();
  }

  Future<void> _fetchAnalyticsData() async {
    final users = await FirebaseFirestore.instance.collectionGroup('family_members').get();
    final mods = await FirebaseFirestore.instance.collectionGroup('moderators').get();

    final all = [...users.docs, ...mods.docs];

    Map<String, int> signMap = {};
    Map<String, int> delMap = {};

    for (var doc in all) {
      final created = doc['createdAt']?.toDate();
      final deleted = doc['deletedAt']?.toDate();

      if (created != null) {
        final key = _formatDate(created);
        signMap[key] = (signMap[key] ?? 0) + 1;
      }

      if (deleted != null) {
        final key = _formatDate(deleted);
        delMap[key] = (delMap[key] ?? 0) + 1;
      }
    }

    setState(() {
      signUps = signMap;
      deletions = delMap;
    });
  }

  String _formatDate(DateTime date) {
    switch (_selectedRange) {
      case 'Days':
        return DateFormat('yyyy-MM-dd').format(date);
      case 'Months':
        return DateFormat('MMM yyyy').format(date);
      case 'Years':
        return DateFormat('yyyy').format(date);
      default:
        return '';
    }
  }

  List<BarChartGroupData> _generateBarData(Map<String, int> dataMap) {
    final sortedKeys = dataMap.keys.toList()..sort();
    return List.generate(sortedKeys.length, (index) {
      final key = sortedKeys[index];
      final count = dataMap[key]!;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(toY: count.toDouble(), color: Colors.green, width: 20),
        ],
        showingTooltipIndicators: [0],
      );
    });
  }

  Widget _buildChart(String title, Map<String, int> dataMap) {
    if (dataMap.isEmpty) return const Text("No data found");

    final xLabels = dataMap.keys.toList()..sort();
    final barData = _generateBarData(dataMap);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 200, child: Divider()),
        SizedBox(
          height: 250,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              barGroups: barData,
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (double value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < xLabels.length) {
                        final label = xLabels[index];
                        return Text(
                          _selectedRange == 'Years'
                              ? label
                              : label.split(' ')[0], // Just show Jan/Feb/Mar etc.
                          style: const TextStyle(fontSize: 10),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(show: true),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  void _logout() async {
    bool? confirmed = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _auth.signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        );
      }
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
            title: const Text("Analytics Data"),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: _logout,
              ),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text("Statistics", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: _ranges.map((range) {
                final isSelected = _selectedRange == range;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(range),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      setState(() {
                        _selectedRange = range;
                        _fetchAnalyticsData();
                      });
                    },
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            _buildChart("Sign Up User", signUps),
            _buildChart("Deleted Account", deletions),
          ],
        ),
      ),
    );
  }
}
