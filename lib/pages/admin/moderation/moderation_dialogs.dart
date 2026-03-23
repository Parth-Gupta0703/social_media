// Canned reason picker and generic confirm dialog for moderation actions.

import 'package:flutter/material.dart';

const List<String> kCannedReasons = [
  'Hate Speech / Discrimination',
  'Harassment or Bullying',
  'Spam or Misleading Content',
  'Explicit / Adult Content',
  'Violence or Threats',
  'False Information / Misinformation',
  'Other Policy Violation',
];

/// Opens a dialog for the admin to select a standard community guideline reason.
/// Returns the selected reason string, or null if cancelled.
Future<String?> pickCannedReason(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _CannedReasonDialog(),
  );
}

/// Opens a generic confirmation dialog. Returns true if confirmed.
Future<bool> showModerationConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required bool danger,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title,
          style: const TextStyle(
              color: Color(0xFF2D3142), fontWeight: FontWeight.w700)),
      content:
          Text(body, style: const TextStyle(color: Color(0xFF677489))),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel',
              style: TextStyle(color: Color(0xFF7D8A9C))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                danger ? const Color(0xFFFF6B6B) : const Color(0xFF00C49A),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child:
              Text(confirmLabel, style: const TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  return result ?? false;
}

// ── Private dialog widget ─────────────────────────────────────────────────────

class _CannedReasonDialog extends StatefulWidget {
  const _CannedReasonDialog();

  @override
  State<_CannedReasonDialog> createState() => _CannedReasonDialogState();
}

class _CannedReasonDialogState extends State<_CannedReasonDialog> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Select Removal Reason',
          style: TextStyle(
              color: Color(0xFF2D3142),
              fontWeight: FontWeight.w700,
              fontSize: 16)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This reason will be logged in the audit trail.',
                style: TextStyle(color: Color(0xFF9CACCF), fontSize: 12)),
            const SizedBox(height: 12),
            ...kCannedReasons.map(
              (r) => InkWell(
                onTap: () => setState(() => _selected = r),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Radio<String>(
                        value: r,
                        groupValue: _selected,
                        activeColor: const Color(0xFFFF6B6B),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        onChanged: (v) => setState(() => _selected = v),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(r,
                            style: const TextStyle(
                                color: Color(0xFF2D3142), fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: Color(0xFF7D8A9C))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF6B6B),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _selected == null
              ? null
              : () => Navigator.pop(context, _selected),
          child:
              const Text('Confirm', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
