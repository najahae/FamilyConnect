import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:familytree/screens/welcome_screen.dart';
import 'dart:collection';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage>
    with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _selectedRange = 'Months';
  final List<String> _ranges = ['Days', 'Months', 'Years'];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late AnimationController _chartAnimationController;
  late Animation<double> _chartAnimation;

  Map<String, int> signUps = {};
  Map<String, int> deletions = {};
  Map<String, int> familyGrowth = {};
  Map<String, int> moderatorActivity = {};
  Map<String, int> _genderDistribution = {};
  int _maleCount = 0;
  int _femaleCount = 0;
  int _otherGenderCount = 0;

  bool _isLoading = true;
  int _totalUsers = 0;
  int _totalFamilies = 0;
  int _totalModerators = 0;
  int _activeUsers = 0;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _fetchAnalyticsData();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _chartAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _chartAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _chartAnimationController, curve: Curves.elasticOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _chartAnimationController.dispose();
    super.dispose();
  }

  Future<void> _fetchAnalyticsData() async {
    setState(() => _isLoading = true);

    try {
      // Fetch all data
      final users = await FirebaseFirestore.instance.collectionGroup('family_members').get();
      final mods = await FirebaseFirestore.instance.collectionGroup('moderators').get();
      final families = await FirebaseFirestore.instance.collection('families').get();
      final genderMap = <String, int>{};
      int male = 0;
      int female = 0;
      int other = 0;

      // Initialize maps
      Map<String, int> signMap = {};
      Map<String, int> delMap = {};
      Map<String, int> familyMap = {};
      Map<String, int> modMap = {};

      // Process all users (including moderators)
      for (var doc in users.docs) {
        final data = doc.data();

        if (data.containsKey('createdAt') && data['createdAt'] != null) {
          final created = (data['createdAt'] as Timestamp).toDate();
          final key = _formatDate(created);
          signMap[key] = (signMap[key] ?? 0) + 1;
        }

        if (data.containsKey('deletedAt') && data['deletedAt'] != null) {
          final deleted = (data['deletedAt'] as Timestamp).toDate();
          final key = _formatDate(deleted);
          delMap[key] = (delMap[key] ?? 0) + 1;
        }

        // Add gender data
        if (data.containsKey('gender')) {
          final gender = data['gender']?.toString().toLowerCase() ?? 'unknown';
          genderMap[gender] = (genderMap[gender] ?? 0) + 1;

          // Count for pie chart
          if (gender == 'male') {
            male++;
          } else if (gender == 'female') {
            female++;
          } else {
            other++;
          }
        }
      }

      // Process moderator data separately for moderator-specific stats
      for (var doc in mods.docs) {
        final data = doc.data();
        if (data.containsKey('createdAt') && data['createdAt'] != null) {
          final created = (data['createdAt'] as Timestamp).toDate();
          final key = _formatDate(created);
          modMap[key] = (modMap[key] ?? 0) + 1;
        }
      }

      // Process family data
      for (var doc in families.docs) {
        final data = doc.data();
        if (data.containsKey('createdAt') && data['createdAt'] != null) {
          final created = (data['createdAt'] as Timestamp).toDate();
          final key = _formatDate(created);
          familyMap[key] = (familyMap[key] ?? 0) + 1;
        }
      }

      // Sort all data chronologically
      Map<String, int> sortMapByDate(Map<String, int> map) {
        final sorted = SplayTreeMap<String, int>();
        map.forEach((key, value) => sorted[key] = value);
        return sorted;
      }

      setState(() {
        signUps = sortMapByDate(signMap);
        deletions = sortMapByDate(delMap);
        familyGrowth = sortMapByDate(familyMap);
        moderatorActivity = sortMapByDate(modMap);
        _totalUsers = users.docs.length;
        _totalFamilies = families.docs.length;
        _totalModerators = mods.docs.length;
        _activeUsers = users.docs.where((doc) {
          final data = doc.data();
          return !data.containsKey('deletedAt') || data['deletedAt'] == null;
        }).length;
        _genderDistribution = genderMap;
        _maleCount = male;
        _femaleCount = female;
        _otherGenderCount = other;
        _isLoading = false;
      });

      _chartAnimationController.reset();
      _chartAnimationController.forward();
    } catch (e) {
      // Error handling remains same
    }
  }

  String _formatDate(DateTime date) {
    switch (_selectedRange) {
      case 'Days':
        return DateFormat('yyyy-MM-dd').format(date);
      case 'Months':
        return DateFormat('yyyy-MM').format(date); // Changed to include year-month only
      case 'Years':
        return DateFormat('yyyy').format(date);
      default:
        return '';
    }
  }

  List<BarChartGroupData> _generateBarData(Map<String, int> dataMap, Color color) {
    if (dataMap.isEmpty) return [];

    final sortedKeys = dataMap.keys.toList()..sort();
    return List.generate(sortedKeys.length, (index) {
      final key = sortedKeys[index];
      final count = dataMap[key] ?? 0;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: count.toDouble() * _chartAnimation.value,
            color: color,
            width: 16,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [color.withOpacity(0.7), color],
            ),
          ),
        ],
      );
    });
  }

  Widget _buildGenderLegend(String label, Color color, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildGenderPieChart() {
    final total = _maleCount + _femaleCount + _otherGenderCount;
    if (total == 0) {
      return _buildEmptyChart('Gender Distribution', Icons.pie_chart);
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_animationController, _chartAnimationController]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.pie_chart, color: Colors.blue, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Gender Distribution',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                      Text(
                        '$total users',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {},
                        ),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 2,
                        centerSpaceRadius: 60,
                        sections: [
                          PieChartSectionData(
                            color: Colors.blue,
                            value: _maleCount.toDouble() * _chartAnimation.value,
                            title: '${((_maleCount / total) * 100).toStringAsFixed(1)}%',
                            radius: 25,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            color: Colors.pink,
                            value: _femaleCount.toDouble() * _chartAnimation.value,
                            title: '${((_femaleCount / total) * 100).toStringAsFixed(1)}%',
                            radius: 25,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            color: Colors.purple,
                            value: _otherGenderCount.toDouble() * _chartAnimation.value,
                            title: '${((_otherGenderCount / total) * 100).toStringAsFixed(1)}%',
                            radius: 25,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildGenderLegend('Male', Colors.blue, _maleCount),
                      _buildGenderLegend('Female', Colors.pink, _femaleCount),
                      _buildGenderLegend('Other', Colors.purple, _otherGenderCount),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedChart(String title, Map<String, int> dataMap, Color color, IconData icon) {
    if (dataMap.isEmpty) {
      return _buildEmptyChart(title, icon);
    }

    final xLabels = dataMap.keys.toList()..sort();

    return AnimatedBuilder(
      animation: Listenable.merge([_animationController, _chartAnimationController]),
      builder: (context, child) {
        final barData = _generateBarData(dataMap, color);

        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        child: Text(
                          '${(dataMap.values.fold(0, (a, b) => a + b) * _chartAnimation.value).round()} total',
                          key: ValueKey(_chartAnimation.value),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        barGroups: barData,
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (double value, meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < xLabels.length) {
                                  final label = xLabels[index];
                                  String displayText;

                                  switch (_selectedRange) {
                                  case 'Days':
                                  displayText = DateFormat('MMM d').format(DateTime.parse(label));
                                  break;
                                  case 'Months':
                                  final parts = label.split('-');
                                  displayText = DateFormat('MMM').format(DateTime(int.parse(parts[0]), int.parse(parts[1]))); // Fixed line
                                  break;
                                  case 'Years':
                                  displayText = label;
                                  break;
                                  default:
                                  displayText = '';
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      displayText,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 35,
                              getTitlesWidget: (value, meta) => Text(
                                value.toInt().toString(),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          show: true,
                          drawHorizontalLine: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey[200]!,
                            strokeWidth: 1,
                          ),
                        ),
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (group) => color.withOpacity(0.9),
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final actualValue = dataMap.values.toList()[groupIndex];
                              return BarTooltipItem(
                                '$actualValue',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyChart(String title, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.grey[400], size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Icon(Icons.bar_chart, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            'No data available',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatsCard(String title, String value, IconData icon, Color color) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _logout() async {
    bool? confirmed = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Confirm Logout',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: Colors.grey[600]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.green[200],
        foregroundColor: Colors.green[800],
        title: Text(
          "Analytics Dashboard",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.green[800],
          ),
        ),
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(25),
            bottomRight: Radius.circular(25),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.green[800]),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchAnalyticsData,
        color: Colors.green[600],
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Stats Cards
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _buildStatsCard('Total Users', _totalUsers.toString(), Icons.people, Colors.blue),
                  _buildStatsCard('Active Users', _activeUsers.toString(), Icons.people_outline, Colors.green),
                  _buildStatsCard('Total Families', _totalFamilies.toString(), Icons.family_restroom, Colors.purple),
                  _buildStatsCard('Moderators', _totalModerators.toString(), Icons.admin_panel_settings, Colors.orange),
                ],
              ),

              _buildGenderPieChart(),

              const SizedBox(height: 24),

              // Time Range Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Time Period Analysis',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: _ranges.map((range) {
                        final isSelected = _selectedRange == range;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedRange = range;
                            });
                            _fetchAnalyticsData();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.green[600] : Colors.transparent,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Text(
                              range,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey[600],
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Charts
              _buildAnimatedChart("User Sign-ups", signUps, Colors.green[600]!, Icons.person_add),
              _buildAnimatedChart("Account Deletions", deletions, Colors.red[600]!, Icons.person_remove),
              _buildAnimatedChart("Family Growth", familyGrowth, Colors.purple[600]!, Icons.family_restroom),
              _buildAnimatedChart("New Moderators", moderatorActivity, Colors.orange[600]!, Icons.admin_panel_settings),
            ],
          ),
        ),
      ),
    );
  }
}