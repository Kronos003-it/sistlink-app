import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // For date formatting

class CreateEventScreen extends StatefulWidget {
  final String? eventId; // Optional: for editing
  final Map<String, dynamic>? initialEventData; // Optional: for editing

  const CreateEventScreen({super.key, this.eventId, this.initialEventData});

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

  bool _isLoading = false;
  bool _isEditMode = false;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final String? _currentUsername =
      FirebaseAuth.instance.currentUser?.displayName;

  @override
  void initState() {
    super.initState();
    if (widget.eventId != null && widget.initialEventData != null) {
      _isEditMode = true;
      _eventNameController.text = widget.initialEventData!['eventName'] ?? '';
      _descriptionController.text =
          widget.initialEventData!['description'] ?? '';
      _locationController.text = widget.initialEventData!['location'] ?? '';

      final Timestamp? eventTimestamp =
          widget.initialEventData!['eventDate'] as Timestamp?;
      if (eventTimestamp != null) {
        final eventDateTime = eventTimestamp.toDate();
        _selectedDate = eventDateTime;
        _selectedTime = TimeOfDay.fromDateTime(eventDateTime);
      }
    }
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate:
          _isEditMode
              ? DateTime(DateTime.now().year - 1)
              : DateTime.now(), // Allow past dates if editing
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (pickedTime != null && pickedTime != _selectedTime) {
      setState(() {
        _selectedTime = pickedTime;
      });
    }
  }

  Future<void> _submitEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an event date.')),
      );
      return;
    }
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an event time.')),
      );
      return;
    }
    if (_currentUserId == null ||
        (_isEditMode == false && _currentUsername == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: User not logged in properly.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final DateTime eventDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    final Timestamp eventTimestamp = Timestamp.fromDate(eventDateTime);

    final eventData = {
      'eventName': _eventNameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'location': _locationController.text.trim(),
      'eventDate': eventTimestamp,
    };

    try {
      if (_isEditMode) {
        // Update existing event
        await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId!)
            .update(eventData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event updated successfully!')),
          );
          Navigator.of(context).pop(); // Pop back to detail screen
        }
      } else {
        // Create new event
        final fullEventData = {
          ...eventData,
          'creatorId': _currentUserId,
          'creatorUsername': _currentUsername,
          'attendees': [_currentUserId], // Creator automatically attends
          'createdAt': FieldValue.serverTimestamp(),
        };
        await FirebaseFirestore.instance
            .collection('events')
            .add(fullEventData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event created successfully!')),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      print("Error submitting event: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to ${_isEditMode ? "update" : "create"} event.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Event' : 'Create New Event'),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TextFormField(
                        controller: _eventNameController,
                        decoration: const InputDecoration(
                          labelText: 'Event Name',
                        ),
                        validator:
                            (value) =>
                                (value == null || value.isEmpty)
                                    ? 'Please enter the event name'
                                    : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                        maxLines: 3,
                        validator:
                            (value) =>
                                (value == null || value.isEmpty)
                                    ? 'Please enter a description'
                                    : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                        ),
                        validator:
                            (value) =>
                                (value == null || value.isEmpty)
                                    ? 'Please enter the location'
                                    : null,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedDate == null
                                  ? 'No date chosen'
                                  : 'Date: ${DateFormat.yMd().format(_selectedDate!)}',
                            ),
                          ),
                          TextButton(
                            onPressed: () => _pickDate(context),
                            child: const Text('Choose Date'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedTime == null
                                  ? 'No time chosen'
                                  : 'Time: ${_selectedTime!.format(context)}',
                            ),
                          ),
                          TextButton(
                            onPressed: () => _pickTime(context),
                            child: const Text('Choose Time'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _submitEvent,
                        child: Text(
                          _isEditMode ? 'Update Event' : 'Create Event',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
