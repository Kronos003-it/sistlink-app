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
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  bool _isAttending = false;
  bool _isLoadingRsvp = false;
  List<String> _attendeesUids = [];
  Map<String, dynamic>? _eventDataForEdit;

  Future<void> _toggleRsvp(Map<String, dynamic> eventData) async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to RSVP.')),
      );
      return;
    }
    setState(() => _isLoadingRsvp = true);
    final eventRef = FirebaseFirestore.instance
        .collection('events')
        .doc(widget.eventId);
    bool currentAttendance =
        (eventData['attendees'] as List<dynamic>?)?.contains(_currentUserId) ??
        false;
    try {
      if (currentAttendance) {
        await eventRef.update({
          'attendees': FieldValue.arrayRemove([_currentUserId]),
        });
      } else {
        await eventRef.update({
          'attendees': FieldValue.arrayUnion([_currentUserId]),
        });
      }
      if (mounted) {
        setState(() {
          _isAttending = !currentAttendance;
          if (_isAttending)
            _attendeesUids.add(_currentUserId!);
          else
            _attendeesUids.remove(_currentUserId);
          _isLoadingRsvp = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to update RSVP.')));
        setState(() => _isLoadingRsvp = false);
      }
    }
  }

  Future<void> _deleteEvent() async {
    if (_currentUserId == null ||
        _eventDataForEdit?['creatorId'] != _currentUserId)
      return;
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder:
          (BuildContext dialogContext) => AlertDialog(
            title: const Text('Delete Event'),
            content: const Text(
              'Are you sure you want to delete this event? This action cannot be undone.',
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
              TextButton(
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
            ],
          ),
    );
    if (confirmDelete == true) {
      try {
        await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event deleted successfully.')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete event.')),
          );
      }
    }
  }

  String _formatEventTimestamp(
    Timestamp timestamp, {
    bool justDate = false,
    bool justTime = false,
  }) {
    final dateTime = timestamp.toDate();
    if (justDate)
      return DateFormat.yMMMMd().format(dateTime); // e.g., October 29, 2021
    if (justTime) return DateFormat.jm().format(dateTime); // e.g., 10:00 AM
    return DateFormat('EEE, MMM d, yyyy \'at\' h:mm a').format(dateTime);
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 16, color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendeeList(List<String> attendeeUids) {
    if (attendeeUids.isEmpty)
      return const Text(
        'No attendees yet.',
        style: TextStyle(fontStyle: FontStyle.italic),
      );
    const maxDisplayedAttendees = 5; // Show a few, then "and X more"
    final displayUids = attendeeUids.take(maxDisplayedAttendees).toList();
    final remainingCount = attendeeUids.length - displayUids.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...displayUids.map(
          (uid) => FutureBuilder<DocumentSnapshot>(
            future:
                FirebaseFirestore.instance.collection('users').doc(uid).get(),
            builder: (context, AsyncSnapshot<DocumentSnapshot> userSnapshot) {
              if (!userSnapshot.hasData || !userSnapshot.data!.exists)
                return const SizedBox.shrink();
              final username =
                  (userSnapshot.data!.data()
                      as Map<String, dynamic>)['username'] ??
                  'User';
              return InkWell(
                onTap:
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(userId: uid),
                      ),
                    ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3.0),
                  child: Text(
                    username,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 15,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (remainingCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              "...and $remainingCount more.",
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Colors.blueAccent[700]!;

    return Scaffold(
      body: FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance
                .collection('events')
                .doc(widget.eventId)
                .get(),
        builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError ||
              !snapshot.hasData ||
              !snapshot.data!.exists) {
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: const Center(
                child: Text('Event not found or error loading.'),
              ),
            );
          }

          final eventData = snapshot.data!.data() as Map<String, dynamic>;
          _eventDataForEdit = eventData;

          final List<dynamic> fetchedAttendees = eventData['attendees'] ?? [];
          _attendeesUids = List<String>.from(fetchedAttendees);
          _isAttending =
              _currentUserId != null && _attendeesUids.contains(_currentUserId);

          final String eventName = eventData['eventName'] ?? 'Unnamed Event';
          final String description =
              eventData['description'] ?? 'No description provided.';
          final String location = eventData['location'] ?? 'Not specified.';
          final Timestamp eventTimestamp =
              eventData['eventDate'] ?? Timestamp.now();
          final String creatorUsername =
              eventData['creatorUsername'] ?? 'Unknown';
          final String? creatorId = eventData['creatorId'] as String?;

          return CustomScrollView(
            slivers: <Widget>[
              SliverAppBar(
                expandedHeight: 200.0,
                pinned: true,
                backgroundColor: primaryColor,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    eventName,
                    style: const TextStyle(
                      fontSize: 18,
                      shadows: [Shadow(blurRadius: 2, color: Colors.black38)],
                    ),
                  ),
                  background: Container(
                    // Placeholder for Event Image
                    color: Colors.grey[300],
                    child: Icon(Icons.event, size: 80, color: Colors.grey[400]),
                  ),
                ),
                actions: [
                  if (_currentUserId != null &&
                      _currentUserId == creatorId) ...[
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Edit Event',
                      onPressed:
                          () => Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder:
                                      (context) => CreateEventScreen(
                                        eventId: widget.eventId,
                                        initialEventData: _eventDataForEdit,
                                      ),
                                ),
                              )
                              .then((_) => mounted ? setState(() {}) : null),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete Event',
                      onPressed: _deleteEvent,
                    ),
                  ],
                ],
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Details",
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          Icons.person_outline,
                          'Hosted by: $creatorUsername',
                        ),
                        _buildInfoRow(Icons.location_on_outlined, location),
                        _buildInfoRow(
                          Icons.calendar_today_outlined,
                          _formatEventTimestamp(eventTimestamp, justDate: true),
                        ),
                        _buildInfoRow(
                          Icons.access_time_outlined,
                          _formatEventTimestamp(eventTimestamp, justTime: true),
                        ),

                        // Mockup has contact phone - we don't store this for events
                        const SizedBox(height: 24),
                        Text(
                          'About this event',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[800],
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'Attendees (${_attendeesUids.length})',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _buildAttendeeList(_attendeesUids),
                        const SizedBox(height: 32),

                        if (_currentUserId != null)
                          SizedBox(
                            width: double.infinity,
                            child:
                                _isLoadingRsvp
                                    ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                    : ElevatedButton(
                                      onPressed: () => _toggleRsvp(eventData),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            _isAttending
                                                ? Colors.grey[600]
                                                : primaryColor,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      child: Text(
                                        _isAttending
                                            ? 'Cancel RSVP'
                                            : 'RSVP / Attend',
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                          ),
                      ],
                    ),
                  ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}
