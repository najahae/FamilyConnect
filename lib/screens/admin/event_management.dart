import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminEventsPage extends StatefulWidget {
  const AdminEventsPage({super.key});

  @override
  State<AdminEventsPage> createState() => _AdminEventsPageState();
}

class _AdminEventsPageState extends State<AdminEventsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  String? _selectedFamilyId;
  TextEditingController _searchController = TextEditingController();
  List<String> _familyIds = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    _loadFamilies();
  }

  Future<void> _loadFamilies() async {
    final snapshot = await _firestore.collection('families').get();
    _familyIds = snapshot.docs.map((doc) => doc.id).toList();
    setState(() {});
  }

  void _viewFamilyEvents(String familyId) {
    setState(() {
      _selectedFamilyId = familyId;
    });
  }

  void _goBack() {
    setState(() {
      _selectedFamilyId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.green[200],
        foregroundColor: Colors.green[900],
        title: Text(
          _selectedFamilyId == null ? 'Family Management' : 'Family Events',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        leading: _selectedFamilyId != null
            ? IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.green[900]),
          onPressed: _goBack,
        )
            : null,
        actions: _selectedFamilyId == null
            ? [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.green[900]),
            onPressed: _loadFamilies,
          ),
        ]
            : null,
      ),
      body: _selectedFamilyId == null ? _buildFamilyList() : _buildEventTabs(),
    );
  }

  Widget _buildFamilyList() {
    final filteredFamilies = _familyIds.where((id) => id.toLowerCase().contains(_searchQuery)).toList();

    return Column(
      children: [
        // Search Section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Search Families',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Type family ID to search...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: Icon(Icons.search, color: Colors.green[600], size: 22),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[500], size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Family Count Badge
        if (filteredFamilies.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 16, left: 20, right: 20),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${filteredFamilies.length} ${filteredFamilies.length == 1 ? 'Family' : 'Families'} Found',
              style: TextStyle(
                color: Colors.green[800],
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),

        // Family List
        Expanded(
          child: filteredFamilies.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: filteredFamilies.length,
            itemBuilder: (context, index) {
              final familyId = filteredFamilies[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.08),
                      spreadRadius: 1,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green[400]!, Colors.green[600]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.family_restroom,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    familyId,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    'Tap to view events',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                  trailing: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.green[700],
                      size: 18,
                    ),
                  ),
                  onTap: () => _viewFamilyEvents(familyId),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(
              Icons.search_off,
              size: 60,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isEmpty ? 'No Families Found' : 'No matching families',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'There are no families in the system yet'
                : 'Try adjusting your search terms',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventTabs() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              labelColor: Colors.green[700],
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Colors.green[600],
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
              tabs: const [
                Tab(text: 'History'),
                Tab(text: 'Ongoing'),
                Tab(text: 'Upcoming'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildEventList('history'),
                _buildEventList('ongoing'),
                _buildEventList('upcoming'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList(String category) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('families')
          .doc(_selectedFamilyId)
          .collection('events')
          .orderBy('date')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          );
        }

        final now = DateTime.now();
        final todayStr = DateFormat('yyyy-MM-dd').format(now);
        final events = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final dateStr = data['date'];
          try {
            final date = DateFormat('yyyy-MM-dd').parse(dateStr);
            if (category == 'history') return date.isBefore(now);
            if (category == 'ongoing') return dateStr == todayStr;
            return date.isAfter(now);
          } catch (_) {
            return false;
          }
        }).toList();

        if (events.isEmpty) {
          return _buildEmptyEventState(category);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final doc = events[index];
            final data = doc.data() as Map<String, dynamic>;
            final title = data['title'] ?? 'Untitled Event';
            final date = data['date'] ?? '';
            final location = _formatLocation(data['location']);

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(20),
                leading: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _getEventGradient(category),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    _getEventIcon(category),
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                title: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          date,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (location != 'Not specified') ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                trailing: Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.visibility,
                      color: Colors.green[700],
                      size: 22,
                    ),
                    onPressed: () => _showEventDetails(context, _selectedFamilyId!, doc.id, data),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyEventState(String category) {
    String message = '';
    IconData icon = Icons.event_busy;

    switch (category) {
      case 'history':
        message = 'No past events found';
        icon = Icons.history;
        break;
      case 'ongoing':
        message = 'No events happening today';
        icon = Icons.event_available;
        break;
      case 'upcoming':
        message = 'No upcoming events scheduled';
        icon = Icons.event_note;
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              icon,
              size: 50,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getEventGradient(String category) {
    switch (category) {
      case 'history':
        return [Colors.grey[400]!, Colors.grey[600]!];
      case 'ongoing':
        return [Colors.orange[400]!, Colors.orange[600]!];
      case 'upcoming':
        return [Colors.blue[400]!, Colors.blue[600]!];
      default:
        return [Colors.green[400]!, Colors.green[600]!];
    }
  }

  IconData _getEventIcon(String category) {
    switch (category) {
      case 'history':
        return Icons.history;
      case 'ongoing':
        return Icons.play_circle_fill;
      case 'upcoming':
        return Icons.upcoming;
      default:
        return Icons.event;
    }
  }

  void _showEventDetails(
      BuildContext context,
      String familyID,
      String eventId,
      Map<String, dynamic> data,
      ) async {
    List<dynamic> invitedIds = data['invitedMemberIds'] ?? [];
    List<String> invitedNames = [];
    final location = data['location'];
    final hasValidLocation = _isLocationValid(location);

    for (var id in invitedIds) {
      final doc = await FirebaseFirestore.instance
          .collection('families')
          .doc(familyID)
          .collection('family_members')
          .doc(id)
          .get();
      if (doc.exists) {
        invitedNames.add(doc.data()?['fullName'] ?? 'Unknown');
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[400]!, Colors.green[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.event, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                data['title'] ?? 'Event Details',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailCard(
                icon: Icons.calendar_today,
                label: 'Date',
                value: data['date'] ?? 'Not specified',
                color: Colors.blue,
              ),
              _buildDetailCard(
                icon: Icons.access_time,
                label: 'Time',
                value: '${data['startTime'] ?? 'N/A'} - ${data['endTime'] ?? 'N/A'}',
                color: Colors.orange,
              ),
              _buildDetailCard(
                icon: Icons.location_on,
                label: 'Location',
                value: _formatLocation(data['location']),
                color: Colors.red,
              ),
              if (hasValidLocation)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.directions, size: 18),
                    label: const Text('View Directions on Google Maps'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.green[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                    onPressed: () => _launchDirections(location),
                  ),
                ),
              if (data['dressCodeMale'] != null)
                _buildDetailCard(
                  icon: Icons.person,
                  label: 'Dress Code (Male)',
                  value: data['dressCodeMale'],
                  color: Colors.purple,
                ),
              if (data['dressCodeFemale'] != null)
                _buildDetailCard(
                  icon: Icons.person_outline,
                  label: 'Dress Code (Female)',
                  value: data['dressCodeFemale'],
                  color: Colors.pink,
                ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.people, color: Colors.green[600], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Invited Members (${invitedNames.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (invitedNames.isEmpty)
                      Text(
                        'No members invited',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    else
                      ...invitedNames.map((name) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.person, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              name,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      )).toList(),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
            ),
            child: const Text("Close"),
          ),
          TextButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: ctx,
                builder: (confirmCtx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Delete Event'),
                  content: const Text('Are you sure you want to delete this event? This action cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(confirmCtx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(confirmCtx, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await FirebaseFirestore.instance
                    .collection('families')
                    .doc(familyID)
                    .collection('events')
                    .doc(eventId)
                    .delete();

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text("Event deleted successfully"),
                    backgroundColor: Colors.red[600],
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              backgroundColor: Colors.red[50],
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String label,
    required String value,
    required MaterialColor color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color[100]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: color[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color[700],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value ?? 'Not specified')),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteEvent(BuildContext context, DocumentReference eventRef) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text('Are you sure you want to delete this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ??
        false;

    if (confirm) {
      await eventRef.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event deleted successfully')),
        );
      }
    }
  }

  String _formatLocation(dynamic location) {
    if (location == null) return 'Not specified';
    if (location is Map && location.containsKey('lat') && location.containsKey('lng')) {
      return 'Location: ${location['lat'].toStringAsFixed(3)}, ${location['lng'].toStringAsFixed(3)}';
    }
    if (location is String) return location;
    return location.toString();
  }

  bool _isLocationValid(dynamic location) {
    if (location == null) return false;
    if (location is Map) return location.containsKey('lat') && location.containsKey('lng');
    return false;
  }

  Future<void> _launchDirections(dynamic location) async {
    String url = '';
    if (location is Map) {
      url = 'https://www.google.com/maps/dir/?api=1&destination=${location['lat']},${location['lng']}';
    }
    if (url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }
}