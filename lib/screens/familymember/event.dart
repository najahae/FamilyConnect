import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'location_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EventPage extends StatefulWidget {
  final String familyID;
  final String role;
  const EventPage({Key? key, required this.familyID, this.role = 'family_member',}) : super(key: key);

  @override
  State<EventPage> createState() => _EventPageState();
}

class _EventPageState extends State<EventPage> with SingleTickerProviderStateMixin {
  DateTime _selectedDay = DateTime.now();
  List<DocumentSnapshot> _events = [];
  Set<DateTime> _markedEventDates = {};
  late TabController _tabController;
  List<DocumentSnapshot> _allEvents = []; // For storing all events for the family

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAllEvents();
    _fetchEventsForSelectedDay();
    _fetchMarkedDates(_selectedDay);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllEvents() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final isModerator = widget.role == 'moderator';

    final snapshot = await FirebaseFirestore.instance
        .collection('families')
        .doc(widget.familyID)
        .collection('events')
        .orderBy('date')
        .get();

    setState(() {
      _allEvents = snapshot.docs.where((doc) {
        if (isModerator) return true;
        final invitedIds = doc.data()['invitedMemberIds'] as List<dynamic>?;
        return invitedIds == null || invitedIds.contains(currentUserId);
      }).toList();
    });
  }

  Future<void> _fetchEventsForSelectedDay() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final isModerator = widget.role == 'moderator';

    final snapshot = await FirebaseFirestore.instance
        .collection('families')
        .doc(widget.familyID)
        .collection('events')
        .where('date', isEqualTo: DateFormat('yyyy-MM-dd').format(_selectedDay))
        .get();

    setState(() {
      _events = snapshot.docs.where((doc) {
        if (isModerator) return true;
        final invitedIds = doc.data()['invitedMemberIds'] as List<dynamic>?;
        return invitedIds == null || invitedIds.contains(currentUserId);
      }).toList();
    });
  }

  Future<void> _fetchMarkedDates(DateTime focusedDay) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final isModerator = widget.role == 'moderator';

    final startOfMonth = DateTime(focusedDay.year, focusedDay.month, 1);
    final endOfMonth = DateTime(focusedDay.year, focusedDay.month + 1, 0);

    final snapshot = await FirebaseFirestore.instance
        .collection('families')
        .doc(widget.familyID)
        .collection('events')
        .where('date', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(startOfMonth))
        .where('date', isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(endOfMonth))
        .get();

    final dates = snapshot.docs.where((doc) {
      if (isModerator) return true;
      final invitedIds = doc.data()['invitedMemberIds'] as List<dynamic>?;
      return invitedIds == null || invitedIds.contains(currentUserId);
    }).map((doc) {
      final dateStr = doc['date'] as String;
      return DateFormat('yyyy-MM-dd').parse(dateStr);
    }).toSet();

    setState(() {
      _markedEventDates = dates;
    });
  }

  // Helper method to categorize events
  List<DocumentSnapshot> _getEventsByCategory(String category) {
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);

    return _allEvents.where((event) {
      final eventDate = event['date'] as String;
      final eventDateTime = DateFormat('yyyy-MM-dd').parse(eventDate);

      if (category == 'history') {
        return eventDate.compareTo(today) < 0;
      } else if (category == 'ongoing') {
        if (eventDate != today) return false;

        // Check if current time is between start and end time
        try {
          final startTimeStr = event['startTime'] as String? ?? '';
          final endTimeStr = event['endTime'] as String? ?? '';

          if (startTimeStr.isEmpty || endTimeStr.isEmpty) return false;

          final startTime = _parseTimeString(startTimeStr);
          final endTime = _parseTimeString(endTimeStr);

          final currentTime = TimeOfDay.fromDateTime(now);

          return (currentTime.hour > startTime.hour ||
              (currentTime.hour == startTime.hour && currentTime.minute >= startTime.minute)) &&
              (currentTime.hour < endTime.hour ||
                  (currentTime.hour == endTime.hour && currentTime.minute <= endTime.minute));
        } catch (e) {
          return false;
        }
      } else { // upcoming
        return eventDate.compareTo(today) > 0 ||
            (eventDate == today &&
                (_parseTimeString(event['startTime'] as String? ?? '').hour > TimeOfDay.fromDateTime(now).hour ||
                    (_parseTimeString(event['startTime'] as String? ?? '').hour == TimeOfDay.fromDateTime(now).hour &&
                        _parseTimeString(event['startTime'] as String? ?? '').minute > TimeOfDay.fromDateTime(now).minute)));
      }
    }).toList();
  }

  TimeOfDay _parseTimeString(String timeStr) {
    final parts = timeStr.split(' ');
    final timePart = parts[0].split(':');
    final hour = int.parse(timePart[0]);
    final minute = int.parse(timePart[1]);
    final isPM = parts.length > 1 && parts[1].toUpperCase() == 'PM';

    return TimeOfDay(
      hour: isPM && hour != 12 ? hour + 12 : hour == 12 && !isPM ? 0 : hour,
      minute: minute,
    );
  }

  Future<List<Map<String, String>>> _fetchFamilyMembers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('families')
        .doc(widget.familyID)
        .collection('family_members')
        .get();

    return snapshot.docs.map((doc) {
      final fullName = (doc['fullName'] ?? '').toString();
      final nickname = (doc['nickname'] ?? '').toString();
      final display = nickname.isNotEmpty ? '$fullName ($nickname)' : fullName;

      return {
        'id': doc.id,
        'display': display,
      };
    }).toList();
  }

  Future<List<String>> _getInvitedMemberNames(List<dynamic> memberIds) async {
    List<String> names = [];

    for (final id in memberIds) {
      final doc = await FirebaseFirestore.instance
          .collection('families')
          .doc(widget.familyID)
          .collection('family_members')
          .doc(id)
          .get();

      if (doc.exists) {
        final name = doc.data()?['fullName'] ?? '[Unknown]';
        names.add(name);
      }
    }

    return names;
  }

  // Function to open Google Maps with directions
  Future<void> _openGoogleMapsDirections(dynamic location) async {
    String url = '';

    if (location is Map<String, dynamic>) {
      // Map location with coordinates
      final lat = location['lat'];
      final lng = location['lng'];
      url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    } else if (location is String && location.isNotEmpty) {
      // Text location
      final encodedLocation = Uri.encodeComponent(location);
      url = 'https://www.google.com/maps/dir/?api=1&destination=$encodedLocation';
    }

    if (url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open Google Maps')),
          );
        }
      }
    }
  }

  // Check if current user can edit/delete the event
  bool _canModifyEvent(DocumentSnapshot eventDoc) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return false;

    // Moderators can modify all events
    if (widget.role == 'moderator') return true;

    // Event creator can modify their own events
    final eventData = eventDoc.data() as Map<String, dynamic>;
    final createdBy = eventData['createdBy'] as String?;
    return createdBy == currentUserId;
  }

  void _showAddEventDialog({DocumentSnapshot? existingEvent}) async {
    final titleController = TextEditingController(text: existingEvent?['title'] ?? '');
    final locationController = TextEditingController(text: existingEvent != null && existingEvent!['location'] is String ? existingEvent['location'] : '');
    final dressCodeMaleController = TextEditingController(text: existingEvent?['dressCodeMale'] ?? '');
    final dressCodeFemaleController = TextEditingController(text: existingEvent?['dressCodeFemale'] ?? '');

    bool useMap = existingEvent != null && existingEvent!['location'] is Map<String, dynamic>;
    LatLng? pickedMapLocation = useMap
        ? LatLng(existingEvent!['location']['lat'], existingEvent['location']['lng'])
        : null;

    // Time dropdown initial values (parse from existing event if any)
    String startHour = '12';
    String startMinute = '00';
    String startPeriod = 'AM';

    String endHour = '12';
    String endMinute = '00';
    String endPeriod = 'AM';

    // Helper to parse time string like "10:30 AM"
    void parseTime(String time, void Function(String h, String m, String p) setTime) {
      if (time.isEmpty) return;
      final parts = time.split(' ');
      if (parts.length != 2) return;
      final hm = parts[0].split(':');
      if (hm.length != 2) return;
      setTime(hm[0], hm[1], parts[1]);
    }

    if (existingEvent != null) {
      parseTime(existingEvent['startTime'] ?? '', (h, m, p) {
        startHour = h;
        startMinute = m;
        startPeriod = p;
      });
      parseTime(existingEvent['endTime'] ?? '', (h, m, p) {
        endHour = h;
        endMinute = m;
        endPeriod = p;
      });
    }

    List<String> selectedMembers = List<String>.from(existingEvent?['invitedMemberIds'] ?? []);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existingEvent == null ? 'Add Event' : 'Edit Event'),
        content: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 350), // Not too wide, not too slim
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(titleController, 'Title'),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: useMap,
                        onChanged: (val) => setState(() {
                          useMap = val ?? false;
                          if (!useMap) pickedMapLocation = null;
                        }),
                      ),
                      const Text('Use Map Location'),
                    ],
                  ),

                  if (useMap) ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.map),
                      label: const Text("Pick Location"),
                      onPressed: () async {
                        final location = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => LocationPicker()),
                        );
                        if (location != null) {
                          setState(() {
                            pickedMapLocation = location;
                          });
                        }
                      },
                    ),
                    if (pickedMapLocation != null)
                      Container(
                        height: 150,
                        margin: const EdgeInsets.only(top: 8),
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: pickedMapLocation!,
                            zoom: 15,
                          ),
                          markers: {
                            Marker(
                              markerId: MarkerId('picked_location'),
                              position: pickedMapLocation!,
                            ),
                          },
                          zoomControlsEnabled: false,
                          myLocationButtonEnabled: false,
                          scrollGesturesEnabled: false,
                          tiltGesturesEnabled: false,
                          rotateGesturesEnabled: false,
                        ),
                      ),
                  ] else
                    _buildTextField(locationController, 'Location'),

                  const SizedBox(height: 12),
                  const Text('Start Time:'),
                  Row(
                    children: [
                      Expanded(child: _buildTimeDropdown(startHour, List.generate(12, (i) => '${i + 1}'), (val) => setState(() => startHour = val))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTimeDropdown(startMinute, ['00','15','30','45'], (val) => setState(() => startMinute = val))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTimeDropdown(startPeriod, ['AM','PM'], (val) => setState(() => startPeriod = val))),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Text('End Time:'),
                  Row(
                    children: [
                      Expanded(child: _buildTimeDropdown(endHour, List.generate(12, (i) => '${i + 1}'), (val) => setState(() => endHour = val))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTimeDropdown(endMinute, ['00','15','30','45'], (val) => setState(() => endMinute = val))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildTimeDropdown(endPeriod, ['AM','PM'], (val) => setState(() => endPeriod = val))),
                    ],
                  ),

                  const SizedBox(height: 12),
                  _buildTextField(dressCodeMaleController, 'Dress Code (Male)'),
                  const SizedBox(height: 12),
                  _buildTextField(dressCodeFemaleController, 'Dress Code (Female)'),
                  const SizedBox(height: 12),

                  FutureBuilder<List<Map<String, String>>>(
                    future: _fetchFamilyMembers(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const CircularProgressIndicator();
                      final members = snapshot.data!;
                      return MultiSelectDialogField(
                        items: members
                            .map((m) => MultiSelectItem<String>(m['id']!, m['display']!))
                            .toList(),
                        initialValue: selectedMembers,
                        searchable: true,
                        title: const Text("Invite Family Members"),
                        buttonText: const Text("Select Members"),
                        listType: MultiSelectListType.CHIP,
                        onConfirm: (values) {
                          setState(() {
                            selectedMembers = values.cast<String>();
                          });
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              // Compose start and end time string
              final composedStartTime = '$startHour:$startMinute $startPeriod';
              final composedEndTime = '$endHour:$endMinute $endPeriod';

              final eventData = {
                'title': titleController.text.trim(),
                'location': useMap && pickedMapLocation != null
                    ? {
                  'lat': pickedMapLocation!.latitude,
                  'lng': pickedMapLocation!.longitude,
                }
                    : locationController.text.trim(),
                'startTime': composedStartTime,
                'endTime': composedEndTime,
                'dressCodeMale': dressCodeMaleController.text.trim(),
                'dressCodeFemale': dressCodeFemaleController.text.trim(),
                'invitedMemberIds': selectedMembers,
                'date': DateFormat('yyyy-MM-dd').format(_selectedDay),
              };

              // Add createdBy field for new events
              if (existingEvent == null) {
                eventData['createdBy'] = FirebaseAuth.instance.currentUser?.uid ?? '';
                eventData['createdAt'] = FieldValue.serverTimestamp();
              } else {
                eventData['updatedAt'] = FieldValue.serverTimestamp();
              }

              final eventsCollection = FirebaseFirestore.instance
                  .collection('families')
                  .doc(widget.familyID)
                  .collection('events');

              if (existingEvent == null) {
                await eventsCollection.add(eventData);
              } else {
                await eventsCollection.doc(existingEvent.id).update(eventData);
              }

              Navigator.pop(context);
              _fetchEventsForSelectedDay();

            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  bool _isLocationValidForDirections(dynamic location) {
    if (location == null) return false;

    // Map location (coordinates) is always valid for directions
    if (location is Map<String, dynamic>) {
      return location.containsKey('lat') && location.containsKey('lng');
    }

    // For string locations, only show directions if it's not manually entered
    // You can implement your own logic here. Some options:

    // Option 1: Check if it contains coordinates-like pattern
    if (location is String && location.isNotEmpty) {
      // Check if it looks like coordinates (contains numbers and comma/space)
      final coordPattern = RegExp(r'^-?\d+\.?\d*[,\s]+-?\d+\.?\d*$');
      if (coordPattern.hasMatch(location.trim())) {
        return true;
      }

      // Check if it's a recognizable address format (contains common address keywords)
      final addressKeywords = ['street', 'road', 'avenue', 'boulevard', 'lane', 'drive', 'plaza', 'square'];
      final lowerLocation = location.toLowerCase();
      if (addressKeywords.any((keyword) => lowerLocation.contains(keyword))) {
        return true;
      }

      // You can add more sophisticated checks here
      return false;
    }

    return false;
  }

  void _showEventDetailsDialog(DocumentSnapshot eventDoc) async {
    final data = eventDoc.data() as Map<String, dynamic>;
    final List<dynamic> invitedIds = data['invitedMemberIds'] ?? [];
    final canModify = _canModifyEvent(eventDoc);

    final memberDocs = await Future.wait(invitedIds.map((id) {
      return FirebaseFirestore.instance
          .collection('families')
          .doc(widget.familyID)
          .collection('family_members')
          .doc(id)
          .get();
    }));

    final List<Map<String, dynamic>> invitedMembers = await Future.wait(
      memberDocs.map((doc) async {
        final uid = doc.id;
        final name = doc['fullName'] ?? 'Unknown';
        final nickname = doc['nickname'] ?? '';
        final initials = name.isNotEmpty ? name.trim().split(" ").map((e) => e[0]).take(2).join().toUpperCase() : '?';

        // Get RSVP status
        final notifDoc = await FirebaseFirestore.instance
            .collection("families")
            .doc(widget.familyID)
            .collection("family_members")
            .doc(uid)
            .collection("notifications")
            .where("eventId", isEqualTo: eventDoc.id)
            .limit(1)
            .get();

        final rsvp = notifDoc.docs.isNotEmpty
            ? (notifDoc.docs.first.data()['rsvpStatus'] ?? 'Pending')
            : 'Pending';

        return {
          'name': name,
          'nickname': nickname,
          'initials': initials,
          'rsvp': rsvp,
        };
      }),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['title'] ?? 'Event Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text("📍 Location: ${data['location'] is String ? data['location'] : 'Pinned Map'}"),
                  ),
                  if (_isLocationValidForDirections(data['location']))
                    IconButton(
                      icon: const Icon(Icons.directions, color: Colors.blue),
                      tooltip: 'Get Directions',
                      onPressed: () => _openGoogleMapsDirections(data['location']),
                    ),
                ],
              ),
              Text("🕒 ${data['startTime']} - ${data['endTime']}"),
              if ((data['dressCodeMale'] ?? '').isNotEmpty)
                Text("👔 Dress Code (Male): ${data['dressCodeMale']}"),
              if ((data['dressCodeFemale'] ?? '').isNotEmpty)
                Text("👗 Dress Code (Female): ${data['dressCodeFemale']}"),
              const SizedBox(height: 12),
              Text("Invited Members", style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: invitedMembers.map((m) {
                  return GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text(m['name']),
                          content: Text(m['nickname'].isNotEmpty ? "Nickname: ${m['nickname']}" : "No nickname"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: Text("Close")),
                          ],
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        CircleAvatar(
                          child: Text(m['initials'], style: TextStyle(color: Colors.white)),
                          backgroundColor: Colors.green,
                        ),
                        const SizedBox(height: 4),
                        Text(m['rsvp'], style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          if (canModify) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showAddEventDialog(existingEvent: eventDoc);
              },
              child: const Text("Edit", style: TextStyle(color: Colors.orange)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _confirmDeleteEvent(eventDoc.id);
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteEvent(String eventId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text('Are you sure you want to delete this event?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
            onPressed: () async {
              Navigator.pop(context); // Close the dialog
              await FirebaseFirestore.instance
                  .collection('families')
                  .doc(widget.familyID)
                  .collection('events')
                  .doc(eventId)
                  .delete();

              _fetchEventsForSelectedDay();
              // Refresh the list
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimeDropdown(String currentValue, List<String> options, void Function(String) onChanged) {
    return DropdownButton<String>(
      value: currentValue,
      items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
      onChanged: (val) {
        if (val != null) onChanged(val);
      },
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(25),
            bottomRight: Radius.circular(25),
          ),
          child: AppBar(
            backgroundColor: Colors.green[200],
            centerTitle: true,
            title: const Text("Event", style: TextStyle(fontWeight: FontWeight.bold)),
            automaticallyImplyLeading: false,
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Calendar'),
                Tab(text: 'History'),
                Tab(text: 'Upcoming'),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
        onPressed: _showAddEventDialog,
        child: const Icon(Icons.add),
      )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          // Calendar Tab
          Column(
            children: [
              TableCalendar(
                firstDay: DateTime(2000),
                lastDay: DateTime(2100),
                focusedDay: _selectedDay,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Month',
                },
                selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                  });
                  _fetchEventsForSelectedDay();
                },
                onPageChanged: (focusedDay) {
                  setState(() {
                    _selectedDay = focusedDay;
                  });
                  _fetchMarkedDates(focusedDay);
                  _fetchEventsForSelectedDay();
                },
                calendarStyle: const CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Colors.brown,
                    shape: BoxShape.circle,
                  ),
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    if (_markedEventDates.contains(DateTime(date.year, date.month, date.day))) {
                      return Positioned(
                        bottom: 4,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red,
                          ),
                        ),
                      );
                    }
                    return null;
                  },
                ),
              ),
              Expanded(
                child: _buildEventList(_events),
              ),
            ],
          ),
          // History Tab
          _buildEventList(_getEventsByCategory('history')),
          // Upcoming Tab
          _buildEventList(_getEventsByCategory('upcoming')),
        ],
      ),
    );
  }

  Widget _buildEventList(List<DocumentSnapshot> events) {
    if (events.isEmpty) {
      return const Center(
        child: Text('No events found'),
      );
    }

    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index].data() as Map<String, dynamic>;
        final canModify = _canModifyEvent(events[index]);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
          child: InkWell(
            onTap: () => _showEventDetailsDialog(events[index]),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event['title'] ?? 'Untitled',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (canModify && _tabController.index == 0) ...[
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.orange, size: 20),
                          onPressed: () => _showAddEventDialog(existingEvent: events[index]),
                          tooltip: 'Edit Event',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          onPressed: () => _confirmDeleteEvent(events[index].id),
                          tooltip: 'Delete Event',
                        ),
                      ],
                      if (_isLocationValidForDirections(event['location']))
                        IconButton(
                          icon: const Icon(Icons.directions, color: Colors.blue, size: 20),
                          onPressed: () => _openGoogleMapsDirections(event['location']),
                          tooltip: 'Get Directions',
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "📅 Date: ${event['date']}",
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    "🕒 From ${event['startTime']} to ${event['endTime']}",
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  if ((event['dressCodeMale'] ?? '').isNotEmpty)
                    Text("👔 Male Dress Code: ${event['dressCodeMale']}"),
                  if ((event['dressCodeFemale'] ?? '').isNotEmpty)
                    Text("👗 Female Dress Code: ${event['dressCodeFemale']}"),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}