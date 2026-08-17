import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostAnnouncementScreen extends StatefulWidget {
  const PostAnnouncementScreen({super.key});

  @override
  State<PostAnnouncementScreen> createState() => _PostAnnouncementScreenState();
}

class _PostAnnouncementScreenState extends State<PostAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedType = 'advisory';
  bool _isPosting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Announcement'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField(
                initialValue: _selectedType,
                items: const [
                  DropdownMenuItem(value: 'power_interruption', child: Text('Power Interruption')),
                  DropdownMenuItem(value: 'advisory', child: Text('Advisory')),
                  DropdownMenuItem(value: 'news', child: Text('News')),
                  DropdownMenuItem(value: 'payment_reminder', child: Text('Payment Reminder')),
                ],
                onChanged: (value) => setState(() => _selectedType = value!),
                decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                validator: (v) => v?.isEmpty == true ? 'Enter title' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Content', border: OutlineInputBorder()),
                validator: (v) => v?.isEmpty == true ? 'Enter content' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isPosting ? null : () async {
                  if (!_formKey.currentState!.validate()) return;
                  setState(() => _isPosting = true);
                  await FirebaseFirestore.instance.collection('announcements').add({
                    'title': _titleController.text,
                    'content': _contentController.text,
                    'type': _selectedType,
                    'postedBy': FirebaseAuth.instance.currentUser?.uid,
                    'datePosted': FieldValue.serverTimestamp(),
                  });
                  _titleController.clear();
                  _contentController.clear();
                  setState(() => _isPosting = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Posted!')),
                  );
                },
                child: _isPosting ? const Text('POSTING...') : const Text('POST'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}