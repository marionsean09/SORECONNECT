import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewAnnouncementsScreen extends StatelessWidget {
  const ViewAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('announcements')
            .orderBy('datePosted', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: Text('Loading...'));
          
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No announcements'));
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              return Card(
                child: ListTile(
                  leading: Icon(
                    data['type'] == 'power_interruption' ? Icons.power : Icons.announcement,
                    color: const Color.fromARGB(255, 214, 87, 2),
                  ),
                  title: Text(data['title'] ?? ''),
                  subtitle: Text(data['content'] ?? ''),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}