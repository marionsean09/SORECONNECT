import 'package:cloud_firestore/cloud_firestore.dart';

class AnnouncementService {

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Future<void> postAnnouncement({
    required String title,
    required String content,
  }) async {

    await _firestore
        .collection('announcements')
        .add({

      'title': title,
      'content': content,
      'created_at': Timestamp.now(),
    });
  }
}