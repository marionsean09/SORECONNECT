import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class PostAnnouncementScreen extends StatefulWidget {
  const PostAnnouncementScreen({super.key});

  @override
  State<PostAnnouncementScreen> createState() =>
      _PostAnnouncementScreenState();
}

class _PostAnnouncementScreenState extends State<PostAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  String _selectedType = 'advisory';
  bool _isPosting = false;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  Future<void> _selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (pickedTime != null) {
      setState(() {
        _selectedTime = pickedTime;
      });
    }
  }

  Future<void> _postAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isPosting = true;
    });

    try {
      final scheduledDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      await FirebaseFirestore.instance
          .collection('announcements')
          .add({
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'type': _selectedType,

        'postedBy': FirebaseAuth.instance.currentUser?.uid,

        // Actual time when the announcement was posted
        'datePosted': FieldValue.serverTimestamp(),

        // Selected date and time
        'scheduledDate': Timestamp.fromDate(scheduledDateTime),
      });

      _titleController.clear();
      _contentController.clear();

      setState(() {
        _selectedType = 'advisory';
        _selectedDate = DateTime.now();
        _selectedTime = TimeOfDay.now();
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Announcement posted successfully!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Announcement'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Form(
          key: _formKey,

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              // ANNOUNCEMENT TYPE
              DropdownButtonFormField<String>(
                value: _selectedType,

                items: const [
                  DropdownMenuItem(
                    value: 'power_interruption',
                    child: Text('Power Interruption'),
                  ),

                  DropdownMenuItem(
                    value: 'advisory',
                    child: Text('Advisory'),
                  ),

                  DropdownMenuItem(
                    value: 'news',
                    child: Text('News'),
                  ),

                  DropdownMenuItem(
                    value: 'payment_reminder',
                    child: Text('Payment Reminder'),
                  ),
                ],

                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedType = value;
                    });
                  }
                },

                decoration: const InputDecoration(
                  labelText: 'Announcement Type',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              // TITLE
              TextFormField(
                controller: _titleController,

                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),

                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter announcement title';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // CONTENT
              TextFormField(
                controller: _contentController,
                maxLines: 5,

                decoration: const InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),

                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter announcement content';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 20),

              const Text(
                'Schedule Announcement',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 10),

              // DATE
              InkWell(
                onTap: _selectDate,

                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),

                  child: Text(
                    DateFormat(
                      'MMMM dd, yyyy',
                    ).format(_selectedDate),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // TIME
              InkWell(
                onTap: _selectTime,

                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Time',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.access_time),
                  ),

                  child: Text(
                    _selectedTime.format(context),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // POST BUTTON
              SizedBox(
                width: double.infinity,
                height: 50,

                child: ElevatedButton(
                  onPressed:
                      _isPosting ? null : _postAnnouncement,

                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),

                  child: _isPosting
                      ? const SizedBox(
                          height: 22,
                          width: 22,

                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'POST ANNOUNCEMENT',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}