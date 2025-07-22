import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HeatMapWebView extends StatefulWidget {
  final String familyID;
  const HeatMapWebView({Key? key, required this.familyID}) : super(key: key);

  @override
  State<HeatMapWebView> createState() => _HeatMapWebViewState();
}

class _HeatMapWebViewState extends State<HeatMapWebView> {
  late final WebViewController _controller;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadFlutterAsset('assets/html/heatmap.html')
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          setState(() => _isLoaded = true);
          _sendDataToWebView();
        },
      ));
  }

  Future<void> _sendDataToWebView() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('families')
        .doc(widget.familyID)
        .collection('family_members')
        .get();

    final coords = <List<double>>[];

    for (var doc in snapshot.docs) {
      final location = doc.data()['location'];
      if (location != null &&
          location['latitude'] != null &&
          location['longitude'] != null) {
        coords.add([location['latitude'], location['longitude']]);
      }
    }

    if (coords.isEmpty) {
      debugPrint("No coordinate data available");
      return;
    }

    final encoded = jsonEncode(coords);
    debugPrint("Sending heatmap data: $encoded");

    // Retry mechanism in case WebView isn't ready
    int attempts = 0;
    while (attempts < 3) {
      try {
        await _controller.runJavaScript('''
          if (typeof updateHeatmap === 'function') {
            updateHeatmap(`$encoded`);
          }
        ''');
        break;
      } catch (e) {
        attempts++;
        debugPrint("Attempt $attempts failed: $e");
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Residence Heatmap'),
        backgroundColor: Colors.green[200],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
