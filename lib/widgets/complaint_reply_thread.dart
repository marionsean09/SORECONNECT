import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:soreconnect/services/complaint_services.dart';

// ============================================================
// COMPLAINT REPLY THREAD
// Shared, ongoing conversation between the consumer, teller, and
// director for one complaint. Embedded directly in each role's
// complaint card so every side can keep replying back and forth.
// ============================================================

class ComplaintReplyThread extends StatefulWidget {
  const ComplaintReplyThread({
    super.key,
    required this.complaintId,
    required this.currentSenderRole,
    required this.currentSenderName,
  });

  final String complaintId;
  final String currentSenderRole;
  final String currentSenderName;

  @override
  State<ComplaintReplyThread> createState() =>
      _ComplaintReplyThreadState();
}

class _ComplaintReplyThreadState extends State<ComplaintReplyThread> {
  final ComplaintService _complaintService = ComplaintService();
  final TextEditingController _messageController = TextEditingController();

  bool _sending = false;

  static const Map<String, Color> _roleColors = {
    'Consumer': Color(0xFF1565C0),
    'Teller': Color(0xFFFFA000),
    'Director': Color(0xFF1B5E20),
  };

  Color _colorForRole(String role) {
    return _roleColors[role] ?? Colors.grey.shade600;
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty) return;

    setState(() {
      _sending = true;
    });

    try {
      await _complaintService.sendReply(
        complaintId: widget.complaintId,
        message: text,
        senderRole: widget.currentSenderRole,
        senderName: widget.currentSenderName,
      );

      _messageController.clear();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Failed to send reply: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _showEditReplyDialog(
    String replyId,
    String currentMessage,
  ) async {
    final controller = TextEditingController(text: currentMessage);
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Edit Reply',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: TextField(
                controller: controller,
                autofocus: true,
                minLines: 1,
                maxLines: 5,
                enabled: !saving,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _colorForRole(
                      widget.currentSenderRole,
                    ),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          final text = controller.text.trim();

                          if (text.isEmpty) return;

                          setDialogState(() => saving = true);

                          try {
                            await _complaintService.updateReply(
                              complaintId: widget.complaintId,
                              replyId: replyId,
                              message: text,
                            );

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          } catch (e) {
                            setDialogState(() => saving = false);

                            if (!dialogContext.mounted) return;

                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.red,
                                content: Text('Failed to update reply: $e'),
                              ),
                            );
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
  }

  Widget _buildBubble(String replyId, Map<String, dynamic> data) {
    final senderRole = (data['senderRole'] ?? '').toString();
    final senderName = (data['senderName'] ?? '').toString();
    final senderId = (data['senderId'] ?? '').toString();
    final message = (data['message'] ?? '').toString();
    final createdAt = data['createdAt'];
    final editedAt = data['editedAt'];

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isMine = senderId.isNotEmpty && senderId == currentUid;

    String timeText = '';

    if (createdAt is Timestamp) {
      timeText = DateFormat('MMM dd, hh:mm a').format(createdAt.toDate());
    }

    final color = _colorForRole(senderRole);

    return Align(
      alignment:
          isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress:
            isMine ? () => _showEditReplyDialog(replyId, message) : null,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$senderName · $senderRole',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: const TextStyle(fontSize: 14, height: 1.3),
              ),
              if (timeText.isNotEmpty || editedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  editedAt != null
                      ? '$timeText${timeText.isNotEmpty ? ' · ' : ''}edited'
                      : timeText,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Conversation',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: _complaintService.getComplaintReplies(
            widget.complaintId,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return Text(
                'Error loading replies: ${snapshot.error}',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'No replies yet.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                return _buildBubble(docs[index].id, data);
              },
            );
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                enabled: !_sending,
                decoration: InputDecoration(
                  hintText: 'Write a reply...',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _sending
                ? const SizedBox(
                    height: 36,
                    width: 36,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton.filled(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send),
                  ),
          ],
        ),
      ],
    );
  }
}
