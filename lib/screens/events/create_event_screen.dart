import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CreateEventScreen extends StatefulWidget {
  final Map<String, dynamic>? initialEventData; // For editing existing event
  final String? eventId; // For editing existing event

  const CreateEventScreen({super.key, this.initialEventData, this.eventId});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _eventNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isPrivateEvent = false; // New state for privacy

  bool _isLoading = false;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  String? _currentUsername;

  bool get _isEditing =>
      widget.initialEventData != null && widget.eventId != null;

  @override
  void initState() {
    super.initState();
    _fetchUsername();
    if (_isEditing) {
      _eventNameController.text = widget.initialEventData!['eventName'] ?? '';
      _descriptionController.text =
          widget.initialEventData!['description'] ?? '';
      _locationController.text = widget.initialEventData!['location'] ?? '';
      if (widget.initialEventData!['eventDate'] != null) {
        final Timestamp eventTimestamp =
            widget.initialEventData!['eventDate'] as Timestamp;
        _selectedDate = eventTimestamp.toDate();
        _selectedTime = TimeOfDay.fromDateTime(_selectedDate!);
      }
      _isPrivateEvent = widget.initialEventData!['isPrivate'] ?? false;
    }
  }

  Future<void> _fetchUsername() async {
    if (_currentUserId != null) {
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUserId)
              .get();
      if (mounted && userDoc.exists) {
        setState(() {
          _currentUsername =
              (userDoc.data() as Map<String, dynamic>)['username'];
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date and time for the event.'),
        ),
      );
      return;
    }
    if (_currentUserId == null || _currentUsername == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not verify user. Please try again.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final DateTime finalDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    final Timestamp eventTimestamp = Timestamp.fromDate(finalDateTime);

    Map<String, dynamic> eventData = {
      'eventName': _eventNameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'location': _locationController.text.trim(),
      'eventDate': eventTimestamp,
      'creatorId': _currentUserId,
      'creatorUsername': _currentUsername,
      'attendees':
          _isEditing
              ? (widget.initialEventData?['attendees'] ?? [])
              : [], // Preserve attendees on edit
      'isPrivate': _isPrivateEvent,
      'allowedUserIds':
          _isPrivateEvent
              ? [_currentUserId]
              : [], // Initially, only creator for private events
      'createdAt':
          _isEditing
              ? widget.initialEventData!['createdAt']
              : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // If editing, ensure creatorId and createdAt are not overwritten by mistake from new data
    if (_isEditing) {
      eventData['creatorId'] =
          widget.initialEventData!['creatorId'] ?? _currentUserId;
      eventData['creatorUsername'] =
          widget.initialEventData!['creatorUsername'] ?? _currentUsername;
      // If changing from public to private, set allowedUserIds to creator
      // If changing from private to public, clear allowedUserIds (or handle as needed)
      if (_isPrivateEvent &&
          (widget.initialEventData!['isPrivate'] == false ||
              widget.initialEventData!['allowedUserIds'] == null)) {
        eventData['allowedUserIds'] = [_currentUserId];
      } else if (!_isPrivateEvent) {
        eventData['allowedUserIds'] = [];
      } else {
        eventData['allowedUserIds'] = List<String>.from(
          widget.initialEventData!['allowedUserIds'] ?? [_currentUserId],
        );
        // Ensure creator is always in allowedUserIds for their private event if editing
        if (!_isPrivateEvent &&
            !eventData['allowedUserIds'].contains(_currentUserId)) {
          eventData['allowedUserIds'].add(_currentUserId);
        }
      }
    }

    try {
      if (_isEditing) {
        await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId!)
            .update(eventData);
      } else {
        await FirebaseFirestore.instance.collection('events').add(eventData);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Event ${_isEditing ? "updated" : "created"} successfully!',
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      print("Error saving event: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to save event.')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildLabeledTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    int maxLines = 1,
    bool isRequired = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText ?? 'Enter $label',
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14.0,
              horizontal: 12.0,
            ),
          ),
          validator:
              isRequired
                  ? (value) =>
                      (value == null || value.isEmpty)
                          ? 'Please enter the $label'
                          : null
                  : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Colors.blueAccent[700]!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Event' : 'Create New Event',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _buildLabeledTextField(
                        controller: _eventNameController,
                        label: 'Event Name',
                      ),
                      const SizedBox(height: 16),
                      _buildLabeledTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),
                      _buildLabeledTextField(
                        controller: _locationController,
                        label: 'Location (Optional)',
                        isRequired: false,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(context),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Event Date',
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 14.0,
                                    horizontal: 12.0,
                                  ),
                                ),
                                child: Text(
                                  _selectedDate == null
                                      ? 'Select Date'
                                      : DateFormat.yMMMd().format(
                                        _selectedDate!,
                                      ),
                                  style: TextStyle(
                                    color:
                                        _selectedDate == null
                                            ? Colors.grey[600]
                                            : Colors.black87,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectTime(context),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Event Time',
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 14.0,
                                    horizontal: 12.0,
                                  ),
                                ),
                                child: Text(
                                  _selectedTime == null
                                      ? 'Select Time'
                                      : _selectedTime!.format(context),
                                  style: TextStyle(
                                    color:
                                        _selectedTime == null
                                            ? Colors.grey[600]
                                            : Colors.black87,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SwitchListTile(
                        title: const Text(
                          'Private Event',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          _isPrivateEvent
                              ? 'Only invited users can see this event.'
                              : 'Visible to everyone.',
                        ),
                        value: _isPrivateEvent,
                        onChanged: (bool value) {
                          setState(() {
                            _isPrivateEvent = value;
                          });
                        },
                        activeColor: primaryColor,
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: _saveEvent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: Text(
                          _isEditing ? 'Save Changes' : 'Create Event',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
