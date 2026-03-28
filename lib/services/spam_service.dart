// lib/services/spam_service.dart
//
// Logs rate-limit violations to Firestore so the admin dashboard
// can surface suspected spammers.
//
// Firestore structure — ONE document per user (docId = userId):
//   spam_reports/{userId}
//     userId:          string
//     email:           string
//     status:          "pending" | "high_risk" | "resolved"
//     reason:          "rate_limit"
//     deniedCount:     number   ← incremented on every violation
//     firstReportedAt: Timestamp
//     lastReportedAt:  Timestamp
//
// Threshold: deniedCount >= 3 → status promoted to "high_risk"

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SpamService {
  SpamService._internal();
  static final SpamService instance = SpamService._internal();

  static const int _highRiskThreshold = 3;

  final _col = FirebaseFirestore.instance.collection('spam_reports');

  /// Call whenever the rate limiter blocks a post attempt.
  /// Uses a transaction so concurrent violations don't corrupt the count.
  Future<void> logRateLimitViolation({
    required String userId,
    required String email,
  }) async {
    if (userId.isEmpty) return;

    final ref = _col.doc(userId);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);

        if (!snap.exists) {
          // First violation — create the document.
          tx.set(ref, {
            'userId': userId,
            'email': email,
            'status': 'pending',
            'reason': 'rate_limit',
            'deniedCount': 1,
            'firstReportedAt': FieldValue.serverTimestamp(),
            'lastReportedAt': FieldValue.serverTimestamp(),
            // 'reportedAt' is used by the admin dashboard .orderBy() query.
            'reportedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Subsequent violation — increment count and maybe escalate.
          final current = (snap.data()?['deniedCount'] ?? 0) as int;
          final newCount = current + 1;
          final currentStatus = (snap.data()?['status'] ?? 'pending')
              .toString();

          // Escalate to high_risk once threshold is hit,
          // but never downgrade if already resolved by admin.
          final newStatus =
              (currentStatus != 'resolved' && newCount >= _highRiskThreshold)
              ? 'high_risk'
              : currentStatus;

          tx.update(ref, {
            'deniedCount': newCount,
            'lastReportedAt': FieldValue.serverTimestamp(),
            'reportedAt': FieldValue.serverTimestamp(),
            'status': newStatus,
            'email': email,
          });
        }
      });

      debugPrint('[SpamService] Violation logged for $userId');
    } catch (e) {
      // Non-critical — never block the UI for a logging failure.
      debugPrint('[SpamService] Failed to log violation: $e');
    }
  }
}
