import 'package:familytree/screens/admin/analytics_data.dart';
import 'package:familytree/screens/admin/event_management.dart';
import 'package:familytree/screens/admin/heatmap_overview.dart';
import 'package:familytree/screens/admin/user_account.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:familytree/screens/welcome_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:collection';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Map<String, int> _signUps = {};
  Map<String, int> _familyGrowth = {};
  Map<String, int> _activeUsers = {}; // Add this
  int _currentMonthActive = 0;
  bool _isLoadingCharts = true;
  int _totalUsers = 0;
  int _totalFamilies = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    // Fetch chart data
    _fetchChartData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchChartData() async {
    setState(() => _isLoadingCharts = true);

    try {
      // Fetch all relevant collections
      final usersQuery = FirebaseFirestore.instance.collectionGroup('family_members');
      final familiesQuery = FirebaseFirestore.instance.collection('families');
      final moderatorsQuery = FirebaseFirestore.instance.collectionGroup('moderators');

      // Execute queries in parallel
      final results = await Future.wait([
        usersQuery.get(),
        familiesQuery.get(),
        moderatorsQuery.get(),
      ]);

      final users = results[0];
      final families = results[1];
      final moderators = results[2];

      // Initialize data maps
      Map<String, int> signMap = {};
      Map<String, int> familyMap = {};
      Map<String, int> activeMap = {};

      // Process users (excluding moderators)
      final regularUsers = users.docs.where((userDoc) =>
      !moderators.docs.any((modDoc) => modDoc.id == userDoc.id)
      );

      for (var doc in regularUsers) {
        final data = doc.data();

        // Signups
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt != null) {
          final key = DateFormat('yyyy-MM').format(createdAt.toDate());
          signMap[key] = (signMap[key] ?? 0) + 1;
        }

        // Active users (logged in last 30 days)
        final lastLogin = data['lastLogin'] as Timestamp?;
        if (lastLogin != null && lastLogin.toDate().isAfter(
            DateTime.now().subtract(const Duration(days: 30))
        ) ){
        final key = DateFormat('yyyy-MM').format(lastLogin.toDate());
        activeMap[key] = (activeMap[key] ?? 0) + 1;
        }
        }

        // Process families
        for (var doc in families.docs) {
          final data = doc.data();
          final createdAt = data['createdAt'] as Timestamp?;
          if (createdAt != null) {
            final key = DateFormat('yyyy-MM').format(createdAt.toDate());
            familyMap[key] = (familyMap[key] ?? 0) + 1;
          }
        }

        // Sort data chronologically
        Map<String, int> sortMapByDate(Map<String, int> map) {
          return SplayTreeMap<String, int>.from(
            map,
                (a, b) => a.compareTo(b),
          );
        }

        setState(() {
          _signUps = sortMapByDate(signMap);
          _familyGrowth = sortMapByDate(familyMap);
          _activeUsers = sortMapByDate(activeMap);
          _totalUsers = users.docs.length;
          _totalFamilies = families.docs.length;
          _currentMonthActive = activeMap.values.fold(0, (sum, count) => sum + count);
          _isLoadingCharts = false;
        });

      } catch (e) {
      setState(() {
        _signUps = {};
        _familyGrowth = {};
        _activeUsers = {};
        _isLoadingCharts = false;
      });
      debugPrint('Error fetching analytics data: $e');
    }
  }

  Map<String, int> _sortMapByDate(Map<String, int> map) {
    return SplayTreeMap<String, int>.from(
      map,
          (a, b) => a.compareTo(b),
    );
  }

  Widget _buildActiveUsersChart() {
    final months = _activeUsers.keys.toList();
    final hasData = months.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Monthly Active Users",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          _buildMiniStatCard(
              "Current Active",
              _currentMonthActive.toString(),
              Colors.green
          ),
          const SizedBox(height: 20),
          _isLoadingCharts
              ? Center(child: CircularProgressIndicator())
              : hasData
              ? SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barGroups: months.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: (_activeUsers[e.value] ?? 0).toDouble(),
                        color: Colors.green[400]!,
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < months.length) {
                          return Text(
                            months[index],
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
              ),
            ),
          )
              : Center(
            child: Text(
              "No active user data available",
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformGrowthChart() {
    final months = _signUps.keys.toList();
    final hasData = months.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Platform Growth",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniStatCard("Total Users", _totalUsers.toString(), Colors.blue),
              _buildMiniStatCard("Total Families", _totalFamilies.toString(), Colors.purple),
            ],
          ),
          const SizedBox(height: 20),
          _isLoadingCharts
              ? Center(child: CircularProgressIndicator(color: Colors.green[600]))
              : hasData
              ? SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 10,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey[200]!,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (double value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < months.length) {
                          final parts = months[index].split('-');
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              DateFormat('MMM').format(DateTime(int.parse(parts[0]), int.parse(parts[1]))),
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
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
                      interval: 10,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                minX: 0,
                maxX: (months.length - 1).toDouble(),
                minY: 0,
                maxY: _signUps.values.reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
                lineBarsData: [
                  LineChartBarData(
                    spots: months.asMap().entries.map((e) {
                      return FlSpot(
                        e.key.toDouble(),
                        (_signUps[e.value] ?? 0).toDouble(),
                      );
                    }).toList(),
                    isCurved: true,
                    color: Colors.blue[400]!,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withOpacity(0.1),
                    ),
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.blue[400]!,
                          strokeWidth: 0,
                        );
                      },
                    ),
                  ),
                  LineChartBarData(
                    spots: months.asMap().entries.map((e) {
                      return FlSpot(
                        e.key.toDouble(),
                        (_familyGrowth[e.value] ?? 0).toDouble(),
                      );
                    }).toList(),
                    isCurved: true,
                    color: Colors.purple[400]!,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.purple.withOpacity(0.1),
                    ),
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.purple[400]!,
                          strokeWidth: 0,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          )
              : Center(
            child: Text(
              "No growth data available",
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildChartLegend(Colors.blue, "User Sign-ups"),
              const SizedBox(width: 20),
              _buildChartLegend(Colors.purple, "Family Growth"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsSection(BuildContext context) {
    return Column(
      children: [
        // 1. Platform Growth Chart (Line Chart)
        _buildPlatformGrowthChart(),
        const SizedBox(height: 20),

        // 2. Active Users Chart (Bar Chart)
        _buildActiveUsersChart(),
        const SizedBox(height: 20),

      ],
    );
  }

  Widget _buildMiniStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

// Helper method for chart legend
  Widget _buildChartLegend(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
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
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Cancel'),
          ),
          Container(
            margin: const EdgeInsets.only(left: 8),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('Logout'),
            ),
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
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Enhanced header with gradient background
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.green[200]!,
                      Colors.green[300]!,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Column(
                    children: [
                      // Top navigation bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {});
                              _animationController.reset();
                              _animationController.forward();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Image.asset("assets/images/logo.png", height: 40),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: Icon(Icons.logout, color: Colors.green[700]),
                              onPressed: _logout,
                              splashRadius: 25,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      // Welcome text
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Welcome back,",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.green[800],
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Admin Dashboard",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Manage your family tree platform",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Dashboard grid with enhanced cards
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: GridView.count(
                          crossAxisCount: screenWidth > 600 ? 2 : 1,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                          childAspectRatio: 1.3,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildDashboardCard(
                              context,
                              label: "User Accounts",
                              iconPath: "assets/images/user.png",
                              color: Colors.blue,
                              description: "Manage users & families",
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const UserAccountsPage()),
                                );
                              },
                            ),
                            _buildDashboardCard(
                              context,
                              label: "Events",
                              iconPath: "assets/images/events.png",
                              color: Colors.purple,
                              description: "Family events & activities",
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AdminEventsPage()),
                              ),
                            ),
                            _buildDashboardCard(
                              context,
                              label: "Analytics",
                              iconPath: "assets/images/analytics.png",
                              color: Colors.orange,
                              description: "Stats & insights",
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const AnalyticsPage()),
                                );
                              },
                            ),
                            _buildDashboardCard(
                              context,
                              label: "Residence Heatmap",
                              iconPath: "assets/images/map.png",
                              color: Colors.teal,
                              description: "Visualize all users' locations",
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const AdminResidenceHeatMap()),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      _buildAnalyticsSection(context), // Add the analytics section here
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Bottom spacer
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
      BuildContext context, {
        required String label,
        required String iconPath,
        required MaterialColor color,
        required String description,
        required VoidCallback onTap,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 200),
        tween: Tween(begin: 1.0, end: 1.0),
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: Container(
              height: 220, // Fixed height for consistency
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                    spreadRadius: 1,
                  ),
                ],
                border: Border.all(
                  color: color.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(25),
                  splashColor: color.withOpacity(0.1),
                  highlightColor: color.withOpacity(0.05),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(25), // Increased padding
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon container with gradient background
                        Container(
                          padding: const EdgeInsets.all(20), // Larger icon container
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                color[100]!,
                                color[200]!,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            iconPath,
                            height: 50, // Larger icon
                            width: 50,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.error_outline,
                                size: 50, // Larger fallback icon
                                color: color[600],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20), // More spacing
                        // Label
                        Text(
                          label,
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 18, // Larger font
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        // Description
                        Text(
                          description,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14, // Larger font
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}