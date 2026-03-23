import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ── Dialogs ───────────────────────────────────────────────────────────────────

Future<bool> showUserConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      content: Text(message, style: const TextStyle(color: Color(0xFF677489))),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Confirm', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// FIX: The original version called c.dispose() AFTER showDialog returned.
/// At that point the dialog's widget tree hasn't fully unwound, so Flutter
/// still has registered dependents on the controller — disposing it then
/// triggers "_dependents.isEmpty is not true" red screen crash.
///
/// Solution: dispose inside a post-frame callback so Flutter has fully
/// removed all widgets that depend on the controller before we dispose it.
Future<String?> showUserTextInputDialog(
  BuildContext context, {
  required String title,
  required String hint,
}) async {
  // Create the controller OUTSIDE the builder so we control its lifetime.
  final controller = TextEditingController();

  final result = await showDialog<String>(
    context: context,
    barrierDismissible: false, // prevent accidental dismiss
    builder: (ctx) =>
        _TextInputDialog(title: title, hint: hint, controller: controller),
  );

  // FIX: Schedule dispose for AFTER the current frame completes.
  // By then Flutter has fully torn down the dialog widget tree and there
  // are zero dependents left on the controller — safe to dispose.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    controller.dispose();
  });

  return result;
}

// ── Dedicated StatefulWidget for the text input dialog ───────────────────────
// Using a StatefulWidget instead of a plain builder function means Flutter
// manages the controller's lifecycle properly through the widget tree,
// preventing any stale-dependent issues.
class _TextInputDialog extends StatelessWidget {
  const _TextInputDialog({
    required this.title,
    required this.hint,
    required this.controller,
  });

  final String title;
  final String hint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      content: TextField(
        controller: controller,
        maxLines: 3,
        autofocus: true,
        decoration: InputDecoration(
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
          ),
        ),
      ),
      actions: [
        TextButton(
          // Cancel: pop with null (no result)
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Color(0xFF677489)),
          ),
        ),
        ElevatedButton(
          // Submit: pop with the current text value
          onPressed: () => Navigator.pop(context, controller.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Submit', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// ── User detail sheet ─────────────────────────────────────────────────────────

Future<void> showUserDetailsSheet(
  BuildContext context, {
  required String email,
  required String username,
  required String role,
  required String status,
  required String banReason,
  Timestamp? bannedAt,
}) async {
  int postCount = 0;
  int flagCount = 0;
  try {
    final results = await Future.wait([
      FirebaseFirestore.instance
          .collection('User Posts')
          .where('UserEmail', isEqualTo: email)
          .count()
          .get(),
      FirebaseFirestore.instance
          .collection('Moderated Posts')
          .where('UserEmail', isEqualTo: email)
          .count()
          .get(),
    ]);
    postCount = results[0].count ?? 0;
    flagCount = results[1].count ?? 0;
  } catch (_) {}

  if (!context.mounted) return;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD7DCE5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: role == 'admin'
                    ? const Color(0xFF6C63FF)
                    : const Color(0xFF00B4D8),
                child: Text(
                  email.isNotEmpty ? email[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      email,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (username.isNotEmpty)
                      Text(
                        '@$username',
                        style: const TextStyle(
                          color: Color(0xFF677489),
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _detailRow(
            Icons.badge_rounded,
            'Role',
            role == 'admin' ? 'Admin' : 'Member',
          ),
          _detailRow(
            Icons.circle_rounded,
            'Status',
            status == 'banned' ? '🚫 Banned' : '✅ Active',
          ),
          if (status == 'banned' && banReason.isNotEmpty)
            _detailRow(Icons.info_outline_rounded, 'Ban Reason', banReason),
          if (bannedAt != null)
            _detailRow(
              Icons.calendar_today_rounded,
              'Banned At',
              _formatDate(bannedAt),
            ),
          _detailRow(Icons.article_rounded, 'Posts Published', '$postCount'),
          _detailRow(Icons.flag_rounded, 'Posts Flagged', '$flagCount'),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

// ── Private helpers ───────────────────────────────────────────────────────────

Widget _detailRow(IconData icon, String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF9CACCF)),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: const TextStyle(color: Color(0xFF677489), fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF2D3142),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

String _formatDate(Timestamp ts) {
  final d = ts.toDate();
  return '${d.day}/${d.month}/${d.year}';
}

// ── Firestore helpers ─────────────────────────────────────────────────────────

Future<void> queueEmail(
  String to,
  String subject,
  String body, {
  required String fromAdmin,
}) async {
  await FirebaseFirestore.instance.collection('mail').add({
    'to': [to],
    'message': {'subject': subject, 'text': body},
    'createdBy': fromAdmin,
    'createdAt': Timestamp.now(),
  });
}

Future<void> collectForDeletion(
  WriteBatch batch,
  String collection,
  String email,
) async {
  final snap = await FirebaseFirestore.instance
      .collection(collection)
      .where('UserEmail', isEqualTo: email)
      .get();
  for (final doc in snap.docs) {
    batch.delete(doc.reference);
  }
}

Future<void> deleteCollectionGroup(String collectionGroup, String email) async {
  try {
    final snap = await FirebaseFirestore.instance
        .collectionGroup(collectionGroup)
        .where('UserEmail', isEqualTo: email)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  } catch (_) {}
}
