import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:sist_link1/screens/events/create_event_screen.dart';
import 'package:sist_link1/screens/profile/profile_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  DocumentSnapshot? _eventDataSnapshot;
  Map<String, dynamic>?
  _creatorUserData; // Will still fetch username, but not use PFP
  List<Map<String, dynamic>> _attendeesData = [];
  bool _isLoading = true;
  bool _isCurrentUserAttending = false;
  bool _isProcessingRSVP = false;
  String? _currentUserId;
  bool _canViewEvent = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _loadEventDetails();
  }

  Future<void> _loadEventDetails() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final eventDoc =
          await FirebaseFirestore.instance
              .collection('events')
              .doc(widget.eventId)
              .get();
      if (eventDoc.exists) {
        _eventDataSnapshot = eventDoc;
        final eventMap = eventDoc.data() as Map<String, dynamic>;

        bool isPrivate = eventMap['isPrivate'] ?? false;
        String creatorId = eventMap['creatorId'] ?? '';
        List<String> allowedUserIds = List<String>.from(
          eventMap['allowedUserIds'] ?? [],
        );

        if (!isPrivate) {
          _canViewEvent = true;
        } else {
          if (_currentUserId != null &&
              (creatorId == _currentUserId ||
                  allowedUserIds.contains(_currentUserId))) {
            _canViewEvent = true;
          } else {
            _canViewEvent = false;
          }
        }

        if (_canViewEvent) {
          if (creatorId.isNotEmpty) {
            final creatorDoc =
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(creatorId)
                    .get();
            if (creatorDoc.exists) {
              _creatorUserData = creatorDoc.data(); // Still fetch for username
            }
          }

          List<String> attendeeIds = List<String>.from(
            eventMap['attendees'] ?? [],
          );
          if (_currentUserId != null) {
            _isCurrentUserAttending = attendeeIds.contains(_currentUserId);
          }
          _attendeesData = [];
          if (attendeeIds.isNotEmpty) {
            final usersSnapshot =
                await FirebaseFirestore.instance
                    .collection('users')
                    .where(FieldPath.documentId, whereIn: attendeeIds)
                    .get();
            for (var userDoc in usersSnapshot.docs) {
              _attendeesData.add({
                // Not fetching 'profilePicUrl' anymore
                'id': userDoc.id,
                'username': userDoc.data()['username'] ?? 'Unknown',
              });
            }
          }
        }
      } else {
        _canViewEvent = false;
      }
    } catch (e) {
      print("Error loading event details: $e");
      _canViewEvent = false;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatEventTimestamp(Timestamp timestamp) {
    return DateFormat(
      'EEE, MMM d, yyyy \'at\' h:mm a',
    ).format(timestamp.toDate());
  }

  Future<void> _toggleRSVP() async {
    if (_currentUserId == null || _eventDataSnapshot == null || !_canViewEvent)
      return;
    setState(() => _isProcessingRSVP = true);
    final eventRef = FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId);
    try {
      if (_isCurrentUserAttending) {
        await eventRef.update({
          'attendees': FieldValue.arrayRemove([_currentUserId]),
        });
      } else {
        await eventRef.update({
          'attendees': FieldValue.arrayUnion([_currentUserId]),
        });
      }
      await _loadEventDetails();
    } catch (e) {
      print("Error toggling RSVP: $e");
    } finally {
      if (mounted) setState(() => _isProcessingRSVP = false);
    }
  }

  Future<void> _deleteEvent() async {
    if (_eventDataSnapshot == null ||
        _currentUserId !=
            (_eventDataSnapshot!.data() as Map<String, dynamic>)['creatorId'])
      return;
    bool confirmDelete =
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Delete'),
              content: const Text(
                'Are you sure you want to delete this event? This action cannot be undone.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirmDelete) {
      try {
        await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId)
            .delete();
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event deleted successfully.')),
          );
        }
      } catch (e) {
        print("Error deleting event: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete event.')),
          );
        }
      }
    }
  }

  Widget _buildDetailItem(
    IconData icon,
    String label,
    String value, {
    bool isLink = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueAccent[700], size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: isLink ? onTap : null,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      color: isLink ? Colors.blueAccent[700] : Colors.black87,
                      decoration:
                          isLink
                              ? TextDecoration.underline
                              : TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(
        appBar: null,
        body: Center(child: CircularProgressIndicator()),
      );

    if (!_canViewEvent || _eventDataSnapshot == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Event Not Found'),
          backgroundColor: Colors.white,
          elevation: 0.5,
          iconTheme: const IconThemeData(color: Colors.black87),
        ),
        body: const Center(
          child: Text('This event is private or does not exist.'),
        ),
      );
    }

    final data = _eventDataSnapshot!.data() as Map<String, dynamic>;
    final String eventName = data['eventName'] ?? 'Unnamed Event';
    final String description =
        data['description'] ?? 'No description provided.';
    final String location = data['location'] ?? 'No location specified.';
    final Timestamp eventTimestamp = data['eventDate'] ?? Timestamp.now();
    final String creatorId = data['creatorId'] ?? '';
    final String creatorUsername =
        _creatorUserData?['username'] ??
        data['creatorUsername'] ??
        'Unknown Creator';
    // final String? creatorProfilePicUrl = _creatorUserData?['profilePicUrl'] as String?; // No longer used for display
    final bool isUserCreator = _currentUserId == creatorId;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          eventName,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          if (isUserCreator)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder:
                            (context) => CreateEventScreen(
                              initialEventData: data,
                              eventId: widget.eventId,
                            ),
                      ),
                    )
                    .then((_) => _loadEventDetails());
              },
              tooltip: 'Edit Event',
            ),
          if (isUserCreator)
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red[700]),
              onPressed: _deleteEvent,
              tooltip: 'Delete Event',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadEventDetails,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.blueGrey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.event, size: 80, color: Colors.blueGrey[300]),
              ),
              const SizedBox(height: 20),
              Text(
                eventName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailItem(
                Icons.calendar_today_outlined,
                'DATE & TIME',
                _formatEventTimestamp(eventTimestamp),
              ),
              _buildDetailItem(
                Icons.location_on_outlined,
                'LOCATION',
                location,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      color: Colors.blueAccent[700],
                      size: 22,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "CREATED BY",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 2),
                          GestureDetector(
                            onTap: () {
                              if (creatorId.isNotEmpty) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder:
                                        (context) =>
                                            ProfileScreen(userId: creatorId),
                                  ),
                                );
                              }
                            },
                            child: Row(
                              children: [
                                CircleAvatar(
                                  // Default icon for creator
                                  radius: 12,
                                  backgroundColor: Colors.grey[300],
                                  child: Icon(
                                    Icons.person,
                                    size: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  creatorUsername,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.blueAccent[700],
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'About this event:',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[800],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: Icon(
                  _isCurrentUserAttending
                      ? Icons.check_circle_outline
                      : Icons.add_circle_outline,
                  color: Colors.white,
                ),
                label: Text(
                  _isCurrentUserAttending ? 'ATTENDING' : 'RSVP TO EVENT',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _isProcessingRSVP ? null : _toggleRSVP,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isCurrentUserAttending
                          ? Colors.green[600]
                          : Colors.blueAccent[700],
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              if (_isProcessingRSVP)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              const SizedBox(height: 24),
              Text(
                'Attendees (${_attendeesData.length})',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _attendeesData.isEmpty
                  ? const Text(
                    'No attendees yet. Be the first to RSVP!',
                    style: TextStyle(color: Colors.grey),
                  )
                  : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _attendeesData.length,
                    itemBuilder: (context, index) {
                      final attendee = _attendeesData[index];
                      return ListTile(
                        leading: CircleAvatar(
                          // Default icon for attendees
                          backgroundColor: Colors.grey[200],
                          child: Icon(
                            Icons.person,
                            size: 20,
                            color: Colors.grey[500],
                          ),
                        ),
                        title: Text(attendee['username'] ?? 'Unknown Attendee'),
                        onTap:
                            () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        ProfileScreen(userId: attendee['id']),
                              ),
                            ),
                      );
                    },
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
