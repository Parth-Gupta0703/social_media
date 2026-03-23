// Shared utility functions for reading Firestore document fields.
// Used across moderation list and card widgets.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads the first non-empty value from a list of keys in a Firestore document.
String readFirst(Map<String, dynamic> data, List<String> keys,
    {String fallback = ''}) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

/// Converts a Firestore [Timestamp] to a human-readable "time ago" string.
String timeAgo(dynamic timestamp) {
  if (timestamp is! Timestamp) return '';
  final diff = DateTime.now().difference(timestamp.toDate());
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  return '${(diff.inDays / 30).floor()}mo ago';
}

/// Extracts the display message from a moderation document.
String extractMessage(Map<String, dynamic> data) =>
    readFirst(data, ['Message', 'Text', 'Comment', 'Reply', 'Content'],
        fallback: 'No content');

/// Extracts the reason from a moderation document.
String extractReason(Map<String, dynamic> data) {
  final text = (data['Reason'] ?? '').toString().trim();
  return text.isEmpty ? 'Unspecified' : text;
}

/// Extracts the user email from a moderation document.
String extractEmail(Map<String, dynamic> data) {
  final text = ((data['UserEmail'] ?? data['email']) ?? '').toString().trim();
  return text.isEmpty ? 'unknown' : text;
}

/// Extracts the content type from a moderation document.
String extractType(Map<String, dynamic> data) =>
    (data['Type'] ?? '').toString().trim();
