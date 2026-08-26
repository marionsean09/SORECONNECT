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
        _getDate(data['scheduledDate']) ??
        _getDate(data['readingDate']) ??
        _getDate(data['disconnectionDate']) ??
        _getDate(data['createdAt']) ??
        _getDate(data['timestamp']) ??
        _getDate(data['dateCreated']);

    return date ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  // ============================================================
  // GET TYPE LABEL
  // ============================================================

  String _getTypeLabel(
    Map<String, dynamic> data,
  ) {
    final savedLabel = data['typeLabel'];

    if (savedLabel != null &&
        savedLabel.toString().trim().isNotEmpty) {
      return savedLabel.toString();
    }

    final type =
        (data['type'] ?? 'advisory').toString();

    switch (type) {
      case 'power_interruption':
        return 'Power Interruption';

      case 'disconnection':
        return 'Disconnection Notice';

      case 'meter_reading':
        return 'Meter Reading Schedule';

      case 'payment_reminder':
        return 'Payment Reminder';

      case 'advisory':
        return 'Advisory';

      case 'news':
        return 'News';

      case 'general':
        return 'General Announcement';

      default:
        return _formatType(type);
    }
  }

  // ============================================================
  // FORMAT TYPE
  // ============================================================

  String _formatType(String value) {
    if (value.trim().isEmpty) {
      return 'Announcement';
    }

    final formatted = value
        .replaceAll('_', ' ')
        .trim();

    return formatted[0].toUpperCase() +
        formatted.substring(1);
  }

  // ============================================================
  // GET TYPE ICON
  // ============================================================

  IconData _getTypeIcon(
    Map<String, dynamic> data,
  ) {
    switch (data['type']) {
      case 'power_interruption':
        return Icons.power_off;

      case 'disconnection':
        return Icons.power_settings_new;

      case 'meter_reading':
        return Icons.speed;

      case 'payment_reminder':
        return Icons.payment;

      case 'advisory':
        return Icons.info_outline;

      case 'news':
        return Icons.newspaper;

      case 'general':
        return Icons.campaign;

      default:
        return Icons.announcement;
    }
  }

  // ============================================================
  // GET TYPE COLOR
  // ============================================================

  Color _getTypeColor(
    Map<String, dynamic> data,
  ) {
    switch (data['type']) {
      case 'power_interruption':
        return Colors.orange;

      case 'disconnection':
        return Colors.red;

      case 'meter_reading':
        return Colors.blue;

      case 'payment_reminder':
        return Colors.green;

      case 'advisory':
        return Colors.indigo;

      case 'news':
        return Colors.purple;

      case 'general':
        return Colors.teal;

      default:
        return Theme.of(context).primaryColor;
    }
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
      }

      return dateA.compareTo(dateB);
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
        elevation: 0,
      ),

      body: Column(
        children: [
          // ======================================================
          // HEADER / SORT
          // ======================================================

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
                      value: _sortOption,

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
                        DropdownMenuItem(
                          value: 'Newest',
                          child: Row(
                            mainAxisSize:
                                MainAxisSize.min,
                            children: [
                              Icon(
                                Icons
                                    .arrow_downward,
                                size: 17,
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
                        DropdownMenuItem(
                          value: 'Oldest',
                          child: Row(
                            mainAxisSize:
                                MainAxisSize.min,
                            children: [
                              Icon(
                                Icons
                                    .arrow_upward,
                                size: 17,
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
                        if (value != null) {
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

          // ======================================================
          // ANNOUNCEMENTS
          // ======================================================

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
                // ==================================================
                // LOADING
                // ==================================================

                if (snapshot
                        .connectionState ==
                    ConnectionState
                        .waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                // ==================================================
                // ERROR
                // ==================================================

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding:
                          const EdgeInsets
                              .all(20),
                      child: Text(
                        'Error loading announcements:\n${snapshot.error}',
                        textAlign:
                            TextAlign.center,
                      ),
                    ),
                  );
                }

                // ==================================================
                // EMPTY
                // ==================================================

                if (!snapshot.hasData ||
                    snapshot.data!.docs
                        .isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,
                      children: [
                        Icon(
                          Icons
                              .campaign_outlined,
                          size: 60,
                          color:
                              Colors.grey,
                        ),
                        SizedBox(
                          height: 12,
                        ),
                        Text(
                          'No announcements',
                          style: TextStyle(
                            color:
                                Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // ==================================================
                // SORT
                // ==================================================

                final docs =
                    _sortAnnouncements(
                  snapshot.data!.docs,
                );

                // ==================================================
                // LIST
                // ==================================================

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
                        docs[index].data()
                            as Map<String,
                                dynamic>;

                    final title =
                        (data['title'] ??
                                'Untitled Announcement')
                            .toString();

                    final content =
                        (data['content'] ??
                                '')
                            .toString();

                    final typeColor =
                        _getTypeColor(
                      data,
                    );

                    final typeLabel =
                        _getTypeLabel(
                      data,
                    );

                    final coveredArea =
                        (data['coveredArea'] ??
                                '')
                            .toString();

                    final date =
                        _getAnnouncementDate(
                      data,
                    );

                    final hasDate =
                        date.millisecondsSinceEpoch >
                            0;

                    return Card(
                      margin:
                          const EdgeInsets.only(
                        bottom: 12,
                      ),
                      elevation: 1,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),
                      child: InkWell(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                        onTap: () {
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
                        child: Padding(
                          padding:
                              const EdgeInsets
                                  .all(14),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              // ==================================
                              // HEADER
                              // ==================================

                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration:
                                        BoxDecoration(
                                      color:
                                          typeColor
                                              .withOpacity(
                                        0.10,
                                      ),
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        12,
                                      ),
                                    ),
                                    child:
                                        Icon(
                                      _getTypeIcon(
                                        data,
                                      ),
                                      color:
                                          typeColor,
                                      size: 25,
                                    ),
                                  ),

                                  const SizedBox(
                                    width: 12,
                                  ),

                                  Expanded(
                                    child:
                                        Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                      children: [
                                        Text(
                                          title,
                                          maxLines:
                                              2,
                                          overflow:
                                              TextOverflow
                                                  .ellipsis,
                                          style:
                                              const TextStyle(
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                            fontSize:
                                                16,
                                          ),
                                        ),

                                        const SizedBox(
                                          height: 5,
                                        ),

                                        Container(
                                          padding:
                                              const EdgeInsets
                                                  .symmetric(
                                            horizontal:
                                                9,
                                            vertical:
                                                4,
                                          ),
                                          decoration:
                                              BoxDecoration(
                                            color:
                                                typeColor
                                                    .withOpacity(
                                              0.10,
                                            ),
                                            borderRadius:
                                                BorderRadius
                                                    .circular(
                                              20,
                                            ),
                                          ),
                                          child:
                                              Text(
                                            typeLabel,
                                            style:
                                                TextStyle(
                                              color:
                                                  typeColor,
                                              fontSize:
                                                  11,
                                              fontWeight:
                                                  FontWeight
                                                      .bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(
                                height: 12,
                              ),

                              // ==================================
                              // CONTENT
                              // ==================================

                              Text(
                                content.length >
                                        100
                                    ? '${content.substring(0, 100)}...'
                                    : content,
                                maxLines: 3,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style:
                                    TextStyle(
                                  color: Colors
                                      .grey
                                      .shade700,
                                  height: 1.4,
                                  fontSize: 14,
                                ),
                              ),

                              const SizedBox(
                                height: 12,
                              ),

                              // ==================================
                              // COVERED AREA
                              // ==================================

                              if (coveredArea
                                  .isNotEmpty)
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Icon(
                                      Icons
                                          .location_on_outlined,
                                      size: 17,
                                      color:
                                          typeColor,
                                    ),
                                    const SizedBox(
                                      width: 6,
                                    ),
                                    Expanded(
                                      child:
                                          Text(
                                        coveredArea,
                                        maxLines:
                                            2,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                        style:
                                            TextStyle(
                                          color:
                                              Colors
                                                  .grey
                                                  .shade700,
                                          fontSize:
                                              12,
                                          fontWeight:
                                              FontWeight
                                                  .w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                              if (coveredArea
                                  .isNotEmpty)
                                const SizedBox(
                                  height: 8,
                                ),

                              // ==================================
                              // DATE
                              // ==================================

                              if (hasDate)
                                Row(
                                  children: [
                                    const Icon(
                                      Icons
                                          .schedule,
                                      size: 16,
                                      color:
                                          Colors
                                              .grey,
                                    ),
                                    const SizedBox(
                                      width: 6,
                                    ),
                                    Text(
                                      DateFormat(
                                        'MMM dd, yyyy • hh:mm a',
                                      ).format(
                                        date,
                                      ),
                                      style:
                                          TextStyle(
                                        color: Colors
                                            .grey
                                            .shade600,
                                        fontSize:
                                            12,
                                      ),
                                    ),
                                  ],
                                ),

                              const SizedBox(
                                height: 10,
                              ),

                              const Divider(
                                height: 1,
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
                                  onPressed:
                                      () {
                                    Navigator
                                        .push(
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
                                  icon:
                                      const Icon(
                                    Icons
                                        .arrow_forward,
                                    size: 18,
                                  ),
                                  label:
                                      const Text(
                                    'View Details',
                                  ),
                                ),
                              ),
                            ],
                          ),
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

// ==================================================================
// ANNOUNCEMENT DETAILS SCREEN
// ==================================================================

class AnnouncementDetailsScreen
    extends StatelessWidget {
  final Map<String, dynamic> announcement;

  const AnnouncementDetailsScreen({
    super.key,
    required this.announcement,
  });

  // ================================================================
  // GET DATE
  // ================================================================

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

  // ================================================================
  // TYPE LABEL
  // ================================================================

  String _getTypeLabel() {
    final savedLabel =
        announcement['typeLabel'];

    if (savedLabel != null &&
        savedLabel.toString().trim().isNotEmpty) {
      return savedLabel.toString();
    }

    final type =
        (announcement['type'] ??
                'advisory')
            .toString();

    switch (type) {
      case 'power_interruption':
        return 'Power Interruption';

      case 'disconnection':
        return 'Disconnection Notice';

      case 'meter_reading':
        return 'Meter Reading Schedule';

      case 'payment_reminder':
        return 'Payment Reminder';

      case 'advisory':
        return 'Advisory';

      case 'news':
        return 'News';

      case 'general':
        return 'General Announcement';

      default:
        return type
            .replaceAll('_', ' ')
            .split(' ')
            .map(
              (word) => word.isEmpty
                  ? word
                  : word[0].toUpperCase() +
                      word.substring(1),
            )
            .join(' ');
    }
  }

  // ================================================================
  // TYPE ICON
  // ================================================================

  IconData _getTypeIcon() {
    switch (announcement['type']) {
      case 'power_interruption':
        return Icons.power_off;

      case 'disconnection':
        return Icons.power_settings_new;

      case 'meter_reading':
        return Icons.speed;

      case 'payment_reminder':
        return Icons.payment;

      case 'advisory':
        return Icons.info_outline;

      case 'news':
        return Icons.newspaper;

      case 'general':
        return Icons.campaign;

      default:
        return Icons.announcement;
    }
  }

  // ================================================================
  // TYPE COLOR
  // ================================================================

  Color _getTypeColor() {
    switch (announcement['type']) {
      case 'power_interruption':
        return Colors.orange;

      case 'disconnection':
        return Colors.red;

      case 'meter_reading':
        return Colors.blue;

      case 'payment_reminder':
        return Colors.green;

      case 'advisory':
        return Colors.indigo;

      case 'news':
        return Colors.purple;

      case 'general':
        return Colors.teal;

      default:
        return Colors.orange;
    }
  }

  // ================================================================
  // DETAIL ITEM
  // ================================================================

  Widget _buildDetailItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    if (value.trim().isEmpty ||
        value.trim().toLowerCase() == 'null') {
      return const SizedBox.shrink();
    }

    final itemColor =
        color ?? Theme.of(context).primaryColor;

    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(bottom: 10),
      padding:
          const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(
              color:
                  itemColor.withOpacity(
                0.10,
              ),
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color: itemColor,
            ),
          ),
          const SizedBox(
            width: 11,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors
                        .grey
                        .shade600,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  value,
                  style:
                      const TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // COVERAGE DETAILS
  // ================================================================

  Widget _buildCoverageDetails(
    BuildContext context,
  ) {
    final coverageType =
        (announcement['coverageType'] ??
                '')
            .toString();

    final municipality =
        (announcement['municipality'] ??
                '')
            .toString();

    final barangay =
        (announcement['barangay'] ??
                '')
            .toString();

    final coveredArea =
        (announcement['coveredArea'] ??
                '')
            .toString();

    String coverageLabel;

    switch (coverageType) {
      case 'all':
        coverageLabel =
            'All Areas';
        break;

      case 'municipality':
        coverageLabel =
            'Municipality';
        break;

      case 'barangay':
        coverageLabel =
            'Barangay';
        break;

      default:
        coverageLabel =
            'Covered Area';
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Covered Area',
          style: TextStyle(
            fontSize: 17,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        _buildDetailItem(
          context: context,
          icon: Icons.public,
          label: 'Coverage',
          value: coverageLabel,
        ),

        if (municipality.isNotEmpty)
          _buildDetailItem(
            context: context,
            icon: Icons.location_city,
            label: 'Municipality',
            value: municipality,
          ),

        if (barangay.isNotEmpty)
          _buildDetailItem(
            context: context,
            icon: Icons.home_work_outlined,
            label: 'Barangay',
            value: barangay,
          ),

        if (coveredArea.isNotEmpty)
          _buildDetailItem(
            context: context,
            icon: Icons.location_on,
            label: 'Affected Area',
            value: coveredArea,
          ),
      ],
    );
  }

  // ================================================================
  // POWER INTERRUPTION DETAILS
  // ================================================================

  Widget _buildPowerInterruptionDetails(
    BuildContext context,
  ) {
    final startDate =
        _getDate(
      announcement['scheduledDate'],
    );

    final endDate =
        _getDate(
      announcement['scheduledEndDate'],
    );

    final startTime =
        (announcement['startTime'] ??
                '')
            .toString();

    final endTime =
        (announcement['endTime'] ??
                '')
            .toString();

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Power Interruption Schedule',
          style: TextStyle(
            fontSize: 17,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        if (startDate != null)
          _buildDetailItem(
            context: context,
            icon: Icons
                .calendar_today,
            label: 'Starting Date',
            value: DateFormat(
              'MMMM dd, yyyy',
            ).format(startDate),
            color: Colors.orange,
          ),

        if (startTime.isNotEmpty)
          _buildDetailItem(
            context: context,
            icon: Icons.access_time,
            label: 'Starting Time',
            value: startTime,
            color: Colors.orange,
          ),

        if (endDate != null)
          _buildDetailItem(
            context: context,
            icon: Icons
                .event_available,
            label: 'Ending Date',
            value: DateFormat(
              'MMMM dd, yyyy',
            ).format(endDate),
            color: Colors.orange,
          ),

        if (endTime.isNotEmpty)
          _buildDetailItem(
            context: context,
            icon: Icons
                .access_time_filled,
            label: 'Ending Time',
            value: endTime,
            color: Colors.orange,
          ),
      ],
    );
  }

  // ================================================================
  // DISCONNECTION DETAILS
  // ================================================================

  Widget _buildDisconnectionDetails(
    BuildContext context,
  ) {
    final date =
        _getDate(
      announcement[
          'disconnectionDate'],
    );

    final time =
        (announcement[
                    'disconnectionTime'] ??
                '')
            .toString();

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Disconnection Schedule',
          style: TextStyle(
            fontSize: 17,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        if (date != null)
          _buildDetailItem(
            context: context,
            icon: Icons
                .calendar_month,
            label:
                'Disconnection Date',
            value: DateFormat(
              'MMMM dd, yyyy',
            ).format(date),
            color: Colors.red,
          ),

        if (time.isNotEmpty)
          _buildDetailItem(
            context: context,
            icon: Icons.access_time,
            label:
                'Disconnection Time',
            value: time,
            color: Colors.red,
          ),
      ],
    );
  }

  // ================================================================
  // METER READING DETAILS
  // ================================================================

  Widget _buildMeterReadingDetails(
    BuildContext context,
  ) {
    final readingDate =
        _getDate(
      announcement[
          'readingDate'],
    );

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Meter Reading Schedule',
          style: TextStyle(
            fontSize: 17,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        if (readingDate != null)
          _buildDetailItem(
            context: context,
            icon: Icons.speed,
            label: 'Reading Date',
            value: DateFormat(
              'MMMM dd, yyyy',
            ).format(
              readingDate,
            ),
            color: Colors.blue,
          ),
      ],
    );
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    final type =
        (announcement['type'] ??
                'advisory')
            .toString();

    final title =
        (announcement['title'] ??
                'Announcement')
            .toString();

    final content =
        (announcement['content'] ??
                '')
            .toString();

    final typeLabel =
        _getTypeLabel();

    final typeColor =
        _getTypeColor();

    final postedDate =
        _getDate(
      announcement['datePosted'],
    );

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
        elevation: 0,
      ),

      body:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // ==================================================
            // TYPE ICON
            // ==================================================

            Container(
              width: 64,
              height: 64,
              decoration:
                  BoxDecoration(
                color: typeColor
                    .withOpacity(
                  0.10,
                ),
                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
              ),
              child: Icon(
                _getTypeIcon(),
                size: 34,
                color: typeColor,
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            // ==================================================
            // TITLE
            // ==================================================

            Text(
              title,
              style:
                  const TextStyle(
                fontSize: 25,
                fontWeight:
                    FontWeight.bold,
                height: 1.2,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            // ==================================================
            // TYPE CHIP
            // ==================================================

            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),
              decoration:
                  BoxDecoration(
                color: typeColor
                    .withOpacity(
                  0.10,
                ),
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
              ),
              child: Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Icon(
                    _getTypeIcon(),
                    size: 16,
                    color: typeColor,
                  ),
                  const SizedBox(
                    width: 6,
                  ),
                  Text(
                    typeLabel,
                    style:
                        TextStyle(
                      color:
                          typeColor,
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            // ==================================================
            // POSTED DATE
            // ==================================================

            if (postedDate != null)
              Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 17,
                    color:
                        Colors.grey,
                  ),
                  const SizedBox(
                    width: 7,
                  ),
                  Text(
                    'Posted ${DateFormat(
                      'MMMM dd, yyyy • hh:mm a',
                    ).format(
                      postedDate,
                    )}',
                    style:
                        const TextStyle(
                      color:
                          Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),

            const Divider(
              height: 35,
            ),

            // ==================================================
            // COVERED AREA
            // ==================================================

            _buildCoverageDetails(
              context,
            ),

            const SizedBox(
              height: 20,
            ),

            // ==================================================
            // POWER INTERRUPTION
            // ==================================================

            if (type ==
                'power_interruption') ...[
              _buildPowerInterruptionDetails(
                context,
              ),
              const SizedBox(
                height: 20,
              ),
            ],

            // ==================================================
            // DISCONNECTION
            // ==================================================

            if (type ==
                'disconnection') ...[
              _buildDisconnectionDetails(
                context,
              ),
              const SizedBox(
                height: 20,
              ),
            ],

            // ==================================================
            // METER READING
            // ==================================================

            if (type ==
                'meter_reading') ...[
              _buildMeterReadingDetails(
                context,
              ),
              const SizedBox(
                height: 20,
              ),
            ],

            // ==================================================
            // ANNOUNCEMENT CONTENT
            // ==================================================

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

            Container(
              width:
                  double.infinity,
              padding:
                  const EdgeInsets.all(
                16,
              ),
              decoration:
                  BoxDecoration(
                color:
                    Colors.grey.shade50,
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
                border: Border.all(
                  color:
                      Colors.grey.shade200,
                ),
              ),
              child: Text(
                content,
                style:
                    const TextStyle(
                  fontSize: 16,
                  height: 1.6,
                ),
              ),
            ),

            const SizedBox(
              height: 25,
            ),

            // ==================================================
            // LOCATION SUMMARY
            // ==================================================

            if ((announcement[
                            'province'] ??
                        '')
                    .toString()
                    .isNotEmpty ||
                (announcement[
                            'district'] ??
                        '')
                    .toString()
                    .isNotEmpty)
              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets.all(
                  14,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors
                      .grey
                      .shade100,
                  borderRadius:
                      BorderRadius
                          .circular(
                    12,
                  ),
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    const Icon(
                      Icons.map_outlined,
                      size: 19,
                      color:
                          Colors.grey,
                    ),
                    const SizedBox(
                      width: 9,
                    ),
                    Expanded(
                      child: Text(
                        '${announcement['district'] ?? ''} • ${announcement['province'] ?? 'Sorsogon'}',
                        style:
                            const TextStyle(
                          color:
                              Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}