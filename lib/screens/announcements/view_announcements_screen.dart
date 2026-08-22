import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ViewAnnouncementsScreen extends StatefulWidget {
  const ViewAnnouncementsScreen({super.key});

  @override
  State<ViewAnnouncementsScreen> createState() =>
      _ViewAnnouncementsScreenState();
}

class _ViewAnnouncementsScreenState
    extends State<ViewAnnouncementsScreen> {

  // ============================================================
  // SORT OPTION
  // ============================================================

  String _sortOption = 'Newest';

  // ============================================================
  // GET DATE
  // ============================================================

  DateTime? _getDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  // ============================================================
  // GET ANNOUNCEMENT DATE
  // ============================================================

  DateTime _getAnnouncementDate(
    Map<String, dynamic> data,
  ) {
    final date =
        _getDate(data['datePosted']) ??
        _getDate(data['createdAt']) ??
        _getDate(data['timestamp']) ??
        _getDate(data['dateCreated']);

    return date ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  // ============================================================
  // SORT ANNOUNCEMENTS
  // ============================================================

  List<QueryDocumentSnapshot> _sortAnnouncements(
    List<QueryDocumentSnapshot> docs,
  ) {
    final sortedDocs =
        List<QueryDocumentSnapshot>.from(docs);

    sortedDocs.sort((a, b) {
      final dataA =
          a.data() as Map<String, dynamic>;

      final dataB =
          b.data() as Map<String, dynamic>;

      final dateA =
          _getAnnouncementDate(dataA);

      final dateB =
          _getAnnouncementDate(dataB);

      if (_sortOption == 'Newest') {
        return dateB.compareTo(dateA);
      } else {
        return dateA.compareTo(dateB);
      }
    });

    return sortedDocs;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Announcements',
        ),
        backgroundColor:
            Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),

      body: Column(
        children: [

          // ====================================================
          // MINIMAL SORT DROPDOWN
          // ====================================================

          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              8,
            ),

            child: Row(
              children: [

                // ==============================================
                // TITLE
                // ==============================================

                const Expanded(
                  child: Text(
                    'All Announcements',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                // ==============================================
                // SORT DROPDOWN
                // ==============================================

                Container(
                  height: 48,

                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 10,
                  ),

                  decoration:
                      BoxDecoration(
                    color:
                        Colors.grey.shade100,

                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),

                    border: Border.all(
                      color:
                          Colors.grey.shade300,
                    ),
                  ),

                  child:
                      DropdownButtonHideUnderline(
                    child:
                        DropdownButton<String>(
                      value:
                          _sortOption,

                      icon:
                          const Icon(
                        Icons
                            .keyboard_arrow_down,
                        size: 20,
                        color:
                            Colors.grey,
                      ),

                      style:
                          const TextStyle(
                        color:
                            Colors.black87,
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w500,
                      ),

                      items: const [

                        // ========================================
                        // NEWEST
                        // ========================================

                        DropdownMenuItem(
                          value: 'Newest',

                          child: Row(
                            mainAxisSize:
                                MainAxisSize.min,

                            children: [
                              Icon(
                                Icons.sort,
                                size: 18,
                                color:
                                    Colors.orange,
                              ),

                              SizedBox(
                                width: 7,
                              ),

                              Text(
                                'Newest',
                              ),
                            ],
                          ),
                        ),

                        // ========================================
                        // OLDEST
                        // ========================================

                        DropdownMenuItem(
                          value: 'Oldest',

                          child: Row(
                            mainAxisSize:
                                MainAxisSize.min,

                            children: [
                              Icon(
                                Icons.sort,
                                size: 18,
                                color:
                                    Colors.orange,
                              ),

                              SizedBox(
                                width: 7,
                              ),

                              Text(
                                'Oldest',
                              ),
                            ],
                          ),
                        ),
                      ],

                      onChanged:
                          (value) {
                        if (value !=
                            null) {
                          setState(() {
                            _sortOption =
                                value;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ====================================================
          // ANNOUNCEMENTS LIST
          // ====================================================

          Expanded(
            child:
                StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore
                      .instance
                      .collection(
                    'announcements',
                  )
                      .snapshots(),

              builder:
                  (context, snapshot) {

                // ==============================================
                // LOADING
                // ==============================================

                if (snapshot
                        .connectionState ==
                    ConnectionState
                        .waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                // ==============================================
                // ERROR
                // ==============================================

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                    ),
                  );
                }

                // ==============================================
                // EMPTY
                // ==============================================

                if (!snapshot.hasData ||
                    snapshot.data!.docs
                        .isEmpty) {
                  return const Center(
                    child: Text(
                      'No announcements',
                    ),
                  );
                }

                // ==============================================
                // SORT ANNOUNCEMENTS
                // ==============================================

                final docs =
                    _sortAnnouncements(
                  snapshot.data!.docs,
                );

                // ==============================================
                // LIST
                // ==============================================

                return ListView.builder(
                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    16,
                  ),

                  itemCount:
                      docs.length,

                  itemBuilder:
                      (context, index) {

                    final data =
                        docs[index]
                            .data()
                            as Map<String,
                                dynamic>;

                    final content =
                        (data['content'] ??
                                '')
                            .toString();

                    return Card(
                      margin:
                          const EdgeInsets.only(
                        bottom: 12,
                      ),

                      child: Padding(
                        padding:
                            const EdgeInsets.all(
                          12,
                        ),

                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,

                          children: [

                            // ==================================
                            // ANNOUNCEMENT HEADER
                            // ==================================

                            ListTile(
                              contentPadding:
                                  EdgeInsets.zero,

                              leading:
                                  Icon(
                                data['type'] ==
                                        'power_interruption'
                                    ? Icons.power
                                    : Icons
                                        .announcement,

                                color:
                                    const Color
                                        .fromARGB(
                                  255,
                                  214,
                                  87,
                                  2,
                                ),
                              ),

                              title:
                                  Text(
                                data['title'] ??
                                    '',

                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),

                              subtitle:
                                  Text(
                                content.length >
                                        80
                                    ? '${content.substring(0, 80)}...'
                                    : content,
                              ),

                              isThreeLine:
                                  true,
                            ),

                            const SizedBox(
                              height: 8,
                            ),

                            // ==================================
                            // VIEW DETAILS
                            // ==================================

                            Align(
                              alignment:
                                  Alignment
                                      .centerRight,

                              child:
                                  TextButton
                                      .icon(
                                icon:
                                    const Icon(
                                  Icons
                                      .arrow_forward,
                                ),

                                label:
                                    const Text(
                                  'View Details',
                                ),

                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) =>
                                              AnnouncementDetailsScreen(
                                        announcement:
                                            data,
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
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ANNOUNCEMENT DETAILS SCREEN
// ============================================================

class AnnouncementDetailsScreen
    extends StatelessWidget {

  final Map<String, dynamic> announcement;

  const AnnouncementDetailsScreen({
    super.key,
    required this.announcement,
  });

  @override
  Widget build(BuildContext context) {

    final scheduledDate =
        announcement['scheduledDate'];

    String dateTimeText =
        'Not specified';

    if (scheduledDate is Timestamp) {
      dateTimeText = DateFormat(
        'MMMM dd, yyyy • hh:mm a',
      ).format(
        scheduledDate.toDate(),
      );
    }

    String announcementType =
        (announcement['type'] ??
                'advisory')
            .toString()
            .replaceAll(
              '_',
              ' ',
            );

    if (announcementType.isNotEmpty) {
      announcementType =
          announcementType[0]
                  .toUpperCase() +
              announcementType
                  .substring(1);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Announcement Details',
        ),
        backgroundColor:
            Theme.of(context)
                .primaryColor,
        foregroundColor:
            Colors.white,
      ),

      body:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            // ==============================================
            // ICON
            // ==============================================

            Icon(
              announcement['type'] ==
                      'power_interruption'
                  ? Icons.power
                  : Icons.announcement,

              size: 45,

              color:
                  const Color.fromARGB(
                255,
                214,
                87,
                2,
              ),
            ),

            const SizedBox(
              height: 15,
            ),

            // ==============================================
            // TITLE
            // ==============================================

            Text(
              announcement['title'] ??
                  '',

              style:
                  const TextStyle(
                fontSize: 24,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            // ==============================================
            // TYPE
            // ==============================================

            Chip(
              label:
                  Text(
                announcementType,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            // ==============================================
            // DATE
            // ==============================================

            Row(
              children: [

                const Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: Colors.grey,
                ),

                const SizedBox(
                  width: 8,
                ),

                Text(
                  dateTimeText,

                  style:
                      const TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),

            const Divider(
              height: 35,
            ),

            // ==============================================
            // ANNOUNCEMENT
            // ==============================================

            const Text(
              'Announcement',

              style:
                  TextStyle(
                fontSize: 17,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            Text(
              announcement['content'] ??
                  '',

              style:
                  const TextStyle(
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