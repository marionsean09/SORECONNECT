import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ViewAnnouncementsScreen extends StatelessWidget {
  const ViewAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('announcements')
            .orderBy('datePosted', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No announcements'),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data =
                  docs[index].data() as Map<String, dynamic>;

              final content =
                  (data['content'] ?? '').toString();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [

                      ListTile(
                        contentPadding: EdgeInsets.zero,

                        leading: Icon(
                          data['type'] == 'power_interruption'
                              ? Icons.power
                              : Icons.announcement,
                          color: const Color.fromARGB(
                            255,
                            214,
                            87,
                            2,
                          ),
                        ),

                        title: Text(
                          data['title'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        subtitle: Text(
                          content.length > 80
                              ? '${content.substring(0, 80)}...'
                              : content,
                        ),

                        isThreeLine: true,
                      ),

                      const SizedBox(height: 8),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: const Icon(
                            Icons.arrow_forward,
                          ),
                          label: const Text(
                            'View Details',
                          ),

                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    AnnouncementDetailsScreen(
                                  announcement: data,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class AnnouncementDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> announcement;

  const AnnouncementDetailsScreen({
    super.key,
    required this.announcement,
  });

  @override
  Widget build(BuildContext context) {
    final scheduledDate =
        announcement['scheduledDate'];

    String dateTimeText = 'Not specified';

    if (scheduledDate is Timestamp) {
      dateTimeText = DateFormat(
        'MMMM dd, yyyy • hh:mm a',
      ).format(scheduledDate.toDate());
    }

    String announcementType =
        (announcement['type'] ?? 'advisory')
            .toString()
            .replaceAll('_', ' ');

    announcementType =
        announcementType[0].toUpperCase() +
            announcementType.substring(1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcement Details'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            Icon(
              announcement['type'] ==
                      'power_interruption'
                  ? Icons.power
                  : Icons.announcement,
              size: 45,
              color: const Color.fromARGB(
                255,
                214,
                87,
                2,
              ),
            ),

            const SizedBox(height: 15),

            Text(
              announcement['title'] ?? '',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Chip(
              label: Text(announcementType),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: Colors.grey,
                ),

                const SizedBox(width: 8),

                Text(
                  dateTimeText,
                  style: const TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),

            const Divider(
              height: 35,
            ),

            const Text(
              'Announcement',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              announcement['content'] ?? '',
              style: const TextStyle(
                fontSize: 16,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}