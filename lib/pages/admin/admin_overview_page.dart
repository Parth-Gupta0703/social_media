import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'admin_dashboard.dart';
import 'overview/overview_data.dart';
import 'overview/overview_widgets.dart';

class AdminOverviewPage extends StatefulWidget {
  const AdminOverviewPage({super.key});

  @override
  State<AdminOverviewPage> createState() => _AdminOverviewPageState();
}

class _AdminOverviewPageState extends State<AdminOverviewPage> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _postsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _flaggedPostsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _flaggedCommentsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _spamStream;

  @override
  void initState() {
    super.initState();
    _usersStream = FirebaseFirestore.instance.collection('Users').snapshots();
    _postsStream = FirebaseFirestore.instance
        .collection('UserPosts')
        .snapshots();
    _flaggedPostsStream = FirebaseFirestore.instance
        .collection('ModeratedPosts')
        .snapshots();
    _flaggedCommentsStream = FirebaseFirestore.instance
        .collection('ModeratedComments')
        .snapshots();
    _spamStream = FirebaseFirestore.instance
        .collection('spam_reports')
        .where('status', whereIn: ['pending', 'high_risk'])
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F1220)
          : const Color(0xFFF4F8FF),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            backgroundColor: isDark
                ? const Color(0xFF171D31)
                : const Color(0xFFE8EEFF),
            flexibleSpace: FlexibleSpaceBar(
              background: AdminPageHeader(
                title: 'Admin Dashboard',
                subtitle: 'SafeSpot Control Panel',
                iconData: Icons.dashboard_rounded,
                fromColor: const Color(0xFF6C63FF),
                toColor: const Color(0xFFFF8FAB),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(14),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── KPI grid — full width, no side-by-side with spam panel ──
                // GridView + IntrinsicHeight is incompatible (crashes).
                // Show KPI grid full-width, spam panel below it separately.
                _buildKpiGrid(context),
                const SizedBox(height: 12),
                _buildSpamPanel(context),
                const SizedBox(height: 16),
                _buildTrendChart(context),
                const SizedBox(height: 16),
                _buildRoleAndRiskRow(context),
                const SizedBox(height: 16),
                _buildTopContributors(context),
                const SizedBox(height: 16),
                _buildRecentEvents(context),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── KPI grid ────────────────────────────────────────────────────────────────

  Widget _buildKpiGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      childAspectRatio: 1.0,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: [
        _KpiCard(
          label: 'Users',
          icon: Icons.people_rounded,
          color: const Color(0xFF6C63FF),
          stream: _usersStream,
        ),
        _KpiCard(
          label: 'Admins',
          icon: Icons.admin_panel_settings_rounded,
          color: const Color(0xFF00B4D8),
          stream: _usersStream,
          countFn: (d) => d
              .where(
                (x) =>
                    (x.data()['role'] ?? '').toString().toLowerCase() ==
                    'admin',
              )
              .length,
        ),
        _KpiCard(
          label: 'Banned',
          icon: Icons.gpp_bad_rounded,
          color: const Color(0xFFFF6B6B),
          stream: _usersStream,
          countFn: (d) => d
              .where(
                (x) =>
                    (x.data()['status'] ?? '').toString().toLowerCase() ==
                    'banned',
              )
              .length,
        ),
        _KpiCard(
          label: 'Posts',
          icon: Icons.article_rounded,
          color: const Color(0xFF9B59B6),
          stream: _postsStream,
        ),
        _KpiCard(
          label: 'Flagged',
          icon: Icons.flag_rounded,
          color: const Color(0xFFEE5A24),
          stream: _flaggedPostsStream,
        ),
        _KpiCard(
          label: 'Flag Cmt',
          icon: Icons.comment_rounded,
          color: const Color(0xFFFFB84D),
          stream: _flaggedCommentsStream,
        ),
        _KpiCard(
          label: 'Spam',
          icon: Icons.report_gmailerrorred_rounded,
          color: const Color(0xFFFF3B30),
          stream: _spamStream,
        ),
      ],
    );
  }

  // ── Spam panel ──────────────────────────────────────────────────────────────

  Widget _buildSpamPanel(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final myEmail =
        FirebaseAuth.instance.currentUser?.email ?? 'admin@safespot.local';
    return _SpamSuspectsPanel(
      text: isDark ? const Color(0xFFE7EDFF) : const Color(0xFF2D3142),
      muted: isDark ? const Color(0xFF9CACCF) : const Color(0xFF667086),
      myEmail: myEmail,
      spamStream: _spamStream,
    );
  }

  // ── 7-day trend chart ───────────────────────────────────────────────────────

  Widget _buildTrendChart(BuildContext context) {
    return overviewCard(
      context,
      title: '7-Day Activity Trend',
      description: 'Daily count of new posts vs flagged content.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              LegendDot(color: Color(0xFF6C63FF), label: 'New Posts'),
              LegendDot(color: Color(0xFFFF6B6B), label: 'Flagged Posts'),
              LegendDot(color: Color(0xFFFFB84D), label: 'Flagged Comments'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 200,
            child: FutureBuilder<TrendData>(
              future: loadTrendData(),
              builder: (_, snap) {
                if (!snap.hasData)
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                  );
                final d = snap.data!;
                final allVals = [
                  ...d.posts,
                  ...d.flaggedPosts,
                  ...d.flaggedComments,
                ];
                final maxY =
                    (allVals.isEmpty
                            ? 5
                            : allVals.reduce((a, b) => a > b ? a : b) + 2)
                        .toDouble();
                return LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: maxY,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => const FlLine(
                        color: Color(0xFFE6EAF2),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, _) {
                            const days = [
                              'Mon',
                              'Tue',
                              'Wed',
                              'Thu',
                              'Fri',
                              'Sat',
                              'Sun',
                            ];
                            final i = v.toInt();
                            if (i < 0 || i >= days.length)
                              return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                days[i],
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF9CACCF),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      overviewLine(d.posts, const Color(0xFF6C63FF)),
                      overviewLine(d.flaggedPosts, const Color(0xFFFF6B6B)),
                      overviewLine(d.flaggedComments, const Color(0xFFFFB84D)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Role pie + Risk gauge ───────────────────────────────────────────────────

  Widget _buildRoleAndRiskRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: overviewCard(
            context,
            title: 'User Roles',
            description: 'Breakdown of all accounts by role.',
            child: Column(
              children: [
                SizedBox(
                  height: 160,
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _usersStream,
                    builder: (_, snap) {
                      final docs = snap.data?.docs ?? const [];
                      final adminN = docs
                          .where(
                            (d) =>
                                (d.data()['role'] ?? '')
                                    .toString()
                                    .toLowerCase() ==
                                'admin',
                          )
                          .length
                          .toDouble();
                      final bannedN = docs
                          .where(
                            (d) =>
                                (d.data()['status'] ?? '')
                                    .toString()
                                    .toLowerCase() ==
                                'banned',
                          )
                          .length
                          .toDouble();
                      final userN = (docs.length - adminN.toInt()).toDouble();
                      return PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 26,
                          sections: [
                            overviewPie(
                              adminN,
                              const Color(0xFF6C63FF),
                              'Admin',
                            ),
                            overviewPie(
                              userN,
                              const Color(0xFF00B4D8),
                              'Users',
                            ),
                            overviewPie(
                              bannedN,
                              const Color(0xFFFF6B6B),
                              'Banned',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                const Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    LegendDot(color: Color(0xFF6C63FF), label: 'Admins'),
                    LegendDot(color: Color(0xFF00B4D8), label: 'Members'),
                    LegendDot(color: Color(0xFFFF6B6B), label: 'Banned'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: overviewCard(
            context,
            title: 'Moderation Risk',
            description: '% of all posts currently flagged.',
            child: FutureBuilder<RiskData>(
              future: loadRiskData(),
              builder: (_, snap) {
                final r = snap.data ?? const RiskData(0, 0);
                final ratio = r.totalPosts == 0
                    ? 0.0
                    : (r.flagged / r.totalPosts).clamp(0.0, 1.0);
                final pct = (ratio * 100).toStringAsFixed(1);
                final Color gc;
                final String rl;
                if (ratio < 0.05) {
                  gc = const Color(0xFF00C49A);
                  rl = 'Low Risk';
                } else if (ratio < 0.15) {
                  gc = const Color(0xFFFFB84D);
                  rl = 'Moderate';
                } else {
                  gc = const Color(0xFFFF6B6B);
                  rl = 'High Risk';
                }
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: ratio,
                            strokeWidth: 12,
                            color: gc,
                            backgroundColor: gc.withOpacity(0.15),
                          ),
                          Center(
                            child: Text(
                              '$pct%',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: gc.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        rl,
                        style: TextStyle(
                          color: gc,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${r.flagged} flagged / ${r.totalPosts} posts',
                      style: const TextStyle(
                        color: Color(0xFF9CACCF),
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── Top contributors ────────────────────────────────────────────────────────

  Widget _buildTopContributors(BuildContext context) {
    return overviewCard(
      context,
      title: 'Top Contributors',
      description: 'Users with the most published posts.',
      child: FutureBuilder<List<ContributorStats>>(
        future: loadTopContributors(),
        builder: (_, snap) {
          if (!snap.hasData)
            return const SizedBox(
              height: 180,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
              ),
            );
          final entries = snap.data!;
          if (entries.isEmpty)
            return const SizedBox(
              height: 80,
              child: Center(child: Text('No post data yet')),
            );
          final maxY =
              (entries
                          .map((e) => e.totalPosts)
                          .fold(0, (a, b) => a > b ? a : b) +
                      2)
                  .toDouble();
          return SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, _, rod, _) {
                      final i = group.x;
                      if (i < 0 || i >= entries.length) return null;
                      final s = entries[i];
                      return BarTooltipItem(
                        '${s.email}\n${s.totalPosts} total\n${s.flaggedPosts} flagged',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: Color(0xFFE6EAF2), strokeWidth: 1),
                ),
                barGroups: List.generate(
                  entries.length,
                  (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: entries[i].totalPosts.toDouble(),
                        color: const Color(0xFF6C63FF),
                        width: 22,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        rodStackItems: [
                          BarChartRodStackItem(
                            0,
                            entries[i].flaggedPosts.toDouble(),
                            const Color(0xFFFF6B6B),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 66,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= entries.length)
                          return const SizedBox.shrink();
                        final raw = entries[i].email.split('@').first;
                        final label = raw.length > 9
                            ? '${raw.substring(0, 9)}…'
                            : raw;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: RotatedBox(
                            quarterTurns: 1,
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF677489),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Recent events ───────────────────────────────────────────────────────────

  Widget _buildRecentEvents(BuildContext context) {
    return overviewCard(
      context,
      title: 'Recent Activity',
      description: 'Latest posts and flagged content, newest first.',
      child: FutureBuilder<List<RecentEvent>>(
        future: loadRecentEvents(),
        builder: (_, snap) {
          final events = snap.data ?? const [];
          if (events.isEmpty)
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No events yet'),
            );
          return Column(
            children: events
                .take(10)
                .map(
                  (e) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: e.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(e.icon, size: 16, color: e.color),
                    ),
                    title: Text(
                      e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      e.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: e.ts != null
                        ? Text(
                            overviewTimeAgo(e.ts),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF9CACCF),
                            ),
                          )
                        : null,
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI Card — no spaceBetween, uses simple Column so it never overflows
// ─────────────────────────────────────────────────────────────────────────────

class _KpiCard extends StatefulWidget {
  const _KpiCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.stream,
    this.countFn,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final int Function(List<QueryDocumentSnapshot<Map<String, dynamic>>>)?
  countFn;

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  int? _cached;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.stream,
      builder: (_, snap) {
        if (snap.hasData) {
          final docs = snap.data!.docs;
          _cached = widget.countFn != null
              ? widget.countFn!(docs)
              : docs.length;
        }
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1F34) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.color.withOpacity(0.4)),
          ),
          child: Column(
            // No spaceBetween — just top-aligned, no overflow risk
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(widget.icon, size: 16, color: widget.color),
              const SizedBox(height: 4),
              Text(
                _cached != null ? '$_cached' : '…',
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFFE7EDFF)
                      : const Color(0xFF2D3142),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              Text(
                widget.label,
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF9CACCF)
                      : const Color(0xFF6B7280),
                  fontSize: 9,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Spam Suspects Panel
// ─────────────────────────────────────────────────────────────────────────────

class _SpamSuspectsPanel extends StatefulWidget {
  const _SpamSuspectsPanel({
    required this.text,
    required this.muted,
    required this.myEmail,
    required this.spamStream,
  });

  final Color text;
  final Color muted;
  final String myEmail;
  final Stream<QuerySnapshot<Map<String, dynamic>>> spamStream;

  @override
  State<_SpamSuspectsPanel> createState() => _SpamSuspectsPanelState();
}

class _SpamSuspectsPanelState extends State<_SpamSuspectsPanel> {
  bool _expanded = true;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.spamStream,
      builder: (context, snap) {
        if (snap.hasData) _docs = snap.data!.docs;
        if (_docs.isEmpty) return const SizedBox.shrink();

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFF3B30).withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFFF3B30).withOpacity(0.35),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.report_gmailerrorred_rounded,
                        color: Color(0xFFFF3B30),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Spam Suspects (${_docs.length})',
                          style: const TextStyle(
                            color: Color(0xFFFF3B30),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: const Color(0xFFFF3B30),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              if (_expanded)
                ..._docs.map((doc) {
                  final data = doc.data();
                  final email = (data['email'] ?? 'unknown').toString();
                  final deniedCount = (data['deniedCount'] ?? 0) as int;
                  final ts = data['reportedAt'] as Timestamp?;
                  final ago = ts == null ? '' : _timeAgo(ts.toDate());
                  return Container(
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0x22FF3B30))),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF3B30).withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              email.isNotEmpty ? email[0].toUpperCase() : '?',
                              style: const TextStyle(
                                color: Color(0xFFFF3B30),
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  email,
                                  style: TextStyle(
                                    color: widget.text,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '$deniedCount× rate limit${ago.isNotEmpty ? ' · $ago' : ''}',
                                  style: TextStyle(
                                    color: widget.muted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _resolve(doc.reference),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFFF3B30),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Dismiss',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _resolve(DocumentReference ref) async {
    await ref.update({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': widget.myEmail,
    });
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}
