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
        .where('status', isEqualTo: 'pending')
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
                SizedBox(
                  height: 220, // ⚠️ FIX HEIGHT MUST
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: _buildKpiGrid(context)),

                      const SizedBox(width: 10),

                      // Expanded(
                      //   flex: 1,
                      //   child: _buildSpamSuspectsSection(context),
                      // ),
                    ],
                  ),
                ),
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

  // ── KPI cards ───────────────────────────────────────────────────────────────

  Widget _buildKpiGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 1.2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _kpiCard(
          context,
          'Users',
          Icons.people_rounded,
          const Color(0xFF6C63FF),
          _usersStream,
        ),
        _kpiCard(
          context,
          'Admins',
          Icons.admin_panel_settings_rounded,
          const Color(0xFF00B4D8),
          _usersStream,
          countFn: (docs) => docs
              .where(
                (d) =>
                    (d.data()['role'] ?? '').toString().toLowerCase() ==
                    'admin',
              )
              .length,
        ),
        _kpiCard(
          context,
          'Banned',
          Icons.gpp_bad_rounded,
          const Color(0xFFFF6B6B),
          _usersStream,
          countFn: (docs) => docs
              .where(
                (d) =>
                    (d.data()['status'] ?? '').toString().toLowerCase() ==
                    'banned',
              )
              .length,
        ),
        _kpiCard(
          context,
          'Posts',
          Icons.article_rounded,
          const Color(0xFF9B59B6),
          _postsStream,
        ),
        _kpiCard(
          context,
          'Flagged',
          Icons.flag_rounded,
          const Color(0xFFEE5A24),
          _flaggedPostsStream,
        ),
        _kpiCard(
          context,
          'Flag Cmt',
          Icons.comment_rounded,
          const Color(0xFFFFB84D),
          _flaggedCommentsStream,
        ),
        _kpiCard(
          context,
          'Spam',
          Icons.report_gmailerrorred_rounded,
          const Color(0xFFFF3B30),
          _spamStream,
        ),
      ],
    );
  }

  Widget _kpiCard(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    Stream<QuerySnapshot<Map<String, dynamic>>> stream, {
    int Function(List<QueryDocumentSnapshot<Map<String, dynamic>>>)? countFn,
  }) {
    return _KpiCardWrapper(
      label: label,
      icon: icon,
      color: color,
      stream: stream,
      countFn: countFn,
    );
  }

  // ── 7-day trend chart ───────────────────────────────────────────────────────

  Widget _buildTrendChart(BuildContext context) {
    return overviewCard(
      context,
      title: '7-Day Activity Trend',
      description:
          'Daily count of new posts created vs content flagged for moderation.',
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
                if (!snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                  );
                }
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
                            if (i < 0 || i >= days.length) {
                              return const SizedBox.shrink();
                            }
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
            description: 'Breakdown of all accounts by their current role.',
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
            description: '% of all posts currently flagged for review.',
            child: FutureBuilder<RiskData>(
              future: loadRiskData(),
              builder: (_, snap) {
                final r = snap.data ?? const RiskData(0, 0);
                final ratio = r.totalPosts == 0
                    ? 0.0
                    : (r.flagged / r.totalPosts).clamp(0.0, 1.0);
                final percent = (ratio * 100).toStringAsFixed(1);
                final Color gaugeColor;
                final String riskLabel;
                if (ratio < 0.05) {
                  gaugeColor = const Color(0xFF00C49A);
                  riskLabel = 'Low Risk';
                } else if (ratio < 0.15) {
                  gaugeColor = const Color(0xFFFFB84D);
                  riskLabel = 'Moderate';
                } else {
                  gaugeColor = const Color(0xFFFF6B6B);
                  riskLabel = 'High Risk';
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
                            color: gaugeColor,
                            backgroundColor: gaugeColor.withValues(alpha: 0.15),
                          ),
                          Center(
                            child: Text(
                              '$percent%',
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
                        color: gaugeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        riskLabel,
                        style: TextStyle(
                          color: gaugeColor,
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
      description:
          'Users with the most published posts. Shows total posts and flagged posts.',
      child: FutureBuilder<List<ContributorStats>>(
        future: loadTopContributors(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const SizedBox(
              height: 180,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
              ),
            );
          }
          final entries = snap.data!;
          if (entries.isEmpty) {
            return const SizedBox(
              height: 80,
              child: Center(child: Text('No post data yet')),
            );
          }
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
                      final stat = entries[i];
                      return BarTooltipItem(
                        '${stat.email}\n${stat.totalPosts} total\n${stat.flaggedPosts} flagged',
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
                        if (i < 0 || i >= entries.length) {
                          return const SizedBox.shrink();
                        }
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
      description:
          'Latest posts and flagged content across the platform, newest first.',
      child: FutureBuilder<List<RecentEvent>>(
        future: loadRecentEvents(),
        builder: (_, snap) {
          final events = snap.data ?? const [];
          if (events.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No events yet'),
            );
          }
          return Column(
            children: events.take(10).map((e) {
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: e.color.withValues(alpha: 0.12),
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
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // ── Spam suspects section ───────────────────────────────────────────────────

  Widget _buildSpamSuspectsSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final myEmail =
        FirebaseAuth.instance.currentUser?.email ?? 'admin@safespot.local';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: _SpamSuspectsPanel(
        text: isDark ? const Color(0xFFE7EDFF) : const Color(0xFF2D3142),
        muted: isDark ? const Color(0xFF9CACCF) : const Color(0xFF667086),
        myEmail: myEmail,
        spamStream: _spamStream,
      ),
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

  List<QueryDocumentSnapshot<Map<String, dynamic>>> lastDocs = [];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.spamStream,
      builder: (context, snap) {
        // ✅ If new data comes → update cache
        if (snap.hasData) {
          lastDocs = snap.data!.docs;
        }

        // ✅ Use cached data ALWAYS
        final docs = lastDocs;

        // ✅ If still empty → hide (first load only)
        if (docs.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30).withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFFF3B30).withOpacity(0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER
                InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
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
                        Text(
                          'Spam Suspects (${docs.length})',
                          style: const TextStyle(
                            color: Color(0xFFFF3B30),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: const Color(0xFFFF3B30),
                        ),
                      ],
                    ),
                  ),
                ),

                // LIST
                if (_expanded)
                  ...docs.map((doc) {
                    final data = doc.data();
                    final email = (data['email'] ?? 'unknown').toString();

                    return ListTile(
                      title: Text(email),
                      trailing: TextButton(
                        onPressed: () async {
                          await doc.reference.update({'status': 'resolved'});

                          setState(() {
                            lastDocs.removeWhere((d) => d.id == doc.id);
                          });
                        },
                        child: const Text('Dismiss'),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _resolve(DocumentReference ref) async {
    try {
      await ref.update({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': widget.myEmail,
      });
    } catch (e) {
      print("Error resolving spam: $e");
    }
  }
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

class _KpiCardWrapper extends StatefulWidget {
  const _KpiCardWrapper({
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
  State<_KpiCardWrapper> createState() => _KpiCardWrapperState();
}

class _KpiCardWrapperState extends State<_KpiCardWrapper> {
  int? lastValue;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.stream,
      builder: (_, snap) {
        if (snap.hasData) {
          final docs = snap.data!.docs;
          final count = widget.countFn != null
              ? widget.countFn!(docs)
              : docs.length;

          lastValue = count;
        }

        final displayValue = lastValue != null ? lastValue.toString() : '...';

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.color.withOpacity(0.4)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // ✅ FIX
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(widget.icon, size: 18, color: widget.color),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayValue,
                    style: const TextStyle(
                      color: Color(0xFF2D3142),
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    widget.label,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
