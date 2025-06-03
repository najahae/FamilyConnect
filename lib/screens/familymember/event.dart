import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'location_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:table_calendar/table_calendar.dart';

class EventPage extends StatefulWidget {
  final String familyID;
  const EventPage({Key? key, required this.familyID}) : super(key: key);

  @override
  State<EventPage> createState() => _EventPageState();
}

class _EventPageState extends State<EventPage> {
  DateTime _selectedDay = DateTime.now();
  List<DocumentSnapshot> _events = [];
  Set<DateTime> _markedEventDates = {};

  @override
  void initState() {
    super.initState();
    _fetchEventsForSelectedDay();
    _fetchMarkedDates(_selectedDay);
  }

  Future<void> _fetchEventsForSelectedDay() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('families')
        .doc(widget.familyID)
        .collection('events')
        .where('date', isEqualTo: DateFormat('yyyy-MM-dd').format(_selectedDay))
        .get();

    setState(() {
      _events = snapshot.docs;
    });
  }

  Future<void> _fetchMarkedDates(DateTime focusedDay) async {
    final startOfMonth = DateTime(focusedDay.year, focusedDay.month, 1);
    final endOfMonth = DateTime(focusedDay.year, focusedDay.month + 1, 0);

    final snapshot = await FirebaseFirestore.instance
        .collection('families')
        .doc(widget.familyID)
        .collection('events')
        .where('date', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(startOfMonth))
        .where('date', isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(endOfMonth))
        .get();

    final dates = snapshot.docs.map((doc) {
      final dateStr = doc['date'] as String;
      return DateFormat('yyyy-MM-dd').parse(dateStr);
    }).toSet();

    setState(() {
      _markedEventDates = dates;
    });
  }


  Future<List<String>> _fetchFamilyMembers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('families')
        .doc(widget.familyID)
        .collection('family_members')
        .get();

    return snapshot.docs.map((doc) => doc['fullName'] as String).toList();
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

    List<String> selectedMembers = List<String>.from(existingEvent?['invitedMembers'] ?? []);

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

                  FutureBuilder<List<String>>(
                    future: _fetchFamilyMembers(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const CircularProgressIndicator();
                      return MultiSelectDialogField<String>(
                        items: snapshot.data!.map((e) => MultiSelectItem(e, e)).toList(),
                        initialValue: selectedMembers,
                        title: const Text("Invite Family Members"),
                        buttonText: const Text("Select Members"),
                        listType: MultiSelectListType.CHIP,
                        onConfirm: (values) {
                          selectedMembers = values;
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
                'invitedMembers': selectedMembers,
                'date': DateFormat('yyyy-MM-dd').format(_selectedDay),
              };

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
        preferredSize: const Size.fromHeight(60),
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
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEventDialog,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime(2000),
            lastDay: DateTime(2100),
            focusedDay: _selectedDay,
            selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
              });
              _fetchEventsForSelectedDay();
            },
            onPageChanged: (focusedDay) {
              _fetchMarkedDates(focusedDay);
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
            child: ListView.builder(
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final event = _events[index].data() as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.all(8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event['title'] ?? 'Untitled',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),

                        Text(
                          "🕒 From ${event['startTime']} to ${event['endTime']}",
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 8),

                        if (event['location'] is String) ...[
                          Text(
                            "📍 Location: ${event['location']}",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ] else if (event['location'] is Map<String, dynamic>) ...[
                          const Text(
                            "📌 Pinned Location:",
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final lat = event['location']['lat'];
                              final lng = event['location']['lng'];

                              return GestureDetector(
                                onTap: () async {
                                  final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

                                  try {
                                    if (!await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication)) {
                                      throw 'Could not launch';
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Could not open Google Maps.')),
                                    );
                                  }
                                },
                                child: SizedBox(
                                  height: 160,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: GoogleMap(
                                      initialCameraPosition: CameraPosition(
                                        target: LatLng(lat, lng),
                                        zoom: 15,
                                      ),
                                      markers: {
                                        Marker(
                                          markerId: const MarkerId('eventLocation'),
                                          position: LatLng(lat, lng),
                                        ),
                                      },
                                      zoomControlsEnabled: false,
                                      myLocationButtonEnabled: false,
                                      scrollGesturesEnabled: false,
                                      rotateGesturesEnabled: false,
                                      tiltGesturesEnabled: false,
                                      mapToolbarEnabled: false,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],

                        const SizedBox(height: 8),

                        if ((event['dressCodeMale'] ?? '').isNotEmpty || (event['dressCodeFemale'] ?? '').isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ((event['dressCodeMale'] ?? '').isNotEmpty)
                                Text("👔 Male Dress Code: ${event['dressCodeMale']}"),
                              if ((event['dressCodeFemale'] ?? '').isNotEmpty)
                                Text("👗 Female Dress Code: ${event['dressCodeFemale']}"),
                              const SizedBox(height: 8),
                            ],
                          ),

                        if (event['invitedMembers'] != null && event['invitedMembers'] is List)
                          Text(
                            "Invited: ${(event['invitedMembers'] as List).join(', ')}",
                            style: const TextStyle(fontSize: 14),
                          ),

                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                _showAddEventDialog(existingEvent: _events[index]);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Edit'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () {
                                _confirmDeleteEvent(_events[index].id);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
