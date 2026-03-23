// Shared UI widgets used in the admin overview page.
// Extracted from admin_overview_page.dart for clarity.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

// ── Card container ────────────────────────────────────────────────────────────

/// Styled card container used by all overview sections.
Widget overviewCard(
  BuildContext context, {
  required String title,
  required Widget child,
  String description = '',
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1A1F34) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
          color: isDark
              ? const Color(0xFF2A3554)
              : const Color(0xFFD8DEEE)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: isDark
                    ? const Color(0xFFE7EDFF)
                    : const Color(0xFF2D3142))),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(description,
              style: const TextStyle(
                  color: Color(0xFF9CACCF), fontSize: 11)),
        ],
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

// ── Chart helpers ─────────────────────────────────────────────────────────────

/// Builds a pie chart section with a minimum non-zero value to avoid rendering bugs.
PieChartSectionData overviewPie(double value, Color color, String title) {
  return PieChartSectionData(
    value: value == 0 ? 0.01 : value,
    color: color,
    title: value == 0 ? '' : value.toInt().toString(),
    titleStyle: const TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
    radius: 54,
  );
}

/// Builds a smooth line bar for a LineChart.
LineChartBarData overviewLine(List<int> values, Color color) {
  return LineChartBarData(
    spots: List.generate(
        values.length, (i) => FlSpot(i.toDouble(), values[i].toDouble())),
    color: color,
    isCurved: true,
    barWidth: 2.5,
    dotData: FlDotData(
      show: true,
      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
          radius: 3,
          color: color,
          strokeWidth: 1.5,
          strokeColor: Colors.white),
    ),
  );
}

// ── Shared widgets ────────────────────────────────────────────────────────────

/// A small colored dot + label used in chart legends.
class LegendDot extends StatelessWidget {
  const LegendDot({super.key, required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF677489))),
      ],
    );
  }
}

// ── Utility ───────────────────────────────────────────────────────────────────

/// Converts a [Timestamp] to a human-readable "time ago" string.
String overviewTimeAgo(dynamic ts) {
  if (ts == null) return '';
  final date = ts.toDate() as DateTime;
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  return '${(diff.inDays / 30).floor()}mo ago';
}
