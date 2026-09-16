import 'package:flutter/material.dart';

// ============================================================
// TICKET BADGE
// Compact, high-contrast chip showing just the ticket number
// (no "Ticket #" label) so it reads at a glance across the
// consumer, teller, and director complaint cards.
// ============================================================

class TicketBadge extends StatelessWidget {
  const TicketBadge({
    super.key,
    required this.ticketNumber,
    this.color = const Color(0xFF1565C0),
  });

  final String ticketNumber;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (ticketNumber.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        ticketNumber,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: color,
        ),
      ),
    );
  }
}
