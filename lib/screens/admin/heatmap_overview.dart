import 'dart:convert';
import 'package:familytree/screens/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminResidenceHeatMap extends StatefulWidget {
  const AdminResidenceHeatMap({super.key});

  @override
  State<AdminResidenceHeatMap> createState() => _AdminResidenceHeatMapState();
}

class _AdminResidenceHeatMapState extends State<AdminResidenceHeatMap> {
  late final WebViewController _controller;
  bool _isLoading = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadFlutterAsset('assets/html/admin_heatmap.html')
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (String url) {
          setState(() => _isLoading = false);
          _sendDataToWebView();
        },
      ));
  }

  Future<void> _sendDataToWebView() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('family_members')
          .where('location', isNotEqualTo: null)
          .get();

      final membersData = <Map<String, dynamic>>[];
      final batchSize = 500;
      int processed = 0;

      while (processed < snapshot.docs.length) {
        final batch = snapshot.docs.skip(processed).take(batchSize);

        for (var doc in batch) {
          final data = doc.data();
          final location = data['location'];

          if (location?['latitude'] != null && location?['longitude'] != null) {
            membersData.add({
              'lat': (location['latitude'] as num).toDouble(),
              'lng': (location['longitude'] as num).toDouble(),
              'name': data['name'] ?? 'Unknown',
              'branch': data['familyBranch'] ?? 'Unknown',
            });
          }
        }

        processed += batch.length;
        if (processed < snapshot.docs.length) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      if (membersData.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("No location data available"))
          );
        }
        return;
      }

      final encoded = jsonEncode(membersData);
      debugPrint("Sending ${membersData.length} locations to heatmap");

      // Robust JS communication
      int retries = 3;
      while (retries > 0 && mounted) {
        try {
          final result = await _controller.runJavaScriptReturningResult('''
          (function() {
            try {
              if (typeof updateHeatmap === 'function') {
                updateHeatmap($encoded);
                return true;
              }
              return false;
            } catch(e) {
              return false;
            }
          })()
        ''');

          if (result == 'true') break;
          await Future.delayed(const Duration(milliseconds: 300));
        } catch (e) {
          debugPrint("JS execution attempt failed: $e");
        }
        retries--;
      }

    } catch (e, stack) {
      debugPrint("Error loading heatmap data: $e");
      debugPrint(stack.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: ${e.toString()}"))
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.green[200],
        foregroundColor: Colors.green[800],
        title: Text(
          "User Residences",
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
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}