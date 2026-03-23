// Data models and Firestore data loaders for the admin overview page.
// Extracted from admin_overview_page.dart for clarity.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ── Data models ───────────────────────────────────────────────────────────────

/// Holds 7-day post and flagged counts indexed by weekday (0=Mon … 6=Sun).
class TrendData {
  const TrendData(this.posts, this.flaggedPosts, this.flaggedComments);
  final List<int> posts;
  final List<int> flaggedPosts;
  final List<int> flaggedComments;
}

/// Totals for the moderation risk gauge.
class RiskData {
  const RiskData(this.totalPosts, this.flagged);
  final int totalPosts;
  final int flagged;
}

/// One entry in the Recent Activity list.
class RecentEvent {
  const RecentEvent({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.ts,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Timestamp? ts;
}

/// One bar in the Top Contributors chart.
class ContributorStats {
  const ContributorStats({
    required this.email,
    required this.totalPosts,
    required this.flaggedPosts,
  });
  final String email;
  final int totalPosts;
  final int flaggedPosts;
}

// ── Data loaders ──────────────────────────────────────────────────────────────

/// Loads 7-day trend data: new posts, flagged posts, and flagged comments per weekday.
Future<TrendData> loadTrendData() async {
  final start = DateTime.now().subtract(const Duration(days: 6));
  final snaps = await Future.wait([
    FirebaseFirestore.instance
        .collection('User Posts')
        .where('TimeStamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .get(),
    FirebaseFirestore.instance
        .collection('Moderated Posts')
        .where('TimeStamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .get(),
    FirebaseFirestore.instance
        .collection('Moderated Comments')
        .where('TimeStamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .get(),
  ]);

  List<int> count(QuerySnapshot<Map<String, dynamic>> s) {
    final out = List<int>.filled(7, 0);
    for (final d in s.docs) {
      final ts = d.data()['TimeStamp'];
      if (ts is! Timestamp) continue;
      final idx = ts.toDate().weekday - 1;
      if (idx >= 0 && idx < 7) out[idx]++;
    }
    return out;
  }

  return TrendData(count(snaps[0]), count(snaps[1]), count(snaps[2]));
}

/// Loads risk gauge data: total published posts vs unique flagged posts.
Future<RiskData> loadRiskData() async {
  final snaps = await Future.wait([
    FirebaseFirestore.instance.collection('User Posts').get(),
    FirebaseFirestore.instance.collection('Moderated Posts').get(),
  ]);

  // Count unique flagged post IDs to avoid double-counting multiple flags per post
  final uniqueFlaggedIds = <String>{};
  for (final doc in snaps[1].docs) {
    final pid = doc.data()['OriginalPostId'];
    if (pid != null && pid.toString().isNotEmpty) {
      uniqueFlaggedIds.add(pid.toString());
    }
  }

  return RiskData(snaps[0].docs.length, uniqueFlaggedIds.length);
}

/// Loads the top 6 contributors by post count.
Future<List<ContributorStats>> loadTopContributors() async {
  final snaps = await Future.wait([
    FirebaseFirestore.instance.collection('User Posts').limit(300).get(),
    FirebaseFirestore.instance.collection('Moderated Posts').limit(300).get(),
  ]);

  final totalMap = <String, int>{};
  final flaggedMap = <String, int>{};

  for (final doc in snaps[0].docs) {
    final email =
        (doc.data()['UserEmail'] ?? '').toString().trim().toLowerCase();
    if (!email.contains('@')) continue;
    totalMap[email] = (totalMap[email] ?? 0) + 1;
  }

  for (final doc in snaps[1].docs) {
    final email =
        (doc.data()['UserEmail'] ?? '').toString().trim().toLowerCase();
    if (!email.contains('@')) continue;
    flaggedMap[email] = (flaggedMap[email] ?? 0) + 1;
  }

  final list = totalMap.entries
      .map((e) => ContributorStats(
            email: e.key,
            totalPosts: e.value,
            flaggedPosts: flaggedMap[e.key] ?? 0,
          ))
      .toList()
    ..sort((a, b) => b.totalPosts.compareTo(a.totalPosts));

  return list.take(6).toList();
}

/// Loads the 10 most recent events (posts, flagged posts, flagged comments).
Future<List<RecentEvent>> loadRecentEvents() async {
  final snaps = await Future.wait([
    FirebaseFirestore.instance
        .collection('User Posts')
        .orderBy('TimeStamp', descending: true)
        .limit(5)
        .get(),
    FirebaseFirestore.instance
        .collection('Moderated Posts')
        .orderBy('TimeStamp', descending: true)
        .limit(5)
        .get(),
    FirebaseFirestore.instance
        .collection('Moderated Comments')
        .orderBy('TimeStamp', descending: true)
        .limit(5)
        .get(),
  ]);

  final events = <RecentEvent>[];

  for (final doc in snaps[0].docs) {
    events.add(RecentEvent(
      icon: Icons.article_rounded,
      color: const Color(0xFF6C63FF),
      title: 'New post by ${doc.data()['UserEmail'] ?? 'unknown'}',
      subtitle: (doc.data()['Message'] ?? '').toString(),
      ts: doc.data()['TimeStamp'] as Timestamp?,
    ));
  }

  for (final doc in snaps[1].docs) {
    events.add(RecentEvent(
      icon: Icons.flag_rounded,
      color: const Color(0xFFFF6B6B),
      title: 'Post flagged — ${doc.data()['Reason'] ?? 'unknown reason'}',
      subtitle:
          (doc.data()['Message'] ?? doc.data()['Text'] ?? '').toString(),
      ts: doc.data()['TimeStamp'] as Timestamp?,
    ));
  }

  for (final doc in snaps[2].docs) {
    events.add(RecentEvent(
      icon: Icons.comment_rounded,
      color: const Color(0xFFFFB84D),
      title: 'Comment flagged — ${doc.data()['Reason'] ?? 'unknown reason'}',
      subtitle:
          (doc.data()['Comment'] ?? doc.data()['Text'] ?? '').toString(),
      ts: doc.data()['TimeStamp'] as Timestamp?,
    ));
  }

  events.sort((a, b) => (b.ts?.millisecondsSinceEpoch ?? 0)
      .compareTo(a.ts?.millisecondsSinceEpoch ?? 0));
  return events;
}
