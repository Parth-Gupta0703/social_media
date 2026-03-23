// Shared chip and pill widgets used across the moderation UI.

import 'package:flutter/material.dart';

/// Colored chip showing the moderation reason (e.g., "Spam").
class ReasonChip extends StatelessWidget {
  const ReasonChip({super.key, required this.reason, required this.color});

  final String reason;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        reason,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Chip showing content type (e.g., "post", "comment", "Admin Flagged").
class TypeChip extends StatelessWidget {
  const TypeChip({
    super.key,
    required this.text,
    this.borderColor = const Color(0xFFC9D9F9),
    this.textColor = const Color(0xFF4B70B1),
  });

  final String text;
  final Color borderColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Small pill showing count (e.g., "3 posts") in the moderation header.
class CountPill extends StatelessWidget {
  const CountPill(this.text, this.color, {super.key});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Colored block used in the context view to display parent post/comment text.
class ContextBlock extends StatelessWidget {
  const ContextBlock({
    super.key,
    required this.label,
    required this.color,
    required this.text,
    this.email,
  });

  final String label;
  final Color color;
  final String text;
  final String? email;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF3C4659),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          if (email != null) ...[
            const SizedBox(height: 6),
            Text(
              email!,
              style: const TextStyle(color: Color(0xFF9CACCF), fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
